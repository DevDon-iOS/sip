//
//  NapWindowStorage.swift
//  sip
//
//  Created by 이돈혁 on 8/20/26.
//

import Foundation
import OSLog

enum NapWindowStorage {
    private static let storageKey = "sip.napWindows.v1"
    private static let logger = Logger(subsystem: "com.codling.sip", category: "NapWindowStorage")

    static func load() -> [NapWindow]? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        do {
            return try JSONDecoder().decode([NapWindow].self, from: data)
        } catch {
            logger.error("시간대를 불러오지 못했습니다: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    static func save(_ windows: [NapWindow]) {
        do {
            let data = try JSONEncoder().encode(windows)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            logger.error("시간대를 저장하지 못했습니다: \(error.localizedDescription, privacy: .public)")
        }
    }
}
