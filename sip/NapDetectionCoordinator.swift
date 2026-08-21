//
//  NapDetectionCoordinator.swift
//  sip
//
//  Created by 이돈혁 on 8/21/26.
//

import Foundation

@MainActor
final class NapDetectionCoordinator {
    private let store: NapDetectionStore
    private let healthData: HealthDataClient
    private let policy: NapDetectionPolicy
    private let processor: NapDetectionProcessor
    private let now: @MainActor () -> Date

    init(
        store: NapDetectionStore,
        healthData: HealthDataClient,
        policy: NapDetectionPolicy = .production,
        processor: NapDetectionProcessor = .init(),
        now: @escaping @MainActor () -> Date = { .now }
    ) {
        self.store = store
        self.healthData = healthData
        self.policy = policy
        self.processor = processor
        self.now = now
    }

    @discardableResult
    func ingest(
        sessionID: UUID,
        windowID: UUID?,
        candidate: NapInterval,
        timeZoneIdentifier: String,
        observations: [NapObservation]
    ) throws -> NapDetectionDecision {
        try store.upsertSession(
            id: sessionID,
            windowID: windowID,
            candidate: candidate,
            timeZoneIdentifier: timeZoneIdentifier,
            algorithmVersion: policy.version,
            now: now()
        )
        try store.upsertObservations(observations)
        return try process(sessionID: sessionID)
    }

    @discardableResult
    func process(sessionID: UUID) throws -> NapDetectionDecision {
        guard let session = try store.session(id: sessionID),
              let candidate = session.candidate else {
            throw NapDetectionError.missingSession
        }
        let observations = try store.observations(sessionID: sessionID)
        let corrections = try store.corrections(sessionID: sessionID)
        var decision = processor.process(
            sessionID: sessionID,
            candidate: candidate,
            observations: observations,
            policy: policy,
            now: now()
        )
        decision = applying(corrections: corrections, to: decision)
        try store.saveDecision(decision)
        if decision.state == .confirmed, let interval = decision.interval {
            session.confirmedAt = corrections.last?.createdAt ?? now()
            session.detectedStart = interval.start
            session.detectedEnd = interval.end
            try store.saveChanges()
        }
        return decision
    }

    func detectedRecords() throws -> [ConfirmedNapRecord] {
        try store.sessions().compactMap { session in
            guard session.state == .confirmed,
                  let interval = session.detectedInterval,
                  let confirmedAt = session.confirmedAt else { return nil }
            return ConfirmedNapRecord(
                id: session.id,
                sessionID: session.id,
                interval: interval,
                source: session.decisionSource,
                algorithmVersion: session.algorithmVersion,
                confirmedAt: confirmedAt,
                healthKitSampleIdentifier: session.healthKitSampleIdentifier
            )
        }
    }

    @discardableResult
    func confirm(sessionID: UUID, interval: NapInterval? = nil) throws -> NapDetectionDecision {
        guard let existing = try store.decision(sessionID: sessionID),
              interval != nil || existing.interval != nil else {
            throw NapDetectionError.invalidInterval
        }
        let correction = NapCorrection(
            id: UUID(),
            sessionID: sessionID,
            kind: interval == nil ? .confirm : .correct,
            interval: interval ?? existing.interval,
            createdAt: try nextCorrectionDate(sessionID: sessionID)
        )
        try store.saveCorrection(correction)
        return try process(sessionID: sessionID)
    }

    @discardableResult
    func correct(sessionID: UUID, interval: NapInterval) throws -> NapDetectionDecision {
        let correction = NapCorrection(
            id: UUID(),
            sessionID: sessionID,
            kind: .correct,
            interval: interval,
            createdAt: try nextCorrectionDate(sessionID: sessionID)
        )
        try store.saveCorrection(correction)
        return try process(sessionID: sessionID)
    }

    @discardableResult
    func exclude(sessionID: UUID) throws -> NapDetectionDecision {
        let correction = NapCorrection(
            id: UUID(),
            sessionID: sessionID,
            kind: .exclude,
            interval: nil,
            createdAt: try nextCorrectionDate(sessionID: sessionID)
        )
        try store.saveCorrection(correction)
        return try process(sessionID: sessionID)
    }

    @discardableResult
    func reconcileAppleHealth(sessionID: UUID) async throws -> NapDetectionDecision {
        guard let session = try store.session(id: sessionID),
              let candidate = session.candidate else {
            throw NapDetectionError.missingSession
        }
        do {
            let observations = try await healthData.fetchSleepObservations(
                sessionID: sessionID,
                interval: candidate,
                algorithmVersion: policy.version
            )
            try store.upsertObservations(observations)
        } catch NapDetectionError.healthAuthorizationDenied {
            // Existing evidence and user decisions remain usable when read access is denied.
        } catch NapDetectionError.healthDataUnavailable {
            // Existing evidence and user decisions remain usable when HealthKit is unavailable.
        }
        return try process(sessionID: sessionID)
    }

    func ingestAvailableHeartRate(sessionID: UUID) async throws {
        guard let session = try store.session(id: sessionID),
              let candidate = session.candidate else {
            throw NapDetectionError.missingSession
        }
        do {
            let observations = try await healthData.fetchHeartRateObservations(
                sessionID: sessionID,
                interval: candidate,
                algorithmVersion: policy.version
            )
            try store.upsertObservations(observations)
        } catch NapDetectionError.healthAuthorizationDenied {
            return
        } catch NapDetectionError.healthDataUnavailable {
            return
        }
    }

    func saveConfirmedToHealthKit(sessionID: UUID) async throws -> ConfirmedNapRecord {
        guard let session = try store.session(id: sessionID),
              session.state == .confirmed,
              let interval = session.detectedInterval,
              let confirmedAt = session.confirmedAt else {
            throw NapDetectionError.unconfirmedHealthWrite
        }
        if session.healthKitSampleIdentifier != nil {
            return makeConfirmedRecord(session: session, interval: interval, confirmedAt: confirmedAt)
        }

        let record = makeConfirmedRecord(session: session, interval: interval, confirmedAt: confirmedAt)
        let sampleIdentifier = try await healthData.saveConfirmedNap(record)
        session.healthKitSampleIdentifier = sampleIdentifier
        session.healthKitSavedAt = now()
        try store.saveChanges()
        return makeConfirmedRecord(session: session, interval: interval, confirmedAt: confirmedAt)
    }

    private func makeConfirmedRecord(
        session: NapDetectionSessionModel,
        interval: NapInterval,
        confirmedAt: Date
    ) -> ConfirmedNapRecord {
        ConfirmedNapRecord(
            id: session.id,
            sessionID: session.id,
            interval: interval,
            source: session.decisionSource,
            algorithmVersion: session.algorithmVersion,
            confirmedAt: confirmedAt,
            healthKitSampleIdentifier: session.healthKitSampleIdentifier
        )
    }

    private func applying(
        corrections: [NapCorrection],
        to decision: NapDetectionDecision
    ) -> NapDetectionDecision {
        guard let latest = corrections.sorted(by: {
            $0.createdAt == $1.createdAt
                ? $0.id.uuidString < $1.id.uuidString
                : $0.createdAt < $1.createdAt
        }).last else {
            return decision
        }
        switch latest.kind {
        case .exclude:
            return userDecision(from: decision, state: .excluded, interval: nil)
        case .confirm, .correct:
            return userDecision(from: decision, state: .confirmed, interval: latest.interval ?? decision.interval)
        }
    }

    private func nextCorrectionDate(sessionID: UUID) throws -> Date {
        let current = now()
        guard let latest = try store.corrections(sessionID: sessionID).last,
              latest.createdAt >= current else { return current }
        return latest.createdAt.addingTimeInterval(0.000_001)
    }

    private func userDecision(
        from decision: NapDetectionDecision,
        state: NapDetectionState,
        interval: NapInterval?
    ) -> NapDetectionDecision {
        NapDetectionDecision(
            id: decision.id,
            sessionID: decision.sessionID,
            state: state,
            source: .user,
            interval: interval,
            evidenceIDs: decision.evidenceIDs,
            appleStages: decision.appleStages,
            algorithmVersion: decision.algorithmVersion,
            policyVersion: decision.policyVersion,
            decidedAt: now()
        )
    }
}
