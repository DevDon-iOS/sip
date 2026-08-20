//
//  FinalPhoneViews.swift
//  sip
//
//  Created by 이돈혁 on 8/20/26.
//

import SwiftUI

struct PermissionIntroductionView: View {
    let onCompletion: () -> Void

    @State private var isRequesting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("sip")
                    .font(NotoSansKR.font(size: 30, weight: .black, relativeTo: .largeTitle))
                    .foregroundStyle(Color("BrandAccent"))
                    .frame(minHeight: 40)
                    .accessibilityLabel("sip")

                Text("낮잠과 기상 후 상태를 기록해요")
                    .font(NotoSansKR.font(size: 24, weight: .bold, relativeTo: .title2))
                    .foregroundStyle(Color("TextPrimary"))
                    .frame(minHeight: 34)
                    .padding(.top, 20)
                    .accessibilityAddTraits(.isHeader)

                Text("필요한 권한은 다음 화면에서 하나씩 요청해요.")
                    .font(NotoSansKR.font(size: 13, weight: .medium, relativeTo: .footnote))
                    .foregroundStyle(Color("TextSecondary"))
                    .frame(minHeight: 20)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 24) {
                    PermissionPurpose(
                        title: "Apple 건강",
                        description: "수면 기록을 읽고 저장해요"
                    )
                    PermissionPurpose(
                        title: "동작 및 피트니스",
                        description: "움직임 변화를 확인해요"
                    )
                    PermissionPurpose(
                        title: "알림",
                        description: "종료 알람과 상태 리마인드를 알려요"
                    )
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color("SurfacePrimary"), in: RoundedRectangle(cornerRadius: 16))
                .padding(.top, 16)

                Text("권한은 나중에 설정에서 바꿀 수 있어요.")
                    .font(NotoSansKR.font(size: 11, weight: .medium, relativeTo: .caption2))
                    .foregroundStyle(Color("TextTertiary"))
                    .frame(minHeight: 16)
                    .padding(.top, 16)

                Button(action: requestPermissions) {
                    Group {
                        if isRequesting {
                            ProgressView()
                                .tint(.white)
                                .accessibilityLabel("권한 요청 중")
                        } else {
                            Text("계속")
                                .font(NotoSansKR.font(size: 16, weight: .bold, relativeTo: .callout))
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(Color("BrandAccent"), in: RoundedRectangle(cornerRadius: 14))
                .disabled(isRequesting)
                .padding(.top, 16)
                .accessibilityHint("Apple 건강, 동작 및 피트니스, 알림 권한을 차례로 요청합니다")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 28)
        }
        .background(Color("BackgroundCanvas").ignoresSafeArea())
        .interactiveDismissDisabled()
    }

    private func requestPermissions() {
        guard !isRequesting else { return }
        isRequesting = true

        Task { @MainActor in
            await PermissionRequestCoordinator.shared.requestAll()
            isRequesting = false
            onCompletion()
        }
    }
}

private struct PermissionPurpose: View {
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(NotoSansKR.font(size: 14, weight: .bold, relativeTo: .body))
                .foregroundStyle(Color("TextPrimary"))
                .frame(minHeight: 22)

            Text(description)
                .font(NotoSansKR.font(size: 12, weight: .medium, relativeTo: .caption1))
                .foregroundStyle(Color("TextSecondary"))
                .frame(minHeight: 18)
        }
        .accessibilityElement(children: .combine)
    }
}

struct RecordsEmptyView: View {
    let onConditionCheckIn: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 6) {
                Text("아직 낮잠 기록이 없어요")
                    .font(NotoSansKR.font(size: 18, weight: .bold, relativeTo: .title3))
                    .foregroundStyle(Color("TextPrimary"))
                    .frame(minHeight: 28)

                Text("지금 상태만 남길 수 있어요.")
                    .font(NotoSansKR.font(size: 13, weight: .medium, relativeTo: .footnote))
                    .foregroundStyle(Color("TextSecondary"))
                    .frame(minHeight: 20)
            }
            .accessibilityElement(children: .combine)

            Button("상태 입력", action: onConditionCheckIn)
                .font(NotoSansKR.font(size: 15, weight: .bold, relativeTo: .body))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Color("BrandAccent"), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityHint("현재 에너지, 집중, 기분을 입력합니다")
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 162)
        .background(Color("SurfacePrimary"), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HelpSection(
                    title: "낮잠 기록",
                    cardTitle: "기록 방식",
                    lines: [
                        "감지된 낮잠만 기록돼요.",
                        "잠든 시간은 직접 추가하거나 바꿀 수 없어요."
                    ]
                )

                HelpSection(
                    title: "알람과 감지",
                    cardTitle: "Apple Watch",
                    lines: [
                        "종료 알람은 지원 범위에서 동작해요.",
                        "기기 상태에 따라 기록이 없을 수 있어요."
                    ]
                )

                HelpSection(
                    title: "데이터",
                    cardTitle: "저장 위치",
                    lines: [
                        "계정 없이 기기에 저장돼요.",
                        "허용하면 Apple 건강에도 자동 저장돼요."
                    ]
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
        .background(Color("BackgroundCanvas").ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("도움말")
                    .font(NotoSansKR.navigationFont(size: 16, weight: .bold))
                    .foregroundStyle(Color("TextPrimary"))
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

private struct HelpSection: View {
    let title: String
    let cardTitle: String
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(NotoSansKR.font(size: 16, weight: .bold, relativeTo: .callout))
                .foregroundStyle(Color("TextPrimary"))
                .frame(minHeight: 24)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 8) {
                Text(cardTitle)
                    .font(NotoSansKR.font(size: 14, weight: .bold, relativeTo: .body))
                    .foregroundStyle(Color("TextPrimary"))
                    .frame(minHeight: 22)

                ForEach(lines, id: \.self) { line in
                    Text(line)
                        .font(NotoSansKR.font(size: 13, weight: .medium, relativeTo: .footnote))
                        .foregroundStyle(Color("TextSecondary"))
                        .frame(minHeight: 20)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color("SurfacePrimary"), in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

#if DEBUG
#Preview("Permission Introduction · iPhone 13 mini") {
    PermissionIntroductionView(onCompletion: {})
        .frame(width: 375, height: 812)
}

#Preview("Permission Introduction · iPhone SE") {
    PermissionIntroductionView(onCompletion: {})
        .frame(width: 375, height: 667)
}

#Preview("Permission Introduction · iPhone 15 Pro") {
    PermissionIntroductionView(onCompletion: {})
        .frame(width: 393, height: 852)
}

#Preview("Records Empty · iPhone 13 mini") {
    RecordsEmptyView(onConditionCheckIn: {})
        .padding(20)
        .frame(width: 375, height: 812, alignment: .top)
        .background(Color("BackgroundCanvas"))
}

#Preview("Help · iPhone 13 mini") {
    DebugNavigationPreview {
        HelpView()
    }
    .frame(width: 375, height: 812)
}


#Preview("Help · iPhone SE") {
    DebugNavigationPreview {
        HelpView()
    }
    .frame(width: 375, height: 667)
}

#Preview("Help · iPhone 15 Pro") {
    DebugNavigationPreview {
        HelpView()
    }
    .frame(width: 393, height: 852)
}
#endif
