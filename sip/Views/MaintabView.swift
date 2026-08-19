//
//  MaintabView.swift
//  Sip
//
//  Created by 이돈혁 on 7/15/25.
//

import SwiftUI

struct MaintabView: View {
    @State private var selectedTab: MainTab

#if DEBUG
    private let usesFigmaRecords: Bool
    private let usesFigmaPermissions: Bool
#endif

    init(previewTab: String? = nil) {
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let launchPreviewTab = arguments.firstIndex(of: "-SIPPreviewTab")
            .flatMap { index in arguments.indices.contains(index + 1) ? arguments[index + 1] : nil }
        let resolvedPreviewTab = previewTab ?? launchPreviewTab
        let initialTab = MainTab(rawValue: resolvedPreviewTab ?? "") ?? .home
        _selectedTab = State(initialValue: initialTab)
        usesFigmaRecords = resolvedPreviewTab == MainTab.records.rawValue
        usesFigmaPermissions = resolvedPreviewTab == MainTab.settings.rawValue
#else
        _ = previewTab
        _selectedTab = State(initialValue: .home)
#endif
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("홈", image: "IconoirHome")
                }
                .tag(MainTab.home)

            recordsView
                .tabItem {
                    Label("기록", image: "IconoirRecords")
                }
                .tag(MainTab.records)

            settingsView
                .tabItem {
                    Label("설정", image: "IconoirSettings")
                }
                .tag(MainTab.settings)
        }
        .tint(Color("BrandAccent"))
    }

    @ViewBuilder
    private var recordsView: some View {
#if DEBUG
        AnalysisView(records: usesFigmaRecords ? SleepRecord.figmaRecords : nil)
#else
        AnalysisView()
#endif
    }

    @ViewBuilder
    private var settingsView: some View {
#if DEBUG
        SettingView(permissions: usesFigmaPermissions ? .figma : nil)
#else
        SettingView()
#endif
    }
}

private enum MainTab: String, Hashable {
    case home
    case records
    case settings
}

#Preview("iPhone 13 mini · 375×812") {
    MaintabView()
        .frame(width: 375, height: 812)
        .preferredColorScheme(.light)
}

#Preview("iPhone SE · 375×667") {
    MaintabView()
        .frame(width: 375, height: 667)
        .preferredColorScheme(.light)
}

#Preview("iPhone 15 Pro · 393×852") {
    MaintabView()
        .frame(width: 393, height: 852)
        .preferredColorScheme(.light)
}

#Preview("Records · iPhone 13 mini") {
    MaintabView(previewTab: "records")
        .frame(width: 375, height: 812)
        .preferredColorScheme(.light)
}

#Preview("Records · iPhone SE") {
    MaintabView(previewTab: "records")
        .frame(width: 375, height: 667)
        .preferredColorScheme(.light)
}

#Preview("Records · iPhone 15 Pro") {
    MaintabView(previewTab: "records")
        .frame(width: 393, height: 852)
        .preferredColorScheme(.light)
}

#Preview("Settings · iPhone 13 mini") {
    MaintabView(previewTab: "settings")
        .frame(width: 375, height: 812)
        .preferredColorScheme(.light)
}

#Preview("Settings · iPhone SE") {
    MaintabView(previewTab: "settings")
        .frame(width: 375, height: 667)
        .preferredColorScheme(.light)
}

#Preview("Settings · iPhone 15 Pro") {
    MaintabView(previewTab: "settings")
        .frame(width: 393, height: 852)
        .preferredColorScheme(.light)
}
