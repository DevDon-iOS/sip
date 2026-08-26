//
//  NapWindowStorage.swift
//  sip
//
//  Created by 이돈혁 on 8/20/26.
//

import Foundation

enum NapWindowStorage {
    private static let storageKey = "sip.napWindows.v1"

    static func load() -> [NapWindow]? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode([NapWindow].self, from: data)
    }

    static func save(_ windows: [NapWindow]) {
        guard let data = try? JSONEncoder().encode(windows) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
