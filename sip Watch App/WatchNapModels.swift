//
//  WatchNapModels.swift
//  sip Watch App
//
//  Created by 이돈혁 on 8/20/26.
//

import Foundation

struct WatchNapWindowSnapshot: Codable, Equatable {
    let id: UUID
    var endMinutes: Int
    var alarmMinutes: Int
    var isAlarmEnabled: Bool

    func nextEndAlarm(after date: Date, calendar: Calendar = .current) -> Date {
        let selectedMinutes = isAlarmEnabled ? alarmMinutes : endMinutes
        let hour = selectedMinutes / 60
        let minute = selectedMinutes % 60
        let today = calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: date
        ) ?? date.addingTimeInterval(60 * 60)

        if today > date {
            return today
        }
        return calendar.date(byAdding: .day, value: 1, to: today) ?? today
    }
}

struct WatchNapSession: Codable, Equatable, Identifiable {
    let id: UUID
    let windowID: UUID
    let startedAt: Date
    var endAlarmAt: Date

    func elapsedInterval(at date: Date) -> TimeInterval {
        max(0, date.timeIntervalSince(startedAt))
    }

    func elapsedLabel(at date: Date) -> String {
        let totalSeconds = Int(elapsedInterval(at: date))
        if totalSeconds < 60 * 60 {
            return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
        }
        return String(format: "%02d:%02d", totalSeconds / 3600, (totalSeconds % 3600) / 60)
    }

    func progress(at date: Date) -> Double {
        let plannedDuration = endAlarmAt.timeIntervalSince(startedAt)
        guard plannedDuration > 0 else { return 0 }
        return min(max(elapsedInterval(at: date) / plannedDuration, 0), 1)
    }
}

struct WatchSyncEvent: Codable, Equatable, Identifiable {
    enum Kind: String, Codable {
        case sessionStarted
        case sessionEnded
        case alarmUpdated
    }

    let id: UUID
    let kind: Kind
    let createdAt: Date
    let session: WatchNapSession?
    let windowID: UUID?
    let alarmMinutes: Int?
    let isAlarmEnabled: Bool?

    static func session(_ session: WatchNapSession, kind: Kind) -> WatchSyncEvent {
        WatchSyncEvent(
            id: UUID(),
            kind: kind,
            createdAt: .now,
            session: session,
            windowID: nil,
            alarmMinutes: nil,
            isAlarmEnabled: nil
        )
    }

    static func alarm(window: WatchNapWindowSnapshot) -> WatchSyncEvent {
        WatchSyncEvent(
            id: UUID(),
            kind: .alarmUpdated,
            createdAt: .now,
            session: nil,
            windowID: window.id,
            alarmMinutes: window.alarmMinutes,
            isAlarmEnabled: window.isAlarmEnabled
        )
    }
}

struct WatchNormalizedObservation: Codable, Equatable, Identifiable {
    enum Kind: String, Codable {
        case motion
        case activeSession
        case directStart
        case directEnd
    }

    static let currentSchemaVersion = 1

    let id: UUID
    let sessionID: UUID
    let sequence: Int
    let start: Date
    let end: Date
    let kind: Kind
    let activity: String?
    let confidence: Int?
    let capturedAt: Date
    let timeZoneIdentifier: String
    let schemaVersion: Int
    let algorithmVersion: String
    let providerIdentifier: String?
    let sourceBundleIdentifier: String?
    let sourceVersion: String?
    let deviceIdentifier: String?
    let metadata: [String: String]?

    init(
        id: UUID = UUID(),
        sessionID: UUID,
        sequence: Int,
        start: Date,
        end: Date,
        kind: Kind,
        activity: String? = nil,
        confidence: Int? = nil,
        capturedAt: Date,
        timeZoneIdentifier: String = TimeZone.current.identifier,
        schemaVersion: Int = currentSchemaVersion,
        algorithmVersion: String,
        providerIdentifier: String? = nil,
        sourceBundleIdentifier: String? = nil,
        sourceVersion: String? = nil,
        deviceIdentifier: String? = nil,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.sessionID = sessionID
        self.sequence = sequence
        self.start = start
        self.end = end
        self.kind = kind
        self.activity = activity
        self.confidence = confidence
        self.capturedAt = capturedAt
        self.timeZoneIdentifier = timeZoneIdentifier
        self.schemaVersion = schemaVersion
        self.algorithmVersion = algorithmVersion
        self.providerIdentifier = providerIdentifier
        self.sourceBundleIdentifier = sourceBundleIdentifier
        self.sourceVersion = sourceVersion
        self.deviceIdentifier = deviceIdentifier
        self.metadata = metadata
    }

    var deduplicationKey: String {
        "\(sessionID.uuidString)|\(providerIdentifier ?? id.uuidString)"
    }
}
