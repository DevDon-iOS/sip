//
//  NapDetectionDomain.swift
//  sip
//
//  Created by 이돈혁 on 8/21/26.
//

import Foundation

struct NapInterval: Codable, Hashable, Sendable {
    let start: Date
    let end: Date

    init(start: Date, end: Date) throws {
        guard start < end else { throw NapDetectionError.invalidInterval }
        self.start = start
        self.end = end
    }

    var duration: TimeInterval { end.timeIntervalSince(start) }

    func intersection(with other: NapInterval) -> NapInterval? {
        let start = max(start, other.start)
        let end = min(end, other.end)
        return try? NapInterval(start: start, end: end)
    }
}

enum NapObservationSource: String, Codable, CaseIterable, Sendable {
    case appleHealth
    case watchMotion
    case heartRate
    case napWindow
    case activeSession
    case alarm
    case directEntry
}

enum AppleSleepStage: Codable, Hashable, Sendable {
    case inBed
    case asleepUnspecified
    case awake
    case core
    case deep
    case rem
    case unknown(Int)

    var isAsleep: Bool {
        switch self {
        case .asleepUnspecified, .core, .deep, .rem:
            true
        case .inBed, .awake, .unknown:
            false
        }
    }

    var stableValue: String {
        switch self {
        case .inBed: "inBed"
        case .asleepUnspecified: "asleepUnspecified"
        case .awake: "awake"
        case .core: "core"
        case .deep: "deep"
        case .rem: "rem"
        case let .unknown(value): "unknown:\(value)"
        }
    }
}

enum NapObservationKind: Codable, Hashable, Sendable {
    case appleSleep(stage: AppleSleepStage)
    case heartRate(beatsPerMinute: Double)
    case motion(activity: String, confidence: Int)
    case napWindow(alarmEnabled: Bool)
    case activeSession
    case alarm(isEnabled: Bool)
    case directStart
    case directEnd

    var supportsInference: Bool {
        switch self {
        case .heartRate, .motion, .activeSession, .directStart, .directEnd:
            true
        case .appleSleep, .napWindow, .alarm:
            false
        }
    }

    var stableValue: String {
        switch self {
        case let .appleSleep(stage): "appleSleep:\(stage.stableValue)"
        case let .heartRate(beatsPerMinute): "heartRate:\(beatsPerMinute)"
        case let .motion(activity, confidence): "motion:\(activity):\(confidence)"
        case let .napWindow(alarmEnabled): "napWindow:\(alarmEnabled)"
        case .activeSession: "activeSession"
        case let .alarm(isEnabled): "alarm:\(isEnabled)"
        case .directStart: "directStart"
        case .directEnd: "directEnd"
        }
    }
}

struct NapObservationProvenance: Codable, Hashable, Sendable {
    let providerIdentifier: String?
    let sourceBundleIdentifier: String?
    let sourceVersion: String?
    let deviceIdentifier: String?
    let metadata: [String: String]

    init(
        providerIdentifier: String? = nil,
        sourceBundleIdentifier: String? = nil,
        sourceVersion: String? = nil,
        deviceIdentifier: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.providerIdentifier = providerIdentifier
        self.sourceBundleIdentifier = sourceBundleIdentifier
        self.sourceVersion = sourceVersion
        self.deviceIdentifier = deviceIdentifier
        self.metadata = metadata
    }
}

struct NapObservation: Codable, Hashable, Identifiable, Sendable {
    static let currentSchemaVersion = 1

    let id: UUID
    let sessionID: UUID
    let interval: NapInterval
    let source: NapObservationSource
    let kind: NapObservationKind
    let provenance: NapObservationProvenance
    let capturedAt: Date
    let schemaVersion: Int
    let algorithmVersion: String

    init(
        id: UUID = UUID(),
        sessionID: UUID,
        interval: NapInterval,
        source: NapObservationSource,
        kind: NapObservationKind,
        provenance: NapObservationProvenance = .init(),
        capturedAt: Date,
        schemaVersion: Int = currentSchemaVersion,
        algorithmVersion: String
    ) {
        self.id = id
        self.sessionID = sessionID
        self.interval = interval
        self.source = source
        self.kind = kind
        self.provenance = provenance
        self.capturedAt = capturedAt
        self.schemaVersion = schemaVersion
        self.algorithmVersion = algorithmVersion
    }

    var deduplicationKey: String {
        if let providerIdentifier = provenance.providerIdentifier {
            return "provider:\(source.rawValue):\(providerIdentifier)"
        }
        return [
            source.rawValue,
            interval.start.timeIntervalSinceReferenceDate.description,
            interval.end.timeIntervalSinceReferenceDate.description,
            kind.stableValue,
            provenance.sourceBundleIdentifier ?? "",
            provenance.deviceIdentifier ?? ""
        ].joined(separator: "|")
    }
}

enum NapDetectionState: String, Codable, Sendable {
    case noRecord
    case partialEvidence
    case provisional
    case confirmed
    case excluded
}

enum NapDecisionSource: String, Codable, Sendable {
    case none
    case partial
    case sipInference
    case appleHealth
    case user
}

struct NapDetectionDecision: Codable, Identifiable, Sendable {
    let id: UUID
    let sessionID: UUID
    let state: NapDetectionState
    let source: NapDecisionSource
    let interval: NapInterval?
    let evidenceIDs: [UUID]
    let appleStages: [AppleSleepStage]
    let algorithmVersion: String
    let policyVersion: String
    let decidedAt: Date

    var fingerprint: String {
        [
            sessionID.uuidString,
            state.rawValue,
            source.rawValue,
            interval?.start.timeIntervalSinceReferenceDate.description ?? "",
            interval?.end.timeIntervalSinceReferenceDate.description ?? "",
            evidenceIDs.map(\.uuidString).sorted().joined(separator: ","),
            appleStages.map(\.stableValue).joined(separator: ","),
            algorithmVersion,
            policyVersion
        ].joined(separator: "|")
    }
}

enum NapCorrectionKind: String, Codable, Sendable {
    case confirm
    case correct
    case exclude
}

struct NapCorrection: Codable, Identifiable, Sendable {
    let id: UUID
    let sessionID: UUID
    let kind: NapCorrectionKind
    let interval: NapInterval?
    let createdAt: Date
}

struct ConfirmedNapRecord: Codable, Identifiable, Sendable {
    let id: UUID
    let sessionID: UUID
    let interval: NapInterval
    let source: NapDecisionSource
    let algorithmVersion: String
    let confirmedAt: Date
    let healthKitSampleIdentifier: String?
}

enum DetectionPolicyValidation: String, Codable, Sendable {
    case unvalidated
    case validated
}

struct NapDetectionPolicy: Codable, Sendable {
    let version: String
    let validation: DetectionPolicyValidation
    let minimumContinuousDuration: TimeInterval?
    let mergeGap: TimeInterval?
    let requiredInferenceSources: Set<NapObservationSource>

    static let production = NapDetectionPolicy(
        version: "unvalidated-production-v1",
        validation: .unvalidated,
        minimumContinuousDuration: nil,
        mergeGap: nil,
        requiredInferenceSources: []
    )

    static func validatedFixture(
        version: String = "fixture-v1",
        minimumContinuousDuration: TimeInterval,
        mergeGap: TimeInterval = 0,
        requiredInferenceSources: Set<NapObservationSource> = []
    ) -> NapDetectionPolicy {
        NapDetectionPolicy(
            version: version,
            validation: .validated,
            minimumContinuousDuration: minimumContinuousDuration,
            mergeGap: mergeGap,
            requiredInferenceSources: requiredInferenceSources
        )
    }
}

enum HealthDataAvailability: Sendable {
    case available
    case unavailable
    case denied
}

enum NapDetectionError: Error, Equatable, Sendable {
    case invalidInterval
    case missingSession
    case policyUnvalidated
    case healthDataUnavailable
    case healthAuthorizationDenied
    case healthReadFailed(String)
    case healthWriteFailed(String)
    case unconfirmedHealthWrite
    case persistenceFailed(String)
}
