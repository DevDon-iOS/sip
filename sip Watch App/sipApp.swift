//
//  sipApp.swift
//  sip Watch App
//
//  Created by 이돈혁 on 7/8/25.
//

import SwiftUI

@main
struct sip_Watch_AppApp: App {
    var body: some Scene {
        WindowGroup {
            rootView
        }
    }

    @ViewBuilder
    private var rootView: some View {
#if DEBUG
        if let previewState = ProcessInfo.processInfo.arguments.watchPreviewState {
            if ProcessInfo.processInfo.arguments.contains("-SIPWatchAccessibilityText") {
                ContentView(previewState: previewState)
                    .environment(\.dynamicTypeSize, .accessibility5)
            } else {
                ContentView(previewState: previewState)
            }
        } else {
            ContentView()
        }
#else
        ContentView()
#endif
    }
}

#if DEBUG
private extension Array where Element == String {
    var watchPreviewState: WatchPreviewState? {
        guard let flagIndex = firstIndex(of: "-SIPWatchPreviewState") else { return nil }
        let valueIndex = index(after: flagIndex)
        guard indices.contains(valueIndex) else { return nil }
        return WatchPreviewState(rawValue: self[valueIndex])
    }
}
#endif
