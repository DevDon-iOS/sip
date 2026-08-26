//
//  PermissionRequestCoordinator.swift
//  sip
//
//  Created by 이돈혁 on 8/20/26.
//

import CoreMotion
import Foundation
import OSLog
import UserNotifications

@MainActor
final class PermissionRequestCoordinator {
    static let shared = PermissionRequestCoordinator()

    private let motionManager = CMMotionActivityManager()
    private let logger = Logger(
        subsystem: "com.codling.sip",
        category: "PermissionRequest"
    )

    func requestAll() async {
        await requestHealth()
        await requestMotion()
        await requestNotifications()
    }

    private func requestHealth() async {
        do {
            try await HealthKitService.shared.requestAuthorization()
        } catch {
            logger.error("Apple 건강 권한 요청을 완료하지 못했습니다: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func requestMotion() async {
        guard CMMotionActivityManager.isActivityAvailable() else { return }
        guard CMMotionActivityManager.authorizationStatus() == .notDetermined else { return }

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                motionManager.queryActivityStarting(
                    from: Date().addingTimeInterval(-1),
                    to: .now,
                    to: .main
                ) { _, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        } catch {
            logger.error("동작 및 피트니스 권한 요청을 완료하지 못했습니다: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func requestNotifications() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }

        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            logger.error("알림 권한 요청을 완료하지 못했습니다: \(error.localizedDescription, privacy: .public)")
        }
    }
}
