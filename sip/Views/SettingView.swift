//
//  SettingView.swift
//  sip
//
//  Created by 이돈혁 on 7/15/25.
//

import SwiftUI

struct SettingView: View {
    @State private var selectedColorIndex = 0
    var body: some View {
        NavigationStack {
            Text("SettingView")
                .navigationTitle("설정")
        }
    }
}

#Preview {
    SettingView()
}
