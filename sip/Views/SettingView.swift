//
//  SettingView.swift
//  sip
//
//  Created by 이돈혁 on 7/15/25.
//

import CoreMotion
import HealthKit
import SwiftUI
import UIKit
import UserNotifications

struct SettingView: View {
    private let fixedPermissions: PermissionSnapshot?
    private let onExport: () -> Void
    private let onDeleteAllData: () -> Void

    @AppStorage("statusReminderEnabled") private var isReminderEnabled = false
    @State private var permissions = PermissionSnapshot.pending
    @Environment(\.openURL) private var openURL

    init(
        permissions: PermissionSnapshot? = nil,
        onExport: @escaping () -> Void = {},
        onDeleteAllData: @escaping () -> Void = {}
    ) {
        fixedPermissions = permissions
        self.onExport = onExport
        self.onDeleteAllData = onDeleteAllData
        _permissions = State(initialValue: permissions ?? .pending)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("설정")
                        .font(NotoSansKR.font(size: 28, weight: .bold, relativeTo: .largeTitle))
                        .foregroundStyle(Color("TextPrimary"))
                        .frame(minHeight: 38)
                        .accessibilityAddTraits(.isHeader)

                    SettingSection(title: "권한") {
                        PermissionRow(label: "Apple 건강", value: permissions.health) {
                            openSystemSettings()
                        }
                        SettingDivider()
                        PermissionRow(label: "동작 및 피트니스", value: permissions.motion) {
                            openSystemSettings()
                        }
                        SettingDivider()
                        PermissionRow(label: "알림", value: permissions.notifications) {
                            openSystemSettings()
                        }
                    }
                    .padding(.top, 10)

                    SettingSection(title: "일반") {
                        Toggle(isOn: $isReminderEnabled) {
                            SettingRowLabel("상태 리마인드")
                        }
                        .toggleStyle(.switch)
                        .tint(Color("BrandAccent"))
                        .frame(minHeight: 64)
                        .padding(.leading, 16)
                        .padding(.trailing, 12)
                        .accessibilityHint("기상 후 상태 입력 알림을 켜거나 끕니다")

                        SettingDivider()
                        NavigationLink {
                            HelpView()
                        } label: {
                            DisclosureRowLabel(label: "도움말")
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 16)

                    SettingSection(title: "데이터") {
                        DisclosureRow(label: "기록 내보내기", action: onExport)
                        SettingDivider()
                        DisclosureRow(
                            label: "모든 데이터 삭제",
                            isDestructive: true,
                            action: onDeleteAllData
                        )
                    }
                    .padding(.top, 16)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 32)
            }
            .background(Color("BackgroundCanvas").ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .task {
                guard fixedPermissions == nil else { return }
                permissions = await PermissionSnapshot.current()
            }
        }
    }

    private func openSystemSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(settingsURL)
    }
}

private struct SettingSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(NotoSansKR.font(size: 12, weight: .bold, relativeTo: .caption1))
                .foregroundStyle(Color("TextSecondary"))
                .frame(minHeight: 18)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) {
                content
            }
            .background(Color("SurfacePrimary"), in: RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color("BorderSubtle"), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
}

private struct PermissionRow: View {
    let label: String
    let value: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                SettingRowLabel(label)
                Spacer(minLength: 8)
                Text(value)
                    .font(NotoSansKR.font(size: 13, weight: .medium, relativeTo: .footnote))
                    .foregroundStyle(Color("TextSecondary"))
                    .lineLimit(1)
            }
            .frame(minHeight: 64)
            .padding(.leading, 16)
            .padding(.trailing, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(value)
        .accessibilityHint("시스템 설정 열기")
    }
}

private struct DisclosureRow: View {
    let label: String
    var isDestructive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                SettingRowLabel(label, isDestructive: isDestructive)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color("TextTertiary"))
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 64)
            .padding(.leading, 16)
            .padding(.trailing, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct DisclosureRowLabel: View {
    let label: String

    var body: some View {
        HStack(spacing: 12) {
            SettingRowLabel(label)
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color("TextTertiary"))
                .accessibilityHidden(true)
        }
        .frame(minHeight: 64)
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .contentShape(Rectangle())
    }
}

private struct SettingRowLabel: View {
    let label: String
    var isDestructive = false

    init(_ label: String, isDestructive: Bool = false) {
        self.label = label
        self.isDestructive = isDestructive
    }

    var body: some View {
        Text(label)
            .font(NotoSansKR.font(size: 15, weight: .regular, relativeTo: .body))
            .foregroundStyle(isDestructive ? Color("StatusError") : Color("TextPrimary"))
            .frame(minHeight: 24)
            .lineLimit(1)
    }
}

private struct SettingDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color("BorderSubtle"))
            .frame(height: 1)
            .padding(.horizontal, 16)
            .accessibilityHidden(true)
    }
}

struct PermissionSnapshot: Equatable {
    let health: String
    let motion: String
    let notifications: String

    static let pending = PermissionSnapshot(
        health: "",
        motion: "",
        notifications: ""
    )

    static let figma = PermissionSnapshot(
        health: "허용됨",
        motion: "허용됨",
        notifications: "꺼짐"
    )

    static func current() async -> PermissionSnapshot {
        let health = healthStatus()
        let motion = motionStatus()
        let notificationSettings = await UNUserNotificationCenter.current().notificationSettings()

        return PermissionSnapshot(
            health: health,
            motion: motion,
            notifications: notificationStatus(notificationSettings.authorizationStatus)
        )
    }

    private static func healthStatus() -> String {
        guard
            HKHealthStore.isHealthDataAvailable(),
            let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
        else {
            return "사용 불가"
        }

        switch HKHealthStore().authorizationStatus(for: sleepType) {
        case .sharingAuthorized:
            return "허용됨"
        case .sharingDenied:
            return "허용 안 됨"
        case .notDetermined:
            return "요청 필요"
        @unknown default:
            return "확인 필요"
        }
    }

    private static func motionStatus() -> String {
        guard CMMotionActivityManager.isActivityAvailable() else {
            return "사용 불가"
        }

        switch CMMotionActivityManager.authorizationStatus() {
        case .authorized:
            return "허용됨"
        case .denied, .restricted:
            return "허용 안 됨"
        case .notDetermined:
            return "요청 필요"
        @unknown default:
            return "확인 필요"
        }
    }

    private static func notificationStatus(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return "허용됨"
        case .denied, .notDetermined:
            return "꺼짐"
        @unknown default:
            return "확인 필요"
        }
    }
}

#Preview("Settings · Permissions Partial") {
    SettingView(permissions: .figma)
        .preferredColorScheme(.light)
}
