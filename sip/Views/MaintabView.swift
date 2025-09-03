//
//  MaintabView.swift
//  Sip
//
//  Created by 이돈혁 on 7/15/25.
//

import SwiftUI

struct MaintabView: View {
    @State private var selectedTab = 1

    var body: some View {
        TabView(selection: $selectedTab) {
            AnalysisView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("분석")
                }
                .tag(0)
            
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("홈")
                }
                .tag(1)
            
            SettingView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("설정")
                }
                .tag(2)
        }
    }
}

#Preview {
    MaintabView()
}
