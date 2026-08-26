//
//  WatchObservationOutbox.swift
//  sip Watch App
//
//  Created by 이돈혁 on 8/21/26.
//

import Foundation

@MainActor
final class WatchObservationOutbox {
    private(set) var observations: [WatchNormalizedObservation]
    private let fileURL: URL

    init(fileURL: URL? = nil) throws {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let directory = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("NapDetection", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            self.fileURL = directory.appendingPathComponent("watch-observation-outbox-v1.json")
        }

        if FileManager.default.fileExists(atPath: self.fileURL.path) {
            observations = try JSONDecoder().decode(
                [WatchNormalizedObservation].self,
                from: Data(contentsOf: self.fileURL)
            )
        } else {
            observations = []
        }
    }

    func enqueue(_ observation: WatchNormalizedObservation) throws {
        guard !observations.contains(where: { $0.id == observation.id }) else { return }
        observations.append(observation)
        observations.sort {
            if $0.sequence != $1.sequence { return $0.sequence < $1.sequence }
            if $0.capturedAt != $1.capturedAt { return $0.capturedAt < $1.capturedAt }
            return $0.id.uuidString < $1.id.uuidString
        }
        try persist()
    }

    func markDelivered(id: UUID) throws {
        observations.removeAll { $0.id == id }
        try persist()
    }

    private func persist() throws {
        let data = try JSONEncoder().encode(observations)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
