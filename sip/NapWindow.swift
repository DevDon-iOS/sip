//
//  NapWindow.swift
//  sip
//
//  Created by 이돈혁 on 8/20/26.
//

import Foundation

struct NapWindow: Codable, Identifiable, Hashable {
    let id: UUID
    var startTime: Date
    var endTime: Date
    var activeWeekdays: Set<Weekday>
    var isEnabled: Bool
    var isEndAlarmEnabled: Bool
    var alarmTime: Date

    init(
        id: UUID = UUID(),
        startTime: Date,
        endTime: Date,
        activeWeekdays: Set<Weekday>,
        isEnabled: Bool = true,
        isEndAlarmEnabled: Bool = true,
        alarmTime: Date
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.activeWeekdays = activeWeekdays
        self.isEnabled = isEnabled
        self.isEndAlarmEnabled = isEndAlarmEnabled
        self.alarmTime = alarmTime
    }

    static var defaultDraft: NapWindow {
        NapWindow(
            startTime: time(hour: 13),
            endTime: time(hour: 14),
            activeWeekdays: [.monday, .tuesday, .wednesday, .thursday, .friday],
            alarmTime: time(hour: 14)
        )
    }

    static var figmaHomeFixtures: [NapWindow] {
        [
            defaultDraft,
            NapWindow(
                startTime: time(hour: 13),
                endTime: time(hour: 14),
                activeWeekdays: [.saturday, .sunday],
                isEnabled: false,
                isEndAlarmEnabled: false,
                alarmTime: time(hour: 14)
            )
        ]
    }

    var timeRange: String {
        "\(Self.timeFormatter.string(from: startTime))–\(Self.timeFormatter.string(from: endTime))"
    }

    var alarmTimeLabel: String {
        Self.timeFormatter.string(from: alarmTime)
    }

    private static func time(hour: Int, minute: Int = 0) -> Date {
        Calendar.current.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: .now
        ) ?? .now
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

enum Weekday: Int, CaseIterable, Codable, Identifiable, Hashable {
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
    case sunday

    var id: Int { rawValue }

    var shortName: String {
        switch self {
        case .monday: "월"
        case .tuesday: "화"
        case .wednesday: "수"
        case .thursday: "목"
        case .friday: "금"
        case .saturday: "토"
        case .sunday: "일"
        }
    }

    var fullName: String {
        switch self {
        case .monday: "월요일"
        case .tuesday: "화요일"
        case .wednesday: "수요일"
        case .thursday: "목요일"
        case .friday: "금요일"
        case .saturday: "토요일"
        case .sunday: "일요일"
        }
    }
}
