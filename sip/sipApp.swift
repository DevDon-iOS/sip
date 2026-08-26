//
//  sipApp.swift
//  sip
//
//  Created by 이돈혁 on 7/8/25.
//

import SwiftUI

@main
struct sipApp: App {
    var body: some Scene {
        WindowGroup {
            rootView
        }
    }

    @ViewBuilder
    private var rootView: some View {
#if DEBUG
        switch ProcessInfo.processInfo.arguments.previewScreen {
        case "condition-detected":
            DebugNavigationPreview {
                ConditionCheckInView(record: .figmaDetected)
            }
        case "no-nap":
            DebugNavigationPreview {
                ConditionCheckInView(record: nil)
            }
        case "record-detail":
            DebugNavigationPreview {
                RecordDetailView(
                    record: .figmaDetected,
                    checkIn: .figmaSaved(for: .figmaDetected)
                )
            }
        default:
            MaintabView()
        }
#else
        MaintabView()
#endif
    }
}

#if DEBUG
private extension Array where Element == String {
    var previewScreen: String? {
        guard let flagIndex = firstIndex(of: "-SIPPreviewScreen") else { return nil }
        let valueIndex = index(after: flagIndex)
        return indices.contains(valueIndex) ? self[valueIndex] : nil
    }
}

private struct DebugNavigationPreview<Content: View>: View {
    @State private var isPresented = true
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            Color("BackgroundCanvas")
                .navigationDestination(isPresented: $isPresented) {
                    content
                }
        }
    }
}
#endif
