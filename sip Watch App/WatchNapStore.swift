//
//  WatchNapStore.swift
//  sip Watch App
//
//  Created by 이돈혁 on 8/20/26.
//

import Foundation
import OSLog
@preconcurrency import WatchConnectivity

@MainActor
final class WatchNapStore: NSObject, ObservableObject {
    @Published private(set) var window: WatchNapWindowSnapshot?
    @Published private(set) var activeSession: WatchNapSession?

    private enum StorageKey {
        static let window = "sip.watch.window.v1"
        static let activeSession = "sip.watch.activeSession.v1"
        static let outbox = "sip.watch.outbox.v1"
        static let endedSessionIDs = "sip.watch.endedSessionIDs.v1"
    }

    private enum MessageKey {
        static let schemaVersion = "schemaVersion"
        static let hasWindow = "hasWindow"
        static let windowID = "windowID"
        static let endMinutes = "endMinutes"
        static let alarmMinutes = "alarmMinutes"
        static let isAlarmEnabled = "isAlarmEnabled"
        static let activeSessionData = "activeSessionData"
        static let eventID = "eventID"
        static let eventData = "eventData"
        static let command = "command"
        static let sessionID = "sessionID"
    }

    private let logger = Logger(
        subsystem: "com.codling.sip.watchkitapp",
        category: "WatchNapStore"
    )
    private let defaults: UserDefaults
    private let connectivitySession: WCSession?
    private var outbox: [WatchSyncEvent]
    private var lastCommittedAlarmSnapshot: WatchNapWindowSnapshot?

    override init() {
        let defaults = UserDefaults.standard
        let loadedWindow = Self.decode(
            WatchNapWindowSnapshot.self,
            key: StorageKey.window,
            defaults: defaults
        )
        self.defaults = defaults
        window = loadedWindow
        activeSession = Self.decode(WatchNapSession.self, key: StorageKey.activeSession, defaults: defaults)
        outbox = Self.decode([WatchSyncEvent].self, key: StorageKey.outbox, defaults: defaults) ?? []
        lastCommittedAlarmSnapshot = loadedWindow
        connectivitySession = WCSession.isSupported() ? .default : nil
        super.init()

        connectivitySession?.delegate = self
        connectivitySession?.activate()
    }

#if DEBUG
    init(previewState: WatchPreviewState) {
        let defaults = UserDefaults(suiteName: "sip.watch.preview.\(UUID().uuidString)") ?? .standard
        let previewWindow = previewState.window
        self.defaults = defaults
        window = previewWindow
        activeSession = previewState.session
        outbox = []
        lastCommittedAlarmSnapshot = previewWindow
        connectivitySession = nil
        super.init()
    }
#endif

    var alarmMinutes: Int {
        window?.alarmMinutes ?? 0
    }

    var isAlarmEnabled: Bool {
        window?.isAlarmEnabled ?? false
    }

    var canStartNap: Bool {
        window != nil
    }

    func startNap(now: Date = .now) {
        guard let window else { return }
        let session = WatchNapSession(
            id: UUID(),
            windowID: window.id,
            startedAt: now,
            endAlarmAt: window.nextEndAlarm(after: now)
        )
        activeSession = session
        persist(session, key: StorageKey.activeSession)
        enqueue(.session(session, kind: .sessionStarted))
    }

    func endNap() {
        guard let activeSession else { return }
        enqueue(.session(activeSession, kind: .sessionEnded))
        rememberEndedSession(activeSession.id)
        self.activeSession = nil
        defaults.removeObject(forKey: StorageKey.activeSession)
    }

    func setAlarmMinutes(_ minutes: Int) {
        guard var window else { return }
        window.alarmMinutes = min(max(minutes, 0), 1439)
        self.window = window
        persist(window, key: StorageKey.window)
    }

    func setAlarmEnabled(_ isEnabled: Bool) {
        guard var window else { return }
        window.isAlarmEnabled = isEnabled
        self.window = window
        persist(window, key: StorageKey.window)
        enqueueAlarmUpdateIfNeeded(window)
    }

    func commitAlarmChange() {
        guard let window else { return }
        enqueueAlarmUpdateIfNeeded(window)
    }

    private func enqueueAlarmUpdateIfNeeded(_ window: WatchNapWindowSnapshot) {
        guard window != lastCommittedAlarmSnapshot else { return }
        lastCommittedAlarmSnapshot = window
        enqueue(.alarm(window: window))
    }

    private func enqueue(_ event: WatchSyncEvent) {
        outbox.append(event)
        persist(outbox, key: StorageKey.outbox)
        flushOutbox()
    }

    private func flushOutbox() {
        guard let connectivitySession,
              connectivitySession.activationState == .activated else { return }

        let outstandingIDs = Set(
            connectivitySession.outstandingUserInfoTransfers.compactMap {
                $0.userInfo[MessageKey.eventID] as? String
            }
        )

        for event in outbox where !outstandingIDs.contains(event.id.uuidString) {
            do {
                let eventData = try JSONEncoder().encode(event)
                connectivitySession.transferUserInfo([
                    MessageKey.schemaVersion: 1,
                    MessageKey.eventID: event.id.uuidString,
                    MessageKey.eventData: eventData
                ])
            } catch {
                logger.error("Watch event encoding failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func apply(applicationContext: [String: Any]) {
        guard (applicationContext[MessageKey.schemaVersion] as? Int) == 1 else { return }

        if applicationContext[MessageKey.hasWindow] as? Bool == true,
           let windowIDString = applicationContext[MessageKey.windowID] as? String,
           let windowID = UUID(uuidString: windowIDString),
           let endMinutes = applicationContext[MessageKey.endMinutes] as? Int,
           let alarmMinutes = applicationContext[MessageKey.alarmMinutes] as? Int,
           let isAlarmEnabled = applicationContext[MessageKey.isAlarmEnabled] as? Bool {
            let snapshot = WatchNapWindowSnapshot(
                id: windowID,
                endMinutes: endMinutes,
                alarmMinutes: alarmMinutes,
                isAlarmEnabled: isAlarmEnabled
            )
            window = snapshot
            lastCommittedAlarmSnapshot = snapshot
            persist(snapshot, key: StorageKey.window)
        } else if applicationContext[MessageKey.hasWindow] as? Bool == false {
            window = nil
            defaults.removeObject(forKey: StorageKey.window)
        }

        if let sessionData = applicationContext[MessageKey.activeSessionData] as? Data {
            do {
                let session = try JSONDecoder().decode(WatchNapSession.self, from: sessionData)
                guard !endedSessionIDs().contains(session.id) else { return }
                activeSession = session
                persist(session, key: StorageKey.activeSession)
            } catch {
                logger.error("Active session decoding failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func apply(userInfo: [String: Any]) {
        guard userInfo[MessageKey.command] as? String == "sessionEnded",
              let sessionIDString = userInfo[MessageKey.sessionID] as? String,
              let sessionID = UUID(uuidString: sessionIDString),
              activeSession?.id == sessionID else { return }
        rememberEndedSession(sessionID)
        activeSession = nil
        defaults.removeObject(forKey: StorageKey.activeSession)
    }

    private func markDelivered(eventID: UUID) {
        outbox.removeAll { $0.id == eventID }
        persist(outbox, key: StorageKey.outbox)
    }

    private func endedSessionIDs() -> [UUID] {
        Self.decode([UUID].self, key: StorageKey.endedSessionIDs, defaults: defaults) ?? []
    }

    private func rememberEndedSession(_ sessionID: UUID) {
        var ids = endedSessionIDs()
        guard !ids.contains(sessionID) else { return }
        ids.append(sessionID)
        persist(Array(ids.suffix(128)), key: StorageKey.endedSessionIDs)
    }

    private func persist<T: Encodable>(_ value: T, key: String) {
        do {
            defaults.set(try JSONEncoder().encode(value), forKey: key)
        } catch {
            logger.error("Watch local persistence failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func decode<T: Decodable>(
        _ type: T.Type,
        key: String,
        defaults: UserDefaults
    ) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            Logger(
                subsystem: "com.codling.sip.watchkitapp",
                category: "WatchNapStore"
            )
            .error("Watch local decoding failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}

extension WatchNapStore: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard error == nil, activationState == .activated else { return }
        Task { @MainActor in
            self.apply(applicationContext: session.receivedApplicationContext)
            self.flushOutbox()
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor in
            self.apply(applicationContext: applicationContext)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any] = [:]
    ) {
        Task { @MainActor in
            self.apply(userInfo: userInfo)
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.flushOutbox()
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didFinish userInfoTransfer: WCSessionUserInfoTransfer,
        error: Error?
    ) {
        guard error == nil,
              let eventIDString = userInfoTransfer.userInfo[MessageKey.eventID] as? String,
              let eventID = UUID(uuidString: eventIDString) else { return }
        Task { @MainActor in
            self.markDelivered(eventID: eventID)
        }
    }
}

#if DEBUG
enum WatchPreviewState: String {
    case preNap = "pre-nap"
    case alarm
    case active
    case end

    private static let referenceNow = Calendar.current.date(
        bySettingHour: 13,
        minute: 40,
        second: 18,
        of: .now
    ) ?? .now

    var window: WatchNapWindowSnapshot? {
        WatchNapWindowSnapshot(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000014") ?? UUID(),
            endMinutes: 14 * 60,
            alarmMinutes: 14 * 60,
            isAlarmEnabled: true
        )
    }

    var session: WatchNapSession? {
        guard (self == .active || self == .end), let window else { return nil }
        return WatchNapSession(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000015") ?? UUID(),
            windowID: window.id,
            startedAt: Self.referenceNow.addingTimeInterval(-(32 * 60 + 18)),
            endAlarmAt: Self.referenceNow.addingTimeInterval(20 * 60)
        )
    }

    var initialPage: Int {
        self == .alarm || self == .end ? 1 : 0
    }

    var fixedNow: Date? {
        self == .active || self == .end ? Self.referenceNow : nil
    }
}
#endif
