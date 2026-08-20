//
//  ConditionCheckIn.swift
//  sip
//
//  Created by 이돈혁 on 8/20/26.
//

import Foundation

struct ConditionCheckIn: Codable, Identifiable, Hashable {
    let id: UUID
    let napSessionID: UUID?
    let energy: Double
    let focus: Double
    let mood: Double
    let recordedAt: Date
    let updatedAt: Date

    init(
        id: UUID = UUID(),
        napSessionID: UUID?,
        energy: Double,
        focus: Double,
        mood: Double,
        recordedAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.napSessionID = napSessionID
        self.energy = Self.normalized(energy)
        self.focus = Self.normalized(focus)
        self.mood = Self.normalized(mood)
        self.recordedAt = recordedAt
        self.updatedAt = updatedAt
    }

    private static func normalized(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

#if DEBUG
extension ConditionCheckIn {
    static func figmaSaved(for record: SleepRecord) -> ConditionCheckIn {
        ConditionCheckIn(
            napSessionID: record.id,
            energy: 0.82,
            focus: 0.78,
            mood: 0.8
        )
    }
}
#endif
