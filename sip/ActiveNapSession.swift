//
//  ActiveNapSession.swift
//  sip
//
//  Created by 이돈혁 on 8/20/26.
//

import Foundation

struct ActiveNapSession: Codable, Identifiable, Hashable {
    let id: UUID
    let windowID: UUID?
    let startedAt: Date
    var endAlarmAt: Date

    init(
        id: UUID = UUID(),
        windowID: UUID?,
        startedAt: Date,
        endAlarmAt: Date
    ) {
        self.id = id
        self.windowID = windowID
        self.startedAt = startedAt
        self.endAlarmAt = endAlarmAt
    }

    static func instant(now: Date = .now, calendar: Calendar = .current) -> ActiveNapSession {
        let endAlarmAt = calendar.date(byAdding: .hour, value: 1, to: now)
            ?? now.addingTimeInterval(60 * 60)
        return ActiveNapSession(
            windowID: nil,
            startedAt: now,
            endAlarmAt: endAlarmAt
        )
    }

    func elapsedMinutes(at date: Date) -> Int {
        max(0, Int(date.timeIntervalSince(startedAt) / 60))
    }

    mutating func extendAlarm(by minutes: Int, calendar: Calendar = .current) {
        guard let extendedAlarm = calendar.date(
            byAdding: .minute,
            value: minutes,
            to: endAlarmAt
        ) else { return }
        endAlarmAt = extendedAlarm
    }
}

#if DEBUG
extension ActiveNapSession {
    static var figmaPreviewNow: Date {
        Calendar.current.date(
            bySettingHour: 13,
            minute: 40,
            second: 0,
            of: .now
        ) ?? .now
    }

    static var figmaPreview: ActiveNapSession {
        let now = figmaPreviewNow
        let startedAt = Calendar.current.date(
            bySettingHour: 13,
            minute: 8,
            second: 0,
            of: now
        ) ?? now.addingTimeInterval(-32 * 60)
        let alarmAt = Calendar.current.date(
            bySettingHour: 14,
            minute: 0,
            second: 0,
            of: now
        ) ?? now.addingTimeInterval(20 * 60)

        return ActiveNapSession(
            windowID: NapWindow.defaultDraft.id,
            startedAt: startedAt,
            endAlarmAt: alarmAt
        )
    }
}
#endif
