//
//  SleepRecord.swift
//  sip
//
//  Created by 이돈혁 on 7/14/25.
//

import Foundation

struct SleepRecord: Codable, Identifiable, Hashable {
    let id: UUID
    let startDate: Date
    let endDate: Date

    init(id: UUID = UUID(), startDate: Date, endDate: Date) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
    }

    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }

    var durationMinutes: Int {
        max(1, Int((duration / 60).rounded()))
    }

    var timeRangeLabel: String {
        "\(Self.timeFormatter.string(from: startDate))–\(Self.timeFormatter.string(from: endDate))"
    }

    var dayLabel: String {
        Calendar.current.isDateInToday(endDate)
            ? "오늘"
            : Self.dayFormatter.string(from: endDate)
    }

    var dateLabel: String {
        "\(dayLabel) · \(Self.timeFormatter.string(from: endDate))"
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일"
        return formatter
    }()
}
