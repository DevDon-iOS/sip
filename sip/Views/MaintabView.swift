//
//  MaintabView.swift
//  Sip
//
//  Created by 이돈혁 on 7/15/25.
//

import SwiftUI

struct MaintabView: View {
    @State private var selectedTab = MainTab.home

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("홈", image: "IconoirHome")
                }
                .tag(MainTab.home)

            AnalysisView()
                .tabItem {
                    Label("기록", image: "IconoirRecords")
                }
                .tag(MainTab.records)

            SettingView()
                .tabItem {
                    Label("설정", image: "IconoirSettings")
                }
                .tag(MainTab.settings)
        }
        .tint(Color("BrandAccent"))
    }
}

private enum MainTab: Hashable {
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
