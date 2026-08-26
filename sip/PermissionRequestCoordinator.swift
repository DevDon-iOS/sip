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

        await withCheckedContinuation { continuation in
            var hasResumed = false

            let resumeOnce = {
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume()
            }

            motionManager.queryActivityStarting(
                from: Date().addingTimeInterval(-1),
                to: .now,
                to: .main
            ) { [logger] _, error in
                if let error {
                    logger.error("동작 및 피트니스 권한 요청을 완료하지 못했습니다: \(error.localizedDescription, privacy: .public)")
                }
                resumeOnce()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [logger] in
                guard !hasResumed else { return }
                logger.error("동작 및 피트니스 권한 요청 응답이 지연되어 다음 단계로 진행합니다.")
                resumeOnce()
            }
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
