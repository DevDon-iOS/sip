//
//  NapDetectionStore.swift
//  sip
//
//  Created by 이돈혁 on 8/21/26.
//

import Foundation
import SwiftData

enum NapDetectionSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [
            NapDetectionSessionModel.self,
            NapObservationModel.self,
            NapDecisionModel.self,
            NapCorrectionModel.self
        ]
    }
}

enum NapDetectionMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [NapDetectionSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

@Model
final class NapDetectionSessionModel {
    @Attribute(.unique) var id: UUID
    var windowID: UUID?
    var candidateStart: Date
    var candidateEnd: Date
    var timeZoneIdentifier: String
    var stateRawValue: String
    var decisionSourceRawValue: String
    var detectedStart: Date?
    var detectedEnd: Date?
    var algorithmVersion: String
    var createdAt: Date
    var updatedAt: Date
    var confirmedAt: Date?
    var healthKitSavedAt: Date?
    var healthKitSampleIdentifier: String?

    init(
        id: UUID,
        windowID: UUID?,
        candidate: NapInterval,
        timeZoneIdentifier: String,
        algorithmVersion: String,
        now: Date
    ) {
        self.id = id
        self.windowID = windowID
        candidateStart = candidate.start
        candidateEnd = candidate.end
        self.timeZoneIdentifier = timeZoneIdentifier
        stateRawValue = NapDetectionState.noRecord.rawValue
        decisionSourceRawValue = NapDecisionSource.none.rawValue
        self.algorithmVersion = algorithmVersion
        createdAt = now
        updatedAt = now
    }

    var candidate: NapInterval? { try? NapInterval(start: candidateStart, end: candidateEnd) }
    var state: NapDetectionState { NapDetectionState(rawValue: stateRawValue) ?? .noRecord }
    var decisionSource: NapDecisionSource { NapDecisionSource(rawValue: decisionSourceRawValue) ?? .none }
    var detectedInterval: NapInterval? {
        guard let detectedStart, let detectedEnd else { return nil }
        return try? NapInterval(start: detectedStart, end: detectedEnd)
    }
}

@Model
final class NapObservationModel {
    @Attribute(.unique) var id: UUID
    var sessionID: UUID
    var deduplicationKey: String
    var start: Date
    var end: Date
    var sourceRawValue: String
    var kindData: Data
    var provenanceData: Data
    var capturedAt: Date
    var schemaVersion: Int
    var algorithmVersion: String

    init(observation: NapObservation) throws {
        id = observation.id
        sessionID = observation.sessionID
        deduplicationKey = observation.deduplicationKey
        start = observation.interval.start
        end = observation.interval.end
        sourceRawValue = observation.source.rawValue
        kindData = try JSONEncoder().encode(observation.kind)
        provenanceData = try JSONEncoder().encode(observation.provenance)
        capturedAt = observation.capturedAt
        schemaVersion = observation.schemaVersion
        algorithmVersion = observation.algorithmVersion
    }

    func domainValue() throws -> NapObservation {
        guard let source = NapObservationSource(rawValue: sourceRawValue) else {
            throw NapDetectionError.persistenceFailed("Unknown observation source")
        }
        return NapObservation(
            id: id,
            sessionID: sessionID,
            interval: try NapInterval(start: start, end: end),
            source: source,
            kind: try JSONDecoder().decode(NapObservationKind.self, from: kindData),
            provenance: try JSONDecoder().decode(NapObservationProvenance.self, from: provenanceData),
            capturedAt: capturedAt,
            schemaVersion: schemaVersion,
            algorithmVersion: algorithmVersion
        )
    }
}

@Model
final class NapDecisionModel {
    @Attribute(.unique) var id: UUID
    var sessionID: UUID
    @Attribute(.unique) var fingerprint: String
    var payload: Data
    var decidedAt: Date

    init(decision: NapDetectionDecision) throws {
        id = decision.id
        sessionID = decision.sessionID
        fingerprint = decision.fingerprint
        payload = try JSONEncoder().encode(decision)
        decidedAt = decision.decidedAt
    }

    func domainValue() throws -> NapDetectionDecision {
        try JSONDecoder().decode(NapDetectionDecision.self, from: payload)
    }
}

@Model
final class NapCorrectionModel {
    @Attribute(.unique) var id: UUID
    var sessionID: UUID
    var payload: Data
    var createdAt: Date

    init(correction: NapCorrection) throws {
        id = correction.id
        sessionID = correction.sessionID
        payload = try JSONEncoder().encode(correction)
        createdAt = correction.createdAt
    }

    func domainValue() throws -> NapCorrection {
        try JSONDecoder().decode(NapCorrection.self, from: payload)
    }
}

@MainActor
protocol NapDetectionStore: AnyObject {
    func upsertSession(
        id: UUID,
        windowID: UUID?,
        candidate: NapInterval,
        timeZoneIdentifier: String,
        algorithmVersion: String,
        now: Date
    ) throws
    func session(id: UUID) throws -> NapDetectionSessionModel?
    func sessions() throws -> [NapDetectionSessionModel]
    func upsertObservations(_ observations: [NapObservation]) throws
    func observations(sessionID: UUID) throws -> [NapObservation]
    func saveDecision(_ decision: NapDetectionDecision) throws
    func decision(sessionID: UUID) throws -> NapDetectionDecision?
    func decisions(sessionID: UUID) throws -> [NapDetectionDecision]
    func saveCorrection(_ correction: NapCorrection) throws
    func corrections(sessionID: UUID) throws -> [NapCorrection]
    func deleteAll() throws
    func saveChanges() throws
}

@MainActor
final class SwiftDataNapDetectionStore: NapDetectionStore {
    let container: ModelContainer
    private let context: ModelContext

    init(inMemory: Bool = false) throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        do {
            container = try ModelContainer(
                for: NapDetectionSessionModel.self,
                NapObservationModel.self,
                NapDecisionModel.self,
                NapCorrectionModel.self,
                migrationPlan: NapDetectionMigrationPlan.self,
                configurations: configuration
            )
            context = ModelContext(container)
            context.autosaveEnabled = false
        } catch {
            throw NapDetectionError.persistenceFailed(error.localizedDescription)
        }
    }

    init(container: ModelContainer) {
        self.container = container
        context = ModelContext(container)
        context.autosaveEnabled = false
    }

    func upsertSession(
        id: UUID,
        windowID: UUID?,
        candidate: NapInterval,
        timeZoneIdentifier: String,
        algorithmVersion: String,
        now: Date
    ) throws {
        if let existing = try session(id: id) {
            existing.windowID = windowID
            existing.candidateStart = min(existing.candidateStart, candidate.start)
            existing.candidateEnd = max(existing.candidateEnd, candidate.end)
            if existing.timeZoneIdentifier.isEmpty {
                existing.timeZoneIdentifier = timeZoneIdentifier
            }
            existing.algorithmVersion = algorithmVersion
            existing.updatedAt = now
        } else {
            context.insert(
                NapDetectionSessionModel(
                    id: id,
                    windowID: windowID,
                    candidate: candidate,
                    timeZoneIdentifier: timeZoneIdentifier,
                    algorithmVersion: algorithmVersion,
                    now: now
                )
            )
        }
        try saveChanges()
    }

    func session(id: UUID) throws -> NapDetectionSessionModel? {
        var descriptor = FetchDescriptor<NapDetectionSessionModel>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func sessions() throws -> [NapDetectionSessionModel] {
        var descriptor = FetchDescriptor<NapDetectionSessionModel>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.includePendingChanges = true
        return try context.fetch(descriptor)
    }

    func upsertObservations(_ observations: [NapObservation]) throws {
        for observation in observations {
            let observationID = observation.id
            let sessionID = observation.sessionID
            let deduplicationKey = observation.deduplicationKey
            var descriptor = FetchDescriptor<NapObservationModel>(
                predicate: #Predicate {
                    $0.id == observationID
                        || ($0.sessionID == sessionID && $0.deduplicationKey == deduplicationKey)
                }
            )
            descriptor.fetchLimit = 1
            if try context.fetch(descriptor).isEmpty {
                context.insert(try NapObservationModel(observation: observation))
            }
        }
        try saveChanges()
    }

    func observations(sessionID: UUID) throws -> [NapObservation] {
        let descriptor = FetchDescriptor<NapObservationModel>(
            predicate: #Predicate { $0.sessionID == sessionID },
            sortBy: [SortDescriptor(\.start), SortDescriptor(\.end)]
        )
        return try context.fetch(descriptor).map { try $0.domainValue() }
    }

    func saveDecision(_ decision: NapDetectionDecision) throws {
        let fingerprint = decision.fingerprint
        var descriptor = FetchDescriptor<NapDecisionModel>(
            predicate: #Predicate { $0.fingerprint == fingerprint }
        )
        descriptor.fetchLimit = 1
        if try context.fetch(descriptor).isEmpty {
            context.insert(try NapDecisionModel(decision: decision))
        }
        guard let session = try session(id: decision.sessionID) else {
            throw NapDetectionError.missingSession
        }
        session.stateRawValue = decision.state.rawValue
        session.decisionSourceRawValue = decision.source.rawValue
        session.detectedStart = decision.interval?.start
        session.detectedEnd = decision.interval?.end
        session.algorithmVersion = decision.algorithmVersion
        session.updatedAt = decision.decidedAt
        try saveChanges()
    }

    func decision(sessionID: UUID) throws -> NapDetectionDecision? {
        try decisionModel(sessionID: sessionID)?.domainValue()
    }

    func decisions(sessionID: UUID) throws -> [NapDetectionDecision] {
        let descriptor = FetchDescriptor<NapDecisionModel>(
            predicate: #Predicate { $0.sessionID == sessionID },
            sortBy: [SortDescriptor(\.decidedAt), SortDescriptor(\.fingerprint)]
        )
        return try context.fetch(descriptor).map { try $0.domainValue() }
    }

    func saveCorrection(_ correction: NapCorrection) throws {
        let correctionID = correction.id
        var descriptor = FetchDescriptor<NapCorrectionModel>(
            predicate: #Predicate { $0.id == correctionID }
        )
        descriptor.fetchLimit = 1
        if try context.fetch(descriptor).isEmpty {
            context.insert(try NapCorrectionModel(correction: correction))
        }
        try saveChanges()
    }

    func corrections(sessionID: UUID) throws -> [NapCorrection] {
        let descriptor = FetchDescriptor<NapCorrectionModel>(
            predicate: #Predicate { $0.sessionID == sessionID },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try context.fetch(descriptor).map { try $0.domainValue() }
    }

    func deleteAll() throws {
        do {
            try context.delete(model: NapCorrectionModel.self)
            try context.delete(model: NapDecisionModel.self)
            try context.delete(model: NapObservationModel.self)
            try context.delete(model: NapDetectionSessionModel.self)
            try saveChanges()
        } catch let error as NapDetectionError {
            throw error
        } catch {
            throw NapDetectionError.persistenceFailed(error.localizedDescription)
        }
    }

    func saveChanges() throws {
        do {
            try context.save()
        } catch {
            throw NapDetectionError.persistenceFailed(error.localizedDescription)
        }
    }

    private func decisionModel(sessionID: UUID) throws -> NapDecisionModel? {
        var descriptor = FetchDescriptor<NapDecisionModel>(
            predicate: #Predicate { $0.sessionID == sessionID },
            sortBy: [SortDescriptor(\.decidedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
