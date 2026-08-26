//
//  CoreMotionActivityObservationProvider.swift
//  sip Watch App
//
//  Created by 이돈혁 on 8/26/26.
//

import CoreMotion
import Foundation
import WatchKit

@MainActor
final class CoreMotionActivityObservationProvider: WatchMotionObservationProviding {
    private static let maximumHistoryInterval: TimeInterval = 7 * 24 * 60 * 60

    private let manager: CMMotionActivityManager
    private let queue: OperationQueue
    private(set) var state: WatchMotionObservationProviderState = .stopped
    private var handler: (@MainActor (WatchMotionActivitySample) -> Void)?
    private var currentActivity: CMMotionActivity?
    private var observationLowerBound: Date?
    private var pausedAt: Date?
    private var observationGeneration: UUID?

    init(
        manager: CMMotionActivityManager = CMMotionActivityManager(),
        queue: OperationQueue = .init()
    ) {
        self.manager = manager
        self.queue = queue
        queue.name = "com.codling.sip.watch-motion"
        queue.qualityOfService = .utility
        queue.maxConcurrentOperationCount = 1
    }

    func start(
        from date: Date,
        handler: @escaping @MainActor (WatchMotionActivitySample) -> Void
    ) throws {
        guard state == .stopped || state == .cancelled else {
            throw WatchMotionObservationError.invalidLifecycle
        }
        try validateAvailability()
        state = .running
        self.handler = handler
        let generation = UUID()
        observationGeneration = generation
        let now = Date.now
        observationLowerBound = now
        queryHistory(from: date, to: now, generation: generation)
        startLiveUpdates(generation: generation)
    }

    func pause(at date: Date) {
        guard state == .running else { return }
        closeCurrentActivity(at: date, origin: "live")
        manager.stopActivityUpdates()
        currentActivity = nil
        pausedAt = date
        state = .paused
    }

    func resume(at date: Date) throws {
        guard state == .paused, let pausedAt else {
            throw WatchMotionObservationError.invalidLifecycle
        }
        try validateAvailability()
        guard let observationGeneration else {
            throw WatchMotionObservationError.invalidLifecycle
        }
        state = .running
        observationLowerBound = date
        self.pausedAt = nil
        queryHistory(from: pausedAt, to: date, generation: observationGeneration)
        startLiveUpdates(generation: observationGeneration)
    }

    func stop(at date: Date) {
        guard state == .running || state == .paused else { return }
        if state == .running {
            closeCurrentActivity(at: date, origin: "live")
        }
        manager.stopActivityUpdates()
        reset(state: .stopped)
    }

    func cancel() {
        manager.stopActivityUpdates()
        queue.cancelAllOperations()
        reset(state: .cancelled)
    }

    private func validateAvailability() throws {
        guard CMMotionActivityManager.isActivityAvailable() else {
            throw WatchMotionObservationError.unavailable
        }
        guard CMMotionActivityManager.authorizationStatus() != .denied,
              CMMotionActivityManager.authorizationStatus() != .restricted else {
            throw WatchMotionObservationError.unauthorized
        }
    }

    private func startLiveUpdates(generation: UUID) {
        manager.startActivityUpdates(to: queue) { [weak self] activity in
            guard let activity else { return }
            Task { @MainActor [weak self] in
                guard self?.observationGeneration == generation else { return }
                self?.receiveLive(activity)
            }
        }
    }

    private func receiveLive(_ activity: CMMotionActivity) {
        guard state == .running else { return }
        if let currentActivity {
            emit(currentActivity, start: currentActivity.startDate, end: activity.startDate, origin: "live")
        }
        currentActivity = activity
    }

    private func queryHistory(from requestedStart: Date, to end: Date, generation: UUID) {
        guard requestedStart < end else { return }
        // Core Motion live updates stop while the app is suspended. Its public history is limited to seven days.
        let start = max(requestedStart, end.addingTimeInterval(-Self.maximumHistoryInterval))
        manager.queryActivityStarting(from: start, to: end, to: queue) { [weak self] activities, error in
            guard error == nil, let activities else { return }
            Task { @MainActor [weak self] in
                guard self?.observationGeneration == generation else { return }
                self?.emitHistory(activities, lowerBound: start, upperBound: end)
            }
        }
    }

    private func emitHistory(
        _ activities: [CMMotionActivity],
        lowerBound: Date,
        upperBound: Date
    ) {
        let ordered = activities.sorted { $0.startDate < $1.startDate }
        for (index, activity) in ordered.enumerated() {
            let start = max(activity.startDate, lowerBound)
            let end = min(
                index + 1 < ordered.count ? ordered[index + 1].startDate : upperBound,
                upperBound
            )
            emit(activity, start: start, end: end, origin: "history")
        }
    }

    private func closeCurrentActivity(at date: Date, origin: String) {
        guard let currentActivity else { return }
        emit(currentActivity, start: currentActivity.startDate, end: date, origin: origin)
    }

    private func emit(_ activity: CMMotionActivity, start: Date, end: Date, origin: String) {
        let start = max(start, observationLowerBound ?? start)
        guard start < end else { return }
        let activityValue = Self.activityValue(activity)
        let confidence = activity.confidence.rawValue
        let providerIdentifier = [
            "core-motion-activity-v1",
            String(start.timeIntervalSinceReferenceDate),
            String(end.timeIntervalSinceReferenceDate),
            activityValue,
            String(confidence)
        ].joined(separator: "|")
        handler?(
            WatchMotionActivitySample(
                start: start,
                end: end,
                activity: activityValue,
                confidence: confidence,
                capturedAt: end,
                providerIdentifier: providerIdentifier,
                providerVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                deviceIdentifier: WKInterfaceDevice.current().model,
                metadata: ["deliveryOrigin": origin]
            )
        )
    }

    private func reset(state: WatchMotionObservationProviderState) {
        self.state = state
        handler = nil
        currentActivity = nil
        observationLowerBound = nil
        pausedAt = nil
        observationGeneration = nil
    }

    private static func activityValue(_ activity: CMMotionActivity) -> String {
        var values: [String] = []
        if activity.stationary { values.append("stationary") }
        if activity.walking { values.append("walking") }
        if activity.running { values.append("running") }
        if activity.automotive { values.append("automotive") }
        if activity.cycling { values.append("cycling") }
        if activity.unknown || values.isEmpty { values.append("unknown") }
        return values.joined(separator: "+")
    }
}
