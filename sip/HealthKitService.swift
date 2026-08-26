//
//  HealthKitService.swift
//  sip
//
//  Created by 이돈혁 on 7/15/25.
//

import Foundation
import HealthKit

final class HealthKitService {
    static let shared = HealthKitService()
    private let healthStore = HKHealthStore()

    // MARK: - Request Authorization
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw NSError(domain: "HealthKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "Health data not available on this device."])
        }

        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        try await healthStore.requestAuthorization(toShare: [sleepType], read: [sleepType])
    }

    // MARK: - Save Nap Record
    func saveNap(startDate: Date, endDate: Date) async throws {
        let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
        let napValue = HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue

        let sample = HKCategorySample(
            type: sleepType,
            value: napValue,
            start: startDate,
            end: endDate
        )

        try await healthStore.save(sample)
    }

    // MARK: - Fetch Recent Naps (Last 7 Days)
    func fetchRecentNaps() async throws -> [SleepRecord] {
        let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
        let now = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: now)!

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let results = result as? [HKCategorySample] else {
                    continuation.resume(returning: [])
                    return
                }

                continuation.resume(returning: results)
            }

            healthStore.execute(query)
        }

        let naps = samples
            .filter { $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue }
            .map {
                SleepRecord(
                    id: $0.uuid,
                    startDate: $0.startDate,
                    endDate: $0.endDate
                )
            }

        return naps
    }
}
