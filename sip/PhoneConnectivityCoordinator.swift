//
//  PhoneConnectivityCoordinator.swift
//  sip
//
//  Created by 이돈혁 on 8/20/26.
//

import Foundation
import OSLog
@preconcurrency import WatchConnectivity

extension Notification.Name {
    static let napWindowsDidChangeFromWatch = Notification.Name("sip.napWindowsDidChangeFromWatch")
    static let activeNapSessionDidChangeFromWatch = Notification.Name("sip.activeNapSessionDidChangeFromWatch")
}

@MainActor
final class PhoneConnectivityCoordinator: NSObject {
    static let shared = PhoneConnectivityCoordinator()

    private enum MessageKey {
        static let schemaVersion = "schemaVersion"
        static let hasWindow = "hasWindow"
        static let windowID = "windowID"
        static let endMinutes = "endMinutes"
        static let alarmMinutes = "alarmMinutes"
        static let isAlarmEnabled = "isAlarmEnabled"
        static let activeSessionData = "activeSessionData"
        static let eventData = "eventData"
        static let observationData = "observationData"
        static let eventID = "eventID"
        static let command = "command"
        static let sessionID = "sessionID"
    }

    private enum StorageKey {
        static let processedEventIDs = "sip.phone.processedWatchEventIDs.v1"
        static let pendingEvents = "sip.phone.pendingWatchEvents.v1"
        static let pendingEndedSessionIDs = "sip.phone.pendingEndedSessionIDs.v1"
    }

    private let logger = Logger(
        subsystem: "com.codling.sip",
        category: "PhoneConnectivityCoordinator"
    )
    private let session: WCSession?
    private var hasStarted = false
    private lazy var detectionCoordinator: NapDetectionCoordinator? = {
        do {
            return NapDetectionCoordinator(
                store: try SwiftDataNapDetectionStore(),
                healthData: HealthKitService.shared
            )
        } catch {
            logger.error("Detection store initialization failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }()

    private override init() {
        session = WCSession.isSupported() ? .default : nil
        super.init()
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        session?.delegate = self
        session?.activate()
    }

    func publish(windows: [NapWindow], activeSession: ActiveNapSession?) {
        processPendingEvents(using: windows)

        guard let session, session.activationState == .activated else { return }
        let resolvedWindows = NapWindowStorage.load() ?? windows
        let enabledWindow = resolvedWindows.first(where: \.isEnabled)
        var context: [String: Any] = [
            MessageKey.schemaVersion: 1,
            MessageKey.hasWindow: enabledWindow != nil
        ]

        if let enabledWindow {
            let calendar = Calendar.current
            context[MessageKey.windowID] = enabledWindow.id.uuidString
            context[MessageKey.endMinutes] = Self.minutes(of: enabledWindow.endTime, calendar: calendar)
            context[MessageKey.alarmMinutes] = Self.minutes(of: enabledWindow.alarmTime, calendar: calendar)
            context[MessageKey.isAlarmEnabled] = enabledWindow.isEndAlarmEnabled
        }

        if let activeSession {
            do {
                context[MessageKey.activeSessionData] = try JSONEncoder().encode(
                    PhoneWatchNapSession(activeSession: activeSession)
                )
            } catch {
                logger.error("Active session encoding failed: \(error.localizedDescription, privacy: .public)")
            }
        }

        do {
            try session.updateApplicationContext(context)
        } catch {
            logger.error("Watch application context update failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func publishStoredState() {
        publish(
            windows: NapWindowStorage.load() ?? [],
            activeSession: ActiveNapSessionStorage.load()
        )
    }

    func notifySessionEnded(_ sessionID: UUID) {
        var pendingIDs = Self.pendingEndedSessionIDs()
        if !pendingIDs.contains(sessionID) {
            pendingIDs.append(sessionID)
            Self.savePendingEndedSessionIDs(pendingIDs)
        }
        flushPendingCommands()
    }

    private func flushPendingCommands() {
        guard let session, session.activationState == .activated else { return }
        let outstandingSessionIDs = Set(
            session.outstandingUserInfoTransfers.compactMap {
                $0.userInfo[MessageKey.sessionID] as? String
            }
        )
        for sessionID in Self.pendingEndedSessionIDs()
        where !outstandingSessionIDs.contains(sessionID.uuidString) {
            session.transferUserInfo([
                MessageKey.schemaVersion: 1,
                MessageKey.command: "sessionEnded",
                MessageKey.sessionID: sessionID.uuidString
            ])
        }
    }

    private func receive(eventData: Data) {
        do {
            let event = try JSONDecoder().decode(PhoneWatchSyncEvent.self, from: eventData)
            var processedIDs = Self.processedEventIDs()
            guard !processedIDs.contains(event.id) else { return }

            if apply(event: event, windows: NapWindowStorage.load() ?? []) {
                processedIDs.append(event.id)
                Self.saveProcessedEventIDs(processedIDs)
            } else {
                var pendingEvents = Self.pendingEvents()
                if !pendingEvents.contains(where: { $0.id == event.id }) {
                    pendingEvents.append(event)
                    Self.savePendingEvents(pendingEvents)
                }
            }
        } catch {
            logger.error("Watch event decoding failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func receive(observationData: Data) {
        do {
            let payload = try JSONDecoder().decode(PhoneWatchObservation.self, from: observationData)
            guard payload.schemaVersion == NapObservation.currentSchemaVersion,
                  let interval = try? NapInterval(start: payload.start, end: payload.end) else { return }
            let kind: NapObservationKind
            switch payload.kind {
            case .motion:
                kind = .motion(activity: payload.activity ?? "unknown", confidence: payload.confidence ?? 0)
            case .activeSession:
                kind = .activeSession
            case .directStart:
                kind = .directStart
            case .directEnd:
                kind = .directEnd
            }
            let observation = NapObservation(
                id: payload.id,
                sessionID: payload.sessionID,
                interval: interval,
                source: payload.kind == .motion ? .watchMotion : .activeSession,
                kind: kind,
                provenance: NapObservationProvenance(
                    providerIdentifier: payload.providerIdentifier ?? payload.id.uuidString,
                    sourceBundleIdentifier: payload.sourceBundleIdentifier ?? "com.codling.sip.watchkitapp",
                    sourceVersion: payload.sourceVersion,
                    deviceIdentifier: payload.deviceIdentifier,
                    metadata: (payload.metadata ?? [:]).merging([
                        "sequence": String(payload.sequence),
                        "timeZoneIdentifier": payload.timeZoneIdentifier
                    ]) { current, _ in current }
                ),
                capturedAt: payload.capturedAt,
                schemaVersion: payload.schemaVersion,
                algorithmVersion: payload.algorithmVersion
            )
            guard let detectionCoordinator else {
                throw NapDetectionError.persistenceFailed("Detection store unavailable")
            }
            _ = try detectionCoordinator.ingest(
                sessionID: payload.sessionID,
                windowID: nil,
                candidate: interval,
                timeZoneIdentifier: payload.timeZoneIdentifier,
                observations: [observation]
            )
            acknowledgeObservation(payload.id)
        } catch {
            logger.error("Watch observation ingestion failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func acknowledgeObservation(_ observationID: UUID) {
        guard let session, session.activationState == .activated else { return }
        session.transferUserInfo([
            MessageKey.schemaVersion: NapObservation.currentSchemaVersion,
            MessageKey.command: "observationIngested",
            MessageKey.eventID: observationID.uuidString
        ])
    }

    private func processPendingEvents(using windows: [NapWindow]) {
        let pendingEvents = Self.pendingEvents()
        guard !pendingEvents.isEmpty else { return }

        var remaining: [PhoneWatchSyncEvent] = []
        var processedIDs = Self.processedEventIDs()
        for event in pendingEvents {
            if processedIDs.contains(event.id) {
                continue
            }
            if apply(event: event, windows: windows) {
                processedIDs.append(event.id)
            } else {
                remaining.append(event)
            }
        }
        Self.saveProcessedEventIDs(processedIDs)
        Self.savePendingEvents(remaining)
    }

    private func apply(event: PhoneWatchSyncEvent, windows: [NapWindow]) -> Bool {
        switch event.kind {
        case .sessionStarted:
            guard let session = event.session?.activeNapSession else { return true }
            ActiveNapSessionStorage.save(session)
            NotificationCenter.default.post(name: .activeNapSessionDidChangeFromWatch, object: nil)
            return true

        case .sessionEnded:
            guard let endedSession = event.session else { return true }
            if let storedSession = ActiveNapSessionStorage.load(), storedSession.id != endedSession.id {
                return true
            }
            ActiveNapSessionStorage.remove()
            NotificationCenter.default.post(name: .activeNapSessionDidChangeFromWatch, object: nil)
            return true

        case .alarmUpdated:
            guard let windowID = event.windowID,
                  let alarmMinutes = event.alarmMinutes,
                  let isAlarmEnabled = event.isAlarmEnabled,
                  var window = windows.first(where: { $0.id == windowID }) else {
                return false
            }

            window.isEndAlarmEnabled = isAlarmEnabled
            window.alarmTime = Self.date(minutes: alarmMinutes, relativeTo: window.alarmTime)
            var updatedWindows = windows
            guard let index = updatedWindows.firstIndex(where: { $0.id == windowID }) else { return false }
            updatedWindows[index] = window
            NapWindowStorage.save(updatedWindows)
            NotificationCenter.default.post(name: .napWindowsDidChangeFromWatch, object: nil)
            return true
        }
    }

    private static func minutes(of date: Date, calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private static func date(minutes: Int, relativeTo date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(
            bySettingHour: min(max(minutes / 60, 0), 23),
            minute: min(max(minutes % 60, 0), 59),
            second: 0,
            of: date
        ) ?? date
    }

    private static func processedEventIDs() -> [UUID] {
        guard let data = UserDefaults.standard.data(forKey: StorageKey.processedEventIDs) else { return [] }
        do {
            return try JSONDecoder().decode([UUID].self, from: data)
        } catch {
            storageLogger.error("Processed Watch event IDs decoding failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    private static func saveProcessedEventIDs(_ ids: [UUID]) {
        let boundedIDs = Array(ids.suffix(512))
        do {
            UserDefaults.standard.set(
                try JSONEncoder().encode(boundedIDs),
                forKey: StorageKey.processedEventIDs
            )
        } catch {
            storageLogger.error("Processed Watch event IDs encoding failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func pendingEvents() -> [PhoneWatchSyncEvent] {
        guard let data = UserDefaults.standard.data(forKey: StorageKey.pendingEvents) else { return [] }
        do {
            return try JSONDecoder().decode([PhoneWatchSyncEvent].self, from: data)
        } catch {
            storageLogger.error("Pending Watch events decoding failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    private static func savePendingEvents(_ events: [PhoneWatchSyncEvent]) {
        do {
            UserDefaults.standard.set(
                try JSONEncoder().encode(events),
                forKey: StorageKey.pendingEvents
            )
        } catch {
            storageLogger.error("Pending Watch events encoding failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func pendingEndedSessionIDs() -> [UUID] {
        guard let data = UserDefaults.standard.data(forKey: StorageKey.pendingEndedSessionIDs) else { return [] }
        do {
            return try JSONDecoder().decode([UUID].self, from: data)
        } catch {
            storageLogger.error("Pending ended session IDs decoding failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    private static func savePendingEndedSessionIDs(_ ids: [UUID]) {
        do {
            UserDefaults.standard.set(
                try JSONEncoder().encode(ids),
                forKey: StorageKey.pendingEndedSessionIDs
            )
        } catch {
            storageLogger.error("Pending ended session IDs encoding failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static let storageLogger = Logger(
        subsystem: "com.codling.sip",
        category: "PhoneConnectivityCoordinator"
    )
}

extension PhoneConnectivityCoordinator: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard error == nil, activationState == .activated else { return }
        Task { @MainActor in
            self.publishStoredState()
            self.flushPendingCommands()
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any] = [:]
    ) {
        Task { @MainActor in
            if let eventData = userInfo[MessageKey.eventData] as? Data {
                self.receive(eventData: eventData)
            } else if let observationData = userInfo[MessageKey.observationData] as? Data {
                self.receive(observationData: observationData)
            }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.flushPendingCommands()
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didFinish userInfoTransfer: WCSessionUserInfoTransfer,
        error: Error?
    ) {
        guard error == nil,
              userInfoTransfer.userInfo[MessageKey.command] as? String == "sessionEnded",
              let sessionIDString = userInfoTransfer.userInfo[MessageKey.sessionID] as? String,
              let sessionID = UUID(uuidString: sessionIDString) else { return }
        Task { @MainActor in
            var pendingIDs = Self.pendingEndedSessionIDs()
            pendingIDs.removeAll { $0 == sessionID }
            Self.savePendingEndedSessionIDs(pendingIDs)
        }
    }
}

private struct PhoneWatchSyncEvent: Codable {
    enum Kind: String, Codable {
        case sessionStarted
        case sessionEnded
        case alarmUpdated
    }

    let id: UUID
    let kind: Kind
    let createdAt: Date
    let session: PhoneWatchNapSession?
    let windowID: UUID?
    let alarmMinutes: Int?
    let isAlarmEnabled: Bool?
}

private struct PhoneWatchNapSession: Codable {
    let id: UUID
    let windowID: UUID
    let startedAt: Date
    let endAlarmAt: Date

    init(activeSession: ActiveNapSession) {
        id = activeSession.id
        windowID = activeSession.windowID ?? activeSession.id
        startedAt = activeSession.startedAt
        endAlarmAt = activeSession.endAlarmAt
    }

    var activeNapSession: ActiveNapSession {
        ActiveNapSession(
            id: id,
            windowID: windowID,
            startedAt: startedAt,
            endAlarmAt: endAlarmAt
        )
    }
}

private struct PhoneWatchObservation: Codable {
    enum Kind: String, Codable {
        case motion
        case activeSession
        case directStart
        case directEnd
    }

    let id: UUID
    let sessionID: UUID
    let sequence: Int
    let start: Date
    let end: Date
    let kind: Kind
    let activity: String?
    let confidence: Int?
    let capturedAt: Date
    let timeZoneIdentifier: String
    let schemaVersion: Int
    let algorithmVersion: String
    let providerIdentifier: String?
    let sourceBundleIdentifier: String?
    let sourceVersion: String?
    let deviceIdentifier: String?
    let metadata: [String: String]?
}
