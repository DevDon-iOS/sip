//
//  NapObservationProcessor.swift
//  sip
//
//  Created by 이돈혁 on 8/21/26.
//

import Foundation

struct NapObservationNormalizer {
    func normalize(_ observations: [NapObservation], within candidate: NapInterval) -> [NapObservation] {
        var byKey: [String: NapObservation] = [:]
        for observation in observations where observation.schemaVersion > 0 {
            guard observation.interval.intersection(with: candidate) != nil else { continue }
            let key = observation.deduplicationKey
            if let existing = byKey[key] {
                byKey[key] = preferred(existing, observation)
            } else {
                byKey[key] = observation
            }
        }

        return byKey.values.sorted {
            if $0.interval.start != $1.interval.start { return $0.interval.start < $1.interval.start }
            if $0.interval.end != $1.interval.end { return $0.interval.end < $1.interval.end }
            if sourceRank($0.source) != sourceRank($1.source) {
                return sourceRank($0.source) < sourceRank($1.source)
            }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    func mergedIntervals(_ intervals: [NapInterval], maximumGap: TimeInterval) -> [NapInterval] {
        let ordered = intervals.sorted {
            $0.start == $1.start ? $0.end < $1.end : $0.start < $1.start
        }
        guard var current = ordered.first else { return [] }
        var result: [NapInterval] = []

        for interval in ordered.dropFirst() {
            if interval.start.timeIntervalSince(current.end) <= maximumGap {
                if let merged = try? NapInterval(start: current.start, end: max(current.end, interval.end)) {
                    current = merged
                }
            } else {
                result.append(current)
                current = interval
            }
        }
        result.append(current)
        return result
    }

    private func preferred(_ lhs: NapObservation, _ rhs: NapObservation) -> NapObservation {
        if sourceRank(lhs.source) != sourceRank(rhs.source) {
            return sourceRank(lhs.source) < sourceRank(rhs.source) ? lhs : rhs
        }
        if lhs.capturedAt != rhs.capturedAt { return lhs.capturedAt < rhs.capturedAt ? lhs : rhs }
        return lhs.id.uuidString < rhs.id.uuidString ? lhs : rhs
    }

    private func sourceRank(_ source: NapObservationSource) -> Int {
        switch source {
        case .appleHealth: 0
        case .directEntry: 1
        case .activeSession: 2
        case .watchMotion: 3
        case .heartRate: 4
        case .alarm: 5
        case .napWindow: 6
        }
    }
}

struct NapDetectionProcessor {
    private let normalizer = NapObservationNormalizer()

    func process(
        sessionID: UUID,
        candidate: NapInterval,
        observations: [NapObservation],
        policy: NapDetectionPolicy,
        now: Date
    ) -> NapDetectionDecision {
        let normalized = normalizer.normalize(observations, within: candidate)
        let appleSleep = normalized.filter {
            guard $0.source == .appleHealth,
                  case let .appleSleep(stage) = $0.kind else { return false }
            return stage.isAsleep
        }

        if !appleSleep.isEmpty {
            let merged = normalizer.mergedIntervals(
                appleSleep.compactMap { $0.interval.intersection(with: candidate) },
                maximumGap: 0
            )
            let interval = merged.max(by: { $0.duration < $1.duration })
            let stages = appleSleep.compactMap { observation -> AppleSleepStage? in
                guard case let .appleSleep(stage) = observation.kind else { return nil }
                return stage
            }
            return decision(
                sessionID: sessionID,
                state: .provisional,
                source: .appleHealth,
                interval: interval,
                evidence: appleSleep,
                appleStages: stages,
                policy: policy,
                now: now
            )
        }

        let inference = normalized.filter { $0.kind.supportsInference }
        guard !inference.isEmpty else {
            return decision(
                sessionID: sessionID,
                state: .noRecord,
                source: .none,
                interval: nil,
                evidence: normalized,
                policy: policy,
                now: now
            )
        }

        guard policy.validation == .validated,
              let minimumDuration = policy.minimumContinuousDuration,
              let mergeGap = policy.mergeGap else {
            return decision(
                sessionID: sessionID,
                state: .partialEvidence,
                source: .partial,
                interval: nil,
                evidence: inference,
                policy: policy,
                now: now
            )
        }

        let sources = Set(inference.map(\.source))
        guard policy.requiredInferenceSources.isSubset(of: sources) else {
            return decision(
                sessionID: sessionID,
                state: .partialEvidence,
                source: .partial,
                interval: nil,
                evidence: inference,
                policy: policy,
                now: now
            )
        }

        let merged = normalizer.mergedIntervals(
            inference.compactMap { $0.interval.intersection(with: candidate) },
            maximumGap: mergeGap
        )
        guard let longest = merged.max(by: { $0.duration < $1.duration }),
              longest.duration >= minimumDuration else {
            return decision(
                sessionID: sessionID,
                state: .partialEvidence,
                source: .partial,
                interval: nil,
                evidence: inference,
                policy: policy,
                now: now
            )
        }

        return decision(
            sessionID: sessionID,
            state: .provisional,
            source: .sipInference,
            interval: longest,
            evidence: inference,
            policy: policy,
            now: now
        )
    }

    private func decision(
        sessionID: UUID,
        state: NapDetectionState,
        source: NapDecisionSource,
        interval: NapInterval?,
        evidence: [NapObservation],
        appleStages: [AppleSleepStage] = [],
        policy: NapDetectionPolicy,
        now: Date
    ) -> NapDetectionDecision {
        NapDetectionDecision(
            id: UUID(),
            sessionID: sessionID,
            state: state,
            source: source,
            interval: interval,
            evidenceIDs: evidence.map(\.id),
            appleStages: appleStages,
            algorithmVersion: evidence.map(\.algorithmVersion).sorted().last ?? policy.version,
            policyVersion: policy.version,
            decidedAt: now
        )
    }
}
