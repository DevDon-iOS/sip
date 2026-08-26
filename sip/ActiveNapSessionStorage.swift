//
//  ActiveNapSessionStorage.swift
//  sip
//
//  Created by 이돈혁 on 8/20/26.
//

import Foundation
import OSLog

enum ActiveNapSessionStorage {
    private static let storageKey = "sip.activeNapSession.v1"
    private static let logger = Logger(subsystem: "com.codling.sip", category: "ActiveNapSessionStorage")

    static func load() -> ActiveNapSession? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        do {
            return try JSONDecoder().decode(ActiveNapSession.self, from: data)
        } catch {
            logger.error("활성 세션을 불러오지 못했습니다: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    static func save(_ session: ActiveNapSession) {
        do {
            let data = try JSONEncoder().encode(session)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            logger.error("활성 세션을 저장하지 못했습니다: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func remove() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
