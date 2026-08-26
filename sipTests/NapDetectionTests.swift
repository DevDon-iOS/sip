//
//  NapDetectionTests.swift
//  sipTests
//
//  Created by 이돈혁 on 8/21/26.
//

import Foundation
import Testing
@testable import sip

@Suite("Nap detection domain")
@MainActor
struct NapDetectionTests {
    private let reference = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("Observations are ordered and duplicate provider samples are suppressed")
    func normalizationAndOrdering() throws {
        let sessionID = UUID()
        let candidate = try interval(0, 60)
        let later = try observation(
            id: UUID(),
            sessionID: sessionID,
            startMinute: 20,
            endMinute: 30,
            source: .watchMotion,
            kind: .motion(activity: "stationary", confidence: 2),
            providerID: "watch-2"
        )
        let duplicate = try observation(
            id: UUID(),
            sessionID: sessionID,
            startMinute: 10,
            endMinute: 20,
            source: .watchMotion,
            kind: .motion(activity: "stationary", confidence: 2),
            providerID: "watch-1"
        )
        let sameProviderLaterArrival = try observation(
            id: UUID(),
            sessionID: sessionID,
            startMinute: 10,
            endMinute: 20,
            source: .watchMotion,
            kind: .motion(activity: "stationary", confidence: 2),
            providerID: "watch-1",
            capturedMinute: 40
        )

        let result = NapObservationNormalizer().normalize(
            [later, sameProviderLaterArrival, duplicate],
            within: candidate
        )

        #expect(result.count == 2)
        #expect(result.map(\.provenance.providerIdentifier) == ["watch-1", "watch-2"])
        #expect(result.first?.id == duplicate.id)
    }

    @Test("Overlaps and midnight boundaries merge by absolute time")
    func overlapAndMidnight() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let start = calendar.date(from: DateComponents(year: 2026, month: 8, day: 21, hour: 23, minute: 50))!
        let first = try NapInterval(start: start, end: start.addingTimeInterval(15 * 60))
        let second = try NapInterval(
            start: start.addingTimeInterval(14 * 60),
            end: start.addingTimeInterval(30 * 60)
        )

        let merged = NapObservationNormalizer().mergedIntervals([second, first], maximumGap: 0)

        #expect(merged.count == 1)
        #expect(merged[0].start == first.start)
        #expect(merged[0].end == second.end)
        #expect(calendar.component(.day, from: merged[0].end) == 22)
    }

    @Test("Unvalidated production policy fails closed")
    func unvalidatedPolicyFailsClosed() throws {
        let sessionID = UUID()
        let candidate = try interval(0, 60)
        let motion = try observation(
            sessionID: sessionID,
            startMinute: 5,
            endMinute: 55,
            source: .watchMotion,
            kind: .motion(activity: "stationary", confidence: 2)
        )

        let decision = NapDetectionProcessor().process(
            sessionID: sessionID,
            candidate: candidate,
            observations: [motion],
            policy: .production,
            now: reference
        )

        #expect(decision.state == .partialEvidence)
        #expect(decision.interval == nil)
        #expect(decision.source == .partial)
    }

    @Test("Fixture policy supports deterministic missing and partial inputs")
    func fixturePolicyMissingAndPartial() throws {
        let sessionID = UUID()
        let candidate = try interval(0, 60)
        let processor = NapDetectionProcessor()
        let policy = NapDetectionPolicy.validatedFixture(
            minimumContinuousDuration: 20 * 60,
            requiredInferenceSources: [.watchMotion, .heartRate]
        )

        let empty = processor.process(
            sessionID: sessionID,
            candidate: candidate,
            observations: [],
            policy: policy,
            now: reference
        )
        let motionOnly = processor.process(
            sessionID: sessionID,
            candidate: candidate,
            observations: [try observation(
                sessionID: sessionID,
                startMinute: 0,
                endMinute: 30,
                source: .watchMotion,
                kind: .motion(activity: "stationary", confidence: 2)
            )],
            policy: policy,
            now: reference
        )

        #expect(empty.state == .noRecord)
        #expect(motionOnly.state == .partialEvidence)
    }

    @Test("Delayed Apple sleep takes precedence and preserves Apple stages")
    func delayedApplePrecedence() throws {
        let sessionID = UUID()
        let candidate = try interval(0, 60)
        let policy = NapDetectionPolicy.validatedFixture(minimumContinuousDuration: 10 * 60)
        let motion = try observation(
            sessionID: sessionID,
            startMinute: 0,
            endMinute: 40,
            source: .watchMotion,
            kind: .motion(activity: "stationary", confidence: 2)
        )
        let apple = try observation(
            sessionID: sessionID,
            startMinute: 10,
            endMinute: 35,
            source: .appleHealth,
            kind: .appleSleep(stage: .core),
            providerID: "HK-1"
        )
        let processor = NapDetectionProcessor()

        let before = processor.process(
            sessionID: sessionID,
            candidate: candidate,
            observations: [motion],
            policy: policy,
            now: reference
        )
        let after = processor.process(
            sessionID: sessionID,
            candidate: candidate,
            observations: [motion, apple],
            policy: policy,
            now: reference
        )

        #expect(before.source == .sipInference)
        #expect(before.appleStages.isEmpty)
        #expect(after.source == .appleHealth)
        #expect(after.appleStages == [.core])
        #expect(after.interval == apple.interval)
    }

    @Test("Corrections and exclusions preserve original observations")
    func correctionAndExclusionPreserveEvidence() async throws {
        let store = try SwiftDataNapDetectionStore(inMemory: true)
        let health = MockHealthDataClient()
        let coordinator = NapDetectionCoordinator(
            store: store,
            healthData: health,
            policy: .validatedFixture(minimumContinuousDuration: 10 * 60),
            now: { self.reference }
        )
        let sessionID = UUID()
        let evidence = try observation(
            sessionID: sessionID,
            startMinute: 5,
            endMinute: 35,
            source: .watchMotion,
            kind: .motion(activity: "stationary", confidence: 2)
        )
        _ = try coordinator.ingest(
            sessionID: sessionID,
            windowID: nil,
            candidate: interval(0, 60),
            timeZoneIdentifier: "Asia/Seoul",
            observations: [evidence]
        )

        let correctedInterval = try interval(10, 30)
        let corrected = try coordinator.correct(sessionID: sessionID, interval: correctedInterval)
        let excluded = try coordinator.exclude(sessionID: sessionID)

        #expect(corrected.state == .confirmed)
        #expect(corrected.interval == correctedInterval)
        #expect(excluded.state == .excluded)
        #expect(try store.observations(sessionID: sessionID).map(\.id) == [evidence.id])
        #expect(try store.corrections(sessionID: sessionID).count == 2)
    }

    @Test("Permission denial does not erase a persisted decision")
    func permissionDeniedReconciliation() async throws {
        let store = try SwiftDataNapDetectionStore(inMemory: true)
        let health = MockHealthDataClient(sleepResult: .failure(.healthAuthorizationDenied))
        let coordinator = NapDetectionCoordinator(
            store: store,
            healthData: health,
            policy: .validatedFixture(minimumContinuousDuration: 10 * 60),
            now: { self.reference }
        )
        let sessionID = UUID()
        _ = try coordinator.ingest(
            sessionID: sessionID,
            windowID: nil,
            candidate: interval(0, 60),
            timeZoneIdentifier: "UTC",
            observations: [try observation(
                sessionID: sessionID,
                startMinute: 0,
                endMinute: 30,
                source: .watchMotion,
                kind: .motion(activity: "stationary", confidence: 2)
            )]
        )

        let decision = try await coordinator.reconcileAppleHealth(sessionID: sessionID)

        #expect(decision.state == .provisional)
        #expect(decision.source == .sipInference)
    }

    @Test("HealthKit writes require confirmation and are idempotent")
    func confirmedOnlyHealthWrite() async throws {
        let store = try SwiftDataNapDetectionStore(inMemory: true)
        let health = MockHealthDataClient()
        let coordinator = NapDetectionCoordinator(
            store: store,
            healthData: health,
            policy: .validatedFixture(minimumContinuousDuration: 10 * 60),
            now: { self.reference }
        )
        let sessionID = UUID()
        _ = try coordinator.ingest(
            sessionID: sessionID,
            windowID: nil,
            candidate: interval(0, 60),
            timeZoneIdentifier: "UTC",
            observations: [try observation(
                sessionID: sessionID,
                startMinute: 0,
                endMinute: 30,
                source: .watchMotion,
                kind: .motion(activity: "stationary", confidence: 2)
            )]
        )

        await #expect(throws: NapDetectionError.unconfirmedHealthWrite) {
            try await coordinator.saveConfirmedToHealthKit(sessionID: sessionID)
        }
        _ = try coordinator.confirm(sessionID: sessionID)
        _ = try await coordinator.saveConfirmedToHealthKit(sessionID: sessionID)
        _ = try await coordinator.saveConfirmedToHealthKit(sessionID: sessionID)

        #expect(await health.saveCount == 1)
        #expect(await health.lastSaved?.interval == (try interval(0, 30)))
    }

    @Test("SwiftData reload keeps decisions, observations, and schema version")
    func persistenceReloadAndSchema() throws {
        let first = try SwiftDataNapDetectionStore(inMemory: true)
        let sessionID = UUID()
        let candidate = try interval(0, 60)
        let evidence = try observation(
            sessionID: sessionID,
            startMinute: 10,
            endMinute: 20,
            source: .watchMotion,
            kind: .motion(activity: "stationary", confidence: 1)
        )
        try first.upsertSession(
            id: sessionID,
            windowID: nil,
            candidate: candidate,
            timeZoneIdentifier: "UTC",
            algorithmVersion: "fixture-v1",
            now: reference
        )
        try first.upsertObservations([evidence, evidence])

        let reloaded = SwiftDataNapDetectionStore(container: first.container)

        #expect(try reloaded.session(id: sessionID)?.timeZoneIdentifier == "UTC")
        #expect(try reloaded.observations(sessionID: sessionID).count == 1)
        #expect(NapDetectionSchemaV1.versionIdentifier == .init(1, 0, 0))
    }

    @Test("Reprocessing is idempotent while changed decisions remain auditable")
    func decisionHistoryAndIdempotency() throws {
        let store = try SwiftDataNapDetectionStore(inMemory: true)
        let coordinator = NapDetectionCoordinator(
            store: store,
            healthData: MockHealthDataClient(),
            policy: .validatedFixture(minimumContinuousDuration: 10 * 60),
            now: { self.reference }
        )
        let sessionID = UUID()
        let motion = try observation(
            sessionID: sessionID,
            startMinute: 0,
            endMinute: 30,
            source: .watchMotion,
            kind: .motion(activity: "stationary", confidence: 2)
        )
        _ = try coordinator.ingest(
            sessionID: sessionID,
            windowID: nil,
            candidate: interval(0, 60),
            timeZoneIdentifier: "UTC",
            observations: [motion]
        )
        _ = try coordinator.process(sessionID: sessionID)
        #expect(try store.decisions(sessionID: sessionID).count == 1)

        let apple = try observation(
            sessionID: sessionID,
            startMinute: 5,
            endMinute: 25,
            source: .appleHealth,
            kind: .appleSleep(stage: .asleepUnspecified),
            providerID: "HK-delayed"
        )
        try store.upsertObservations([apple])
        _ = try coordinator.process(sessionID: sessionID)

        let history = try store.decisions(sessionID: sessionID)
        #expect(history.count == 2)
        #expect(Set(history.map(\.source)) == [.sipInference, .appleHealth])
    }

    @Test("Out-of-order Watch observations are ingested idempotently")
    func watchObservationIdempotency() throws {
        let store = try SwiftDataNapDetectionStore(inMemory: true)
        let sessionID = UUID()
        let first = try observation(
            id: UUID(),
            sessionID: sessionID,
            startMinute: 0,
            endMinute: 10,
            source: .watchMotion,
            kind: .motion(activity: "stationary", confidence: 1),
            providerID: "watch-sequence-1"
        )
        let second = try observation(
            id: UUID(),
            sessionID: sessionID,
            startMinute: 10,
            endMinute: 20,
            source: .watchMotion,
            kind: .motion(activity: "stationary", confidence: 1),
            providerID: "watch-sequence-2"
        )
        try store.upsertSession(
            id: sessionID,
            windowID: nil,
            candidate: interval(0, 30),
            timeZoneIdentifier: "UTC",
            algorithmVersion: "fixture-v1",
            now: reference
        )
        let duplicateProvider = try observation(
            id: UUID(),
            sessionID: sessionID,
            startMinute: 10,
            endMinute: 20,
            source: .watchMotion,
            kind: .motion(activity: "stationary", confidence: 1),
            providerID: "watch-sequence-2"
        )
        try store.upsertObservations([second, first, duplicateProvider, second])

        let stored = try store.observations(sessionID: sessionID)

        #expect(stored.map(\.id) == [first.id, second.id])
    }

    @Test("Watch outbox survives reload, orders events, and retains failed transfers")
    func watchOutboxRetryAndReload() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("watch-outbox-\(UUID().uuidString).json")
        let sessionID = UUID()
        let later = WatchNormalizedObservation(
            sessionID: sessionID,
            sequence: 2,
            start: reference.addingTimeInterval(20),
            end: reference.addingTimeInterval(21),
            kind: .motion,
            activity: "stationary",
            confidence: 2,
            capturedAt: reference.addingTimeInterval(21),
            algorithmVersion: "fixture-v1"
        )
        let earlier = WatchNormalizedObservation(
            sessionID: sessionID,
            sequence: 1,
            start: reference.addingTimeInterval(10),
            end: reference.addingTimeInterval(11),
            kind: .motion,
            activity: "stationary",
            confidence: 2,
            capturedAt: reference.addingTimeInterval(11),
            algorithmVersion: "fixture-v1"
        )
        let outbox = try WatchObservationOutbox(fileURL: fileURL)
        try outbox.enqueue(later)
        try outbox.enqueue(earlier)
        try outbox.enqueue(later)

        let reloaded = try WatchObservationOutbox(fileURL: fileURL)
        #expect(reloaded.observations.map(\.id) == [earlier.id, later.id])

        try reloaded.markDelivered(id: earlier.id)
        let afterAcknowledgement = try WatchObservationOutbox(fileURL: fileURL)
        #expect(afterAcknowledgement.observations.map(\.id) == [later.id])

        try FileManager.default.removeItem(at: fileURL)
    }

    @Test("Watch motion provider lifecycle emits versioned provenance")
    func watchMotionLifecycleAndProvenance() throws {
        let provider = FakeWatchMotionObservationProvider()
        var received: [WatchNormalizedObservation] = []
        let controller = WatchMotionObservationController(provider: provider) {
            received.append($0)
        }
        let sessionID = UUID()
        let start = reference
        let end = reference.addingTimeInterval(60)

        try controller.start(sessionID: sessionID, from: start)
        provider.emit(
            WatchMotionActivitySample(
                start: start,
                end: end,
                activity: "stationary",
                confidence: 2,
                capturedAt: end,
                providerIdentifier: "core-motion-activity-v1|sample-1",
                providerVersion: "watchOS fixture",
                deviceIdentifier: "Watch fixture",
                metadata: ["deliveryOrigin": "history"]
            )
        )
        controller.pause(at: end)
        try controller.resume(at: end.addingTimeInterval(30))
        controller.stop(at: end.addingTimeInterval(60))

        #expect(provider.calls == [
            .start(start),
            .pause(end),
            .resume(end.addingTimeInterval(30)),
            .stop(end.addingTimeInterval(60))
        ])
        #expect(controller.providerState == .stopped)
        #expect(received.count == 1)
        #expect(received[0].sessionID == sessionID)
        #expect(received[0].providerIdentifier == "core-motion-activity-v1|sample-1")
        #expect(received[0].sourceVersion == "watchOS fixture")
        #expect(received[0].deviceIdentifier == "Watch fixture")
        #expect(received[0].schemaVersion == WatchNormalizedObservation.currentSchemaVersion)
        #expect(received[0].algorithmVersion == "unvalidated-production-v1")
        #expect(received[0].metadata == ["deliveryOrigin": "history"])
    }

    @Test("Watch motion cancellation suppresses late provider delivery")
    func watchMotionCancellation() throws {
        let provider = FakeWatchMotionObservationProvider()
        var received: [WatchNormalizedObservation] = []
        let controller = WatchMotionObservationController(provider: provider) {
            received.append($0)
        }

        try controller.start(sessionID: UUID(), from: reference)
        controller.cancel()
        provider.emit(
            WatchMotionActivitySample(
                start: reference,
                end: reference.addingTimeInterval(1),
                activity: "unknown",
                confidence: 0,
                capturedAt: reference.addingTimeInterval(1),
                providerIdentifier: "late-sample",
                providerVersion: nil,
                deviceIdentifier: nil,
                metadata: [:]
            )
        )

        #expect(provider.calls == [.start(reference), .cancel])
        #expect(controller.providerState == .cancelled)
        #expect(received.isEmpty)
    }

    @Test("Deterministic provider identity survives outbox reload and retry")
    func watchMotionDeterministicIdentityAndOutboxRetry() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("watch-motion-outbox-\(UUID().uuidString).json")
        let provider = FakeWatchMotionObservationProvider()
        let outbox = try WatchObservationOutbox(fileURL: fileURL)
        let sessionID = UUID()
        let controller = WatchMotionObservationController(provider: provider) {
            try? outbox.enqueue($0)
        }
        let sample = WatchMotionActivitySample(
            start: reference,
            end: reference.addingTimeInterval(30),
            activity: "stationary",
            confidence: 1,
            capturedAt: reference.addingTimeInterval(30),
            providerIdentifier: "core-motion-activity-v1|stable-sample",
            providerVersion: "fixture",
            deviceIdentifier: "fixture-watch",
            metadata: ["deliveryOrigin": "history"]
        )

        try controller.start(sessionID: sessionID, from: reference)
        provider.emit(sample)
        provider.emit(sample)
        controller.stop(at: sample.end)

        let relaunchedOutbox = try WatchObservationOutbox(fileURL: fileURL)
        let relaunchedProvider = FakeWatchMotionObservationProvider()
        let relaunchedController = WatchMotionObservationController(provider: relaunchedProvider) {
            try? relaunchedOutbox.enqueue($0)
        }
        try relaunchedController.start(sessionID: sessionID, from: reference)
        relaunchedProvider.emit(sample)
        #expect(relaunchedOutbox.observations.count == 1)
        #expect(relaunchedOutbox.observations[0].providerIdentifier == sample.providerIdentifier)
        #expect(relaunchedOutbox.observations[0].metadata == sample.metadata)

        relaunchedController.stop(at: sample.end)
        try relaunchedController.start(sessionID: UUID(), from: reference)
        relaunchedProvider.emit(sample)
        #expect(relaunchedOutbox.observations.count == 2)
        #expect(relaunchedOutbox.observations[0].id != relaunchedOutbox.observations[1].id)

        try FileManager.default.removeItem(at: fileURL)
    }

    private func interval(_ startMinute: Int, _ endMinute: Int) throws -> NapInterval {
        try NapInterval(
            start: reference.addingTimeInterval(TimeInterval(startMinute * 60)),
            end: reference.addingTimeInterval(TimeInterval(endMinute * 60))
        )
    }

    private func observation(
        id: UUID = UUID(),
        sessionID: UUID,
        startMinute: Int,
        endMinute: Int,
        source: NapObservationSource,
        kind: NapObservationKind,
        providerID: String? = nil,
        capturedMinute: Int? = nil
    ) throws -> NapObservation {
        NapObservation(
            id: id,
            sessionID: sessionID,
            interval: try NapInterval(
                start: reference.addingTimeInterval(TimeInterval(startMinute * 60)),
                end: reference.addingTimeInterval(TimeInterval(endMinute * 60))
            ),
            source: source,
            kind: kind,
            provenance: .init(providerIdentifier: providerID),
            capturedAt: reference.addingTimeInterval(TimeInterval((capturedMinute ?? endMinute) * 60)),
            algorithmVersion: "fixture-v1"
        )
    }
}

@MainActor
private final class FakeWatchMotionObservationProvider: WatchMotionObservationProviding {
    enum Call: Equatable {
        case start(Date)
        case pause(Date)
        case resume(Date)
        case stop(Date)
        case cancel
    }

    private(set) var state: WatchMotionObservationProviderState = .stopped
    private(set) var calls: [Call] = []
    private var handler: (@MainActor (WatchMotionActivitySample) -> Void)?

    func start(
        from date: Date,
        handler: @escaping @MainActor (WatchMotionActivitySample) -> Void
    ) throws {
        guard state == .stopped || state == .cancelled else {
            throw WatchMotionObservationError.invalidLifecycle
        }
        calls.append(.start(date))
        state = .running
        self.handler = handler
    }

    func pause(at date: Date) {
        guard state == .running else { return }
        calls.append(.pause(date))
        state = .paused
    }

    func resume(at date: Date) throws {
        guard state == .paused else { throw WatchMotionObservationError.invalidLifecycle }
        calls.append(.resume(date))
        state = .running
    }

    func stop(at date: Date) {
        guard state == .running || state == .paused else { return }
        calls.append(.stop(date))
        state = .stopped
        handler = nil
    }

    func cancel() {
        calls.append(.cancel)
        state = .cancelled
        handler = nil
    }

    func emit(_ sample: WatchMotionActivitySample) {
        handler?(sample)
    }
}

private actor MockHealthDataClient: HealthDataClient {
    private let sleepResult: Result<[NapObservation], NapDetectionError>
    private(set) var saveCount = 0
    private(set) var lastSaved: ConfirmedNapRecord?

    init(sleepResult: Result<[NapObservation], NapDetectionError> = .success([])) {
        self.sleepResult = sleepResult
    }

    func requestAuthorization() async throws {}

    func fetchSleepObservations(
        sessionID: UUID,
        interval: NapInterval,
        algorithmVersion: String
    ) async throws -> [NapObservation] {
        try sleepResult.get()
    }

    func fetchHeartRateObservations(
        sessionID: UUID,
        interval: NapInterval,
        algorithmVersion: String
    ) async throws -> [NapObservation] {
        []
    }

    func saveConfirmedNap(_ record: ConfirmedNapRecord) async throws -> String {
        saveCount += 1
        lastSaved = record
        return "HK-\(record.sessionID.uuidString)"
    }
}
