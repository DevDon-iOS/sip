//
//  HealthKitService.swift
//  sip
//
//  Created by 이돈혁 on 7/15/25.
//

import Foundation
import HealthKit

protocol HealthDataClient: Sendable {
    func requestAuthorization() async throws
    func fetchSleepObservations(
        sessionID: UUID,
        interval: NapInterval,
        algorithmVersion: String
    ) async throws -> [NapObservation]
    func fetchHeartRateObservations(
        sessionID: UUID,
        interval: NapInterval,
        algorithmVersion: String
    ) async throws -> [NapObservation]
    func saveConfirmedNap(_ record: ConfirmedNapRecord) async throws -> String
}

final class HealthKitService: HealthDataClient, @unchecked Sendable {
    static let shared = HealthKitService()
    private let healthStore: HKHealthStore

    init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw NapDetectionError.healthDataUnavailable
        }
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
              let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            throw NapDetectionError.healthDataUnavailable
        }
        do {
            try await healthStore.requestAuthorization(toShare: [sleepType], read: [sleepType, heartRateType])
        } catch {
            throw map(error, operation: .authorization)
        }
    }

    func fetchSleepObservations(
        sessionID: UUID,
        interval: NapInterval,
        algorithmVersion: String
    ) async throws -> [NapObservation] {
        guard HKHealthStore.isHealthDataAvailable(),
              let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw NapDetectionError.healthDataUnavailable
        }
        let samples: [HKCategorySample]
        do {
            samples = try await querySamples(
                type: sleepType,
                interval: interval,
                sortIdentifier: HKSampleSortIdentifierStartDate
            )
        } catch {
            throw map(error, operation: .read)
        }

        return samples.compactMap { sample in
            guard let stage = Self.sleepStage(value: sample.value),
                  let sampleInterval = try? NapInterval(start: sample.startDate, end: sample.endDate) else {
                return nil
            }
            let deviceIdentifier = [sample.device?.manufacturer, sample.device?.model, sample.device?.hardwareVersion]
                .compactMap { $0 }
                .joined(separator: ":")
            return NapObservation(
                id: sample.uuid,
                sessionID: sessionID,
                interval: sampleInterval,
                source: .appleHealth,
                kind: .appleSleep(stage: stage),
                provenance: NapObservationProvenance(
                    providerIdentifier: sample.uuid.uuidString,
                    sourceBundleIdentifier: sample.sourceRevision.source.bundleIdentifier,
                    sourceVersion: sample.sourceRevision.version,
                    deviceIdentifier: deviceIdentifier.isEmpty ? nil : deviceIdentifier,
                    metadata: ["productType": sample.sourceRevision.productType ?? ""]
                ),
                capturedAt: sample.endDate,
                algorithmVersion: algorithmVersion
            )
        }
    }

    func fetchHeartRateObservations(
        sessionID: UUID,
        interval: NapInterval,
        algorithmVersion: String
    ) async throws -> [NapObservation] {
        guard HKHealthStore.isHealthDataAvailable(),
              let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            throw NapDetectionError.healthDataUnavailable
        }
        let samples: [HKQuantitySample]
        do {
            samples = try await querySamples(
                type: heartRateType,
                interval: interval,
                sortIdentifier: HKSampleSortIdentifierStartDate
            )
        } catch {
            throw map(error, operation: .read)
        }
        let unit = HKUnit.count().unitDivided(by: .minute())
        return samples.compactMap { sample in
            let normalizedEnd = max(sample.endDate, sample.startDate.addingTimeInterval(0.001))
            guard let sampleInterval = try? NapInterval(start: sample.startDate, end: normalizedEnd) else {
                return nil
            }
            return NapObservation(
                id: sample.uuid,
                sessionID: sessionID,
                interval: sampleInterval,
                source: .heartRate,
                kind: .heartRate(beatsPerMinute: sample.quantity.doubleValue(for: unit)),
                provenance: NapObservationProvenance(
                    providerIdentifier: sample.uuid.uuidString,
                    sourceBundleIdentifier: sample.sourceRevision.source.bundleIdentifier,
                    sourceVersion: sample.sourceRevision.version
                ),
                capturedAt: sample.endDate,
                algorithmVersion: algorithmVersion
            )
        }
    }

    func saveConfirmedNap(_ record: ConfirmedNapRecord) async throws -> String {
        guard HKHealthStore.isHealthDataAvailable(),
              let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw NapDetectionError.healthDataUnavailable
        }
        let sample = HKCategorySample(
            type: sleepType,
            value: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            start: record.interval.start,
            end: record.interval.end,
            metadata: [
                "SIPSessionID": record.sessionID.uuidString,
                "SIPAlgorithmVersion": record.algorithmVersion,
                HKMetadataKeySyncIdentifier: "sip.nap.\(record.sessionID.uuidString)",
                HKMetadataKeySyncVersion: 1
            ]
        )
        do {
            try await healthStore.save(sample)
            return sample.uuid.uuidString
        } catch {
            throw map(error, operation: .write)
        }
    }

    func fetchRecentNaps() async throws -> [SleepRecord] {
        let now = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: now)
            ?? now.addingTimeInterval(-7 * 24 * 60 * 60)
        let interval = try NapInterval(start: startDate, end: now)
        return try await fetchSleepObservations(
            sessionID: UUID(),
            interval: interval,
            algorithmVersion: "apple-health-read-v1"
        )
        .filter {
            guard case let .appleSleep(stage) = $0.kind else { return false }
            return stage.isAsleep
        }
        .map { SleepRecord(id: $0.id, startDate: $0.interval.start, endDate: $0.interval.end) }
    }

    private func querySamples<Sample: HKSample>(
        type: HKSampleType,
        interval: NapInterval,
        sortIdentifier: String
    ) async throws -> [Sample] {
        let predicate = HKQuery.predicateForSamples(
            withStart: interval.start,
            end: interval.end,
            options: []
        )
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: sortIdentifier, ascending: true)]
            ) { _, result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: result as? [Sample] ?? [])
                }
            }
            healthStore.execute(query)
        }
    }

    private enum Operation { case authorization, read, write }

    private func map(_ error: Error, operation: Operation) -> NapDetectionError {
        let nsError = error as NSError
        if nsError.domain == HKError.errorDomain,
           nsError.code == HKError.Code.errorAuthorizationDenied.rawValue {
            return .healthAuthorizationDenied
        }
        switch operation {
        case .authorization, .read:
            return .healthReadFailed(error.localizedDescription)
        case .write:
            return .healthWriteFailed(error.localizedDescription)
        }
    }

    private static func sleepStage(value: Int) -> AppleSleepStage? {
        guard let value = HKCategoryValueSleepAnalysis(rawValue: value) else { return .unknown(value) }
        switch value {
        case .inBed: return .inBed
        case .asleepUnspecified: return .asleepUnspecified
        case .awake: return .awake
        case .asleepCore: return .core
        case .asleepDeep: return .deep
        case .asleepREM: return .rem
        @unknown default: return .unknown(value.rawValue)
        }
    }
}
