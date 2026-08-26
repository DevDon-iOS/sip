//
//  AppDataManagement.swift
//  sip
//
//  Created by 이돈혁 on 8/20/26.
//

import Foundation
import SwiftUI
import UIKit

enum AppDataManagement {
    static func makeExportFile(now: Date = .now) throws -> URL {
        let payload = AppDataExport(
            version: 1,
            exportedAt: now,
            napWindows: NapWindowStorage.load() ?? [],
            activeNapSession: ActiveNapSessionStorage.load(),
            conditionCheckIns: ConditionCheckInStorage.load()
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

        let data = try encoder.encode(payload)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let fileName = "sip-export-\(formatter.string(from: now)).json"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    @MainActor
    static func deleteLocalData() {
        let activeSession = ActiveNapSessionStorage.load()
        NapWindowStorage.removeAll()
        ActiveNapSessionStorage.remove()
        ConditionCheckInStorage.removeAll()
        UserDefaults.standard.removeObject(forKey: "statusReminderEnabled")
        if let activeSession {
            PhoneConnectivityCoordinator.shared.notifySessionEnded(activeSession.id)
        }
        NotificationCenter.default.post(name: .localAppDataDidChange, object: nil)
        PhoneConnectivityCoordinator.shared.publish(windows: [], activeSession: nil)
    }
}

private struct AppDataExport: Codable {
    let version: Int
    let exportedAt: Date
    let napWindows: [NapWindow]
    let activeNapSession: ActiveNapSession?
    let conditionCheckIns: [ConditionCheckIn]
}

struct ActivityShareView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ExportFile: Identifiable {
    let id = UUID()
    let url: URL
}

extension Notification.Name {
    static let localAppDataDidChange = Notification.Name("sip.localAppDataDidChange")
}
