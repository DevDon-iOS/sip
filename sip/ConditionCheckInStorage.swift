//
//  ConditionCheckInStorage.swift
//  sip
//
//  Created by 이돈혁 on 8/20/26.
//

import Foundation
import OSLog

enum ConditionCheckInStorage {
    private static let storageKey = "sip.conditionCheckIns.v1"
    private static let logger = Logger(subsystem: "com.codling.sip", category: "ConditionCheckInStorage")

    static func load() -> [ConditionCheckIn] {
        do {
            return try read()
        } catch {
            logger.error("기상 상태를 불러오지 못했습니다: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    static func save(_ checkIn: ConditionCheckIn) throws {
        var checkIns = try read()
        let matchingIndex = checkIns.firstIndex { stored in
            stored.id == checkIn.id
                || (checkIn.napSessionID != nil && stored.napSessionID == checkIn.napSessionID)
        }
        if let index = matchingIndex {
            checkIns[index] = checkIn
        } else {
            checkIns.append(checkIn)
        }
        let data = try JSONEncoder().encode(checkIns)
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    static func checkIn(for napSessionID: UUID) -> ConditionCheckIn? {
        load()
            .filter { $0.napSessionID == napSessionID }
            .max { $0.updatedAt < $1.updatedAt }
    }

    static func removeAll() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    private static func read() throws -> [ConditionCheckIn] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
        return try JSONDecoder().decode([ConditionCheckIn].self, from: data)
    }
}
