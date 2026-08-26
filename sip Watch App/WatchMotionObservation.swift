//
//  WatchMotionObservation.swift
//  sip Watch App
//
//  Created by 이돈혁 on 8/26/26.
//

import CryptoKit
import Foundation

struct WatchMotionActivitySample: Equatable, Sendable {
    let start: Date
    let end: Date
    let activity: String
    let confidence: Int
    let capturedAt: Date
    let providerIdentifier: String
    let providerVersion: String?
    let deviceIdentifier: String?
    let metadata: [String: String]
}

@MainActor
protocol WatchMotionObservationProviding: AnyObject {
    var state: WatchMotionObservationProviderState { get }

    func start(
        from date: Date,
        handler: @escaping @MainActor (WatchMotionActivitySample) -> Void
    ) throws
    func pause(at date: Date)
    func resume(at date: Date) throws
    func stop(at date: Date)
    func cancel()
}

enum WatchMotionObservationProviderState: Equatable, Sendable {
    case stopped
    case running
    case paused
    case cancelled
}

enum WatchMotionObservationError: Error, Equatable, Sendable {
    case unavailable
    case unauthorized
    case invalidLifecycle
}

@MainActor
final class WatchMotionObservationController {
    static let algorithmVersion = "unvalidated-production-v1"

    private let provider: WatchMotionObservationProviding
    private let sink: @MainActor (WatchNormalizedObservation) -> Void
    private let sourceBundleIdentifier: String
    private var sessionID: UUID?

    var providerState: WatchMotionObservationProviderState { provider.state }

    init(
        provider: WatchMotionObservationProviding,
        sourceBundleIdentifier: String = "com.codling.sip.watchkitapp",
        sink: @escaping @MainActor (WatchNormalizedObservation) -> Void
    ) {
        self.provider = provider
        self.sourceBundleIdentifier = sourceBundleIdentifier
        self.sink = sink
    }

    func start(sessionID: UUID, from date: Date) throws {
        guard self.sessionID == nil else { throw WatchMotionObservationError.invalidLifecycle }
        self.sessionID = sessionID
        do {
            try provider.start(from: date) { [weak self] sample in
                self?.receive(sample)
            }
        } catch {
            self.sessionID = nil
            throw error
        }
    }

    func pause(at date: Date) {
        guard sessionID != nil else { return }
        provider.pause(at: date)
    }

    func resume(at date: Date) throws {
        guard sessionID != nil else { throw WatchMotionObservationError.invalidLifecycle }
        try provider.resume(at: date)
    }

    func stop(at date: Date) {
        guard sessionID != nil else { return }
        provider.stop(at: date)
        sessionID = nil
    }

    func cancel() {
        provider.cancel()
        sessionID = nil
    }

    private func receive(_ sample: WatchMotionActivitySample) {
        guard let sessionID, sample.start < sample.end else { return }
        let id = Self.deterministicID(for: "\(sessionID.uuidString)|\(sample.providerIdentifier)")
        let sequence = Int(sample.start.timeIntervalSince1970 * 1_000)
        sink(
            WatchNormalizedObservation(
                id: id,
                sessionID: sessionID,
                sequence: sequence,
                start: sample.start,
                end: sample.end,
                kind: .motion,
                activity: sample.activity,
                confidence: sample.confidence,
                capturedAt: sample.capturedAt,
                algorithmVersion: Self.algorithmVersion,
                providerIdentifier: sample.providerIdentifier,
                sourceBundleIdentifier: sourceBundleIdentifier,
                sourceVersion: sample.providerVersion,
                deviceIdentifier: sample.deviceIdentifier,
                metadata: sample.metadata
            )
        )
    }

    private static func deterministicID(for providerIdentifier: String) -> UUID {
        var bytes = Array(SHA256.hash(data: Data(providerIdentifier.utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x80
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        let value: uuid_t = (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return UUID(uuid: value)
    }
}
