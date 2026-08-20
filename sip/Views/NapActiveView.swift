//
//  NapActiveView.swift
//  sip
//
//  Created by 이돈혁 on 8/20/26.
//

import SwiftUI

struct NapActiveView: View {
    @State private var session: ActiveNapSession
    @State private var isAlarmEditorPresented = false
    @State private var isEndConfirmationPresented = false

    private let onUpdate: (ActiveNapSession) -> Void
    private let onEnd: (ActiveNapSession) -> Void
    private let fixedNow: Date?

    @Environment(\.dismiss) private var dismiss

    init(
        session: ActiveNapSession,
        fixedNow: Date? = nil,
        onUpdate: @escaping (ActiveNapSession) -> Void = { _ in },
        onEnd: @escaping (ActiveNapSession) -> Void = { _ in }
    ) {
        _session = State(initialValue: session)
        self.fixedNow = fixedNow
        self.onUpdate = onUpdate
        self.onEnd = onEnd
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let fixedNow {
                    ActiveNapCard(session: session, now: fixedNow)
                } else {
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        ActiveNapCard(session: session, now: context.date)
                    }
                }

                Text("빠른 변경")
                    .font(NotoSansKR.font(size: 16, weight: .bold, relativeTo: .callout))
                    .foregroundStyle(Color("TextPrimary"))
                    .frame(minHeight: 24)
                    .accessibilityAddTraits(.isHeader)

                HStack(spacing: 12) {
                    QuickActionButton(title: "15분 연장", action: extendAlarm)
                    QuickActionButton(title: "알람 변경") {
                        isAlarmEditorPresented = true
                    }
                }

                Button(role: .destructive) {
                    isEndConfirmationPresented = true
                } label: {
                    Text("낮잠 종료")
                        .font(NotoSansKR.font(size: 14, weight: .bold, relativeTo: .body))
                        .frame(maxWidth: .infinity, minHeight: 54)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color("StatusError"))
                .background(Color("SurfacePrimary"), in: RoundedRectangle(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color("BorderSubtle"), lineWidth: 1)
                }
                .accessibilityHint("현재 진행 중인 낮잠을 종료합니다")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 32)
            .padding(.bottom, 24)
        }
        .background(Color("BackgroundCanvas").ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("낮잠 중")
                    .font(NotoSansKR.font(size: 16, weight: .bold, relativeTo: .headline))
                    .foregroundStyle(Color("TextPrimary"))
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(isPresented: $isAlarmEditorPresented) {
            AlarmTimeEditor(alarmAt: session.endAlarmAt) { alarmAt in
                session.endAlarmAt = alarmAt
                persistUpdate()
            }
        }
        .confirmationDialog(
            "낮잠을 종료할까요?",
            isPresented: $isEndConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("낮잠 종료", role: .destructive) {
                onEnd(session)
                dismiss()
            }
            Button("취소", role: .cancel) {}
        }
    }

    private func extendAlarm() {
        session.extendAlarm(by: 15)
        persistUpdate()
    }

    private func persistUpdate() {
        onUpdate(session)
    }
}

private struct ActiveNapCard: View {
    let session: ActiveNapSession
    let now: Date

    var body: some View {
        VStack(spacing: 8) {
            Text("진행 시간")
                .font(NotoSansKR.font(size: 12, weight: .medium, relativeTo: .caption1))
                .opacity(0.78)

            Text("\(session.elapsedMinutes(at: now))분")
                .font(NotoSansKR.font(size: 44, weight: .bold, relativeTo: .largeTitle))
                .frame(minHeight: 56)
                .accessibilityLabel("진행 시간")
                .accessibilityValue("\(session.elapsedMinutes(at: now))분")

            Text("\(Self.timeFormatter.string(from: session.startedAt)) 시작")
                .font(NotoSansKR.font(size: 13, weight: .regular, relativeTo: .footnote))
                .opacity(0.78)

            Spacer(minLength: 12)

            Text("종료 알람 \(Self.timeFormatter.string(from: session.endAlarmAt))")
                .font(NotoSansKR.font(size: 13, weight: .medium, relativeTo: .footnote))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
        }
        .foregroundStyle(Color("SurfacePrimary"))
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .top)
        .background(Color("BrandAccent"), in: RoundedRectangle(cornerRadius: 24))
        .accessibilityElement(children: .contain)
    }

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

private struct QuickActionButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(NotoSansKR.font(size: 14, weight: .bold, relativeTo: .body))
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color("BrandAccent"))
        .background(Color("SurfacePrimary"), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct AlarmTimeEditor: View {
    @State private var alarmAt: Date
    let onSave: (Date) -> Void

    @Environment(\.dismiss) private var dismiss

    init(alarmAt: Date, onSave: @escaping (Date) -> Void) {
        _alarmAt = State(initialValue: alarmAt)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("종료 알람", selection: $alarmAt, displayedComponents: .hourAndMinute)
                    .font(NotoSansKR.font(size: 15, weight: .medium, relativeTo: .body))
                    .environment(\.locale, Locale(identifier: "en_GB"))
            }
            .navigationTitle("알람 변경")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        onSave(alarmAt)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .tint(Color("BrandAccent"))
    }
}

#if DEBUG
#Preview("Nap Active · iPhone 13 mini") {
    NavigationStack {
        NapActiveView(
            session: .figmaPreview,
            fixedNow: ActiveNapSession.figmaPreviewNow
        )
    }
    .frame(width: 375, height: 812)
    .preferredColorScheme(.light)
}

#Preview("Nap Active · iPhone SE") {
    NavigationStack {
        NapActiveView(
            session: .figmaPreview,
            fixedNow: ActiveNapSession.figmaPreviewNow
        )
    }
    .frame(width: 375, height: 667)
    .preferredColorScheme(.light)
}

#Preview("Nap Active · iPhone 15 Pro") {
    NavigationStack {
        NapActiveView(
            session: .figmaPreview,
            fixedNow: ActiveNapSession.figmaPreviewNow
        )
    }
    .frame(width: 393, height: 852)
    .preferredColorScheme(.light)
}
#endif
