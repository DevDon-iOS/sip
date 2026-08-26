//
//  ContentView.swift
//  sip Watch App
//
//  Created by 이돈혁 on 7/8/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var store: WatchNapStore
    @State private var selectedPage: Int
    private let fixedNow: Date?

    init() {
        _store = StateObject(wrappedValue: WatchNapStore())
        _selectedPage = State(initialValue: 0)
        fixedNow = nil
    }

#if DEBUG
    init(previewState: WatchPreviewState) {
        _store = StateObject(wrappedValue: WatchNapStore(previewState: previewState))
        _selectedPage = State(initialValue: previewState.initialPage)
        fixedNow = previewState.fixedNow
    }
#endif

    var body: some View {
        NavigationStack {
            Group {
                if let session = store.activeSession {
                    ActiveNapPages(
                        session: session,
                        selectedPage: $selectedPage,
                        fixedNow: fixedNow,
                        onEnd: store.endNap
                    )
                } else {
                    PreNapPages(
                        store: store,
                        selectedPage: $selectedPage
                    )
                }
            }
            .background(Color("BackgroundCanvas").ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(Color("BrandAccent"))
        .preferredColorScheme(.dark)
        .onChange(of: store.activeSession) { _, _ in
            selectedPage = 0
        }
    }
}

private struct PreNapPages: View {
    @ObservedObject var store: WatchNapStore
    @Binding var selectedPage: Int

    var body: some View {
        TabView(selection: $selectedPage) {
            PreNapStartPage(
                isEnabled: store.canStartNap,
                onStart: { store.startNap() }
            )
            .tag(0)

            AlarmEditorPage(store: store)
                .tag(1)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .padding(.bottom, 14)
        .accessibilityValue(selectedPage == 0 ? "1/2 페이지" : "2/2 페이지")
    }
}

private struct PreNapStartPage: View {
    let isEnabled: Bool
    let onStart: () -> Void

    var body: some View {
        Button(action: onStart) {
            Text("Zzz")
                .font(WatchNotoSansKR.font(size: 28, weight: .bold, relativeTo: .title2))
                .foregroundStyle(Color("TextPrimary"))
                .frame(width: 88, height: 88)
                .background(Color("BrandAccent"), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel("측정 시작")
        .accessibilityValue(isEnabled ? "시작 가능" : "설정된 낮잠 시간이 없음")
        .accessibilityHint("두 번 탭하여 낮잠을 시작합니다")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 14)
    }
}

private struct AlarmEditorPage: View {
    @ObservedObject var store: WatchNapStore
    @State private var alarmMinutes: Double
    @FocusState private var isTimeFocused: Bool

    init(store: WatchNapStore) {
        self.store = store
        _alarmMinutes = State(initialValue: Double(store.alarmMinutes))
    }

    var body: some View {
        VStack(spacing: 6) {
            Text("알람")
                .font(WatchNotoSansKR.font(size: 13, weight: .bold, relativeTo: .footnote))
                .foregroundStyle(Color("TextPrimary"))
                .lineLimit(1)

            Button {
                isTimeFocused = true
            } label: {
                Text(timeLabel)
                    .font(WatchNotoSansKR.font(size: 28, weight: .bold, relativeTo: .title2))
                    .foregroundStyle(Color("TextPrimary"))
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Color("SurfacePrimary"), in: RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color("BrandAccent"), lineWidth: 1.5)
                    }
            }
            .buttonStyle(.plain)
            .focusable()
            .focused($isTimeFocused)
            .digitalCrownRotation(
                $alarmMinutes,
                from: 0,
                through: 1435,
                by: 5,
                sensitivity: .medium,
                isContinuous: true,
                isHapticFeedbackEnabled: true
            )
            .accessibilityLabel("알람 시간")
            .accessibilityValue(accessibilityTimeLabel)
            .accessibilityHint("Digital Crown을 돌려 시간을 변경합니다")

            HStack(spacing: 8) {
                Text("켜기")
                    .font(WatchNotoSansKR.font(size: 12, weight: .medium, relativeTo: .caption))
                    .foregroundStyle(Color("TextPrimary"))

                Spacer(minLength: 4)

                Toggle(
                    "알람",
                    isOn: Binding(
                        get: { store.isAlarmEnabled },
                        set: store.setAlarmEnabled
                    )
                )
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(Color("BrandAccent"))
            }
            .padding(.leading, 8)
            .padding(.trailing, 2)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Color("SurfacePrimary"), in: RoundedRectangle(cornerRadius: 16))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 18)
        .onChange(of: alarmMinutes) { _, newValue in
            store.setAlarmMinutes(Int(newValue.rounded()))
        }
        .onChange(of: isTimeFocused) { wasFocused, isFocused in
            if wasFocused && !isFocused {
                store.commitAlarmChange()
            }
        }
        .onDisappear {
            store.commitAlarmChange()
        }
    }

    private var timeLabel: String {
        let minutes = Int(alarmMinutes.rounded())
        return String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    private var accessibilityTimeLabel: String {
        let minutes = Int(alarmMinutes.rounded())
        let hour = minutes / 60
        let minute = minutes % 60
        return minute == 0 ? "\(hour)시" : "\(hour)시 \(minute)분"
    }
}

private struct ActiveNapPages: View {
    let session: WatchNapSession
    @Binding var selectedPage: Int
    let fixedNow: Date?
    let onEnd: () -> Void

    var body: some View {
        TabView(selection: $selectedPage) {
            if let fixedNow {
                ActiveTimerPage(session: session, now: fixedNow)
                    .tag(0)
            } else {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    ActiveTimerPage(session: session, now: context.date)
                }
                .tag(0)
            }

            EndConfirmationPage(onEnd: onEnd)
                .tag(1)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .padding(.bottom, 14)
        .accessibilityValue(selectedPage == 0 ? "1/2 페이지" : "2/2 페이지")
    }
}

private struct ActiveTimerPage: View {
    let session: WatchNapSession
    let now: Date

    var body: some View {
        GeometryReader { proxy in
            let ringSize = min(proxy.size.width * 0.716, proxy.size.height - 20)
            let lineWidth = max(6, ringSize * 8 / 116)

            ZStack {
                Circle()
                    .stroke(Color("PageInactive"), lineWidth: lineWidth)

                Circle()
                    .trim(from: 0, to: session.progress(at: now))
                    .stroke(
                        Color("BrandAccent"),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("낮잠 중")
                        .font(WatchNotoSansKR.font(size: 12, weight: .bold, relativeTo: .caption))
                        .foregroundStyle(Color("BrandAccent"))
                        .lineLimit(1)

                    Text(session.elapsedLabel(at: now))
                        .font(WatchNotoSansKR.font(size: 30, weight: .bold, relativeTo: .title))
                        .foregroundStyle(Color("TextPrimary"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }
            .frame(width: ringSize, height: ringSize)
            .position(x: proxy.size.width / 2, y: ringSize / 2)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("낮잠 중")
            .accessibilityValue("진행 시간 \(session.elapsedLabel(at: now))")
        }
    }
}

private struct EndConfirmationPage: View {
    let onEnd: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text("낮잠을 끝낼까요?")
                .font(WatchNotoSansKR.font(size: 17, weight: .bold, relativeTo: .headline))
                .foregroundStyle(Color("TextPrimary"))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .accessibilityAddTraits(.isHeader)

            Spacer()
                .frame(height: 18)

            Button("종료", action: onEnd)
                .font(WatchNotoSansKR.font(size: 14, weight: .bold, relativeTo: .body))
                .buttonStyle(.borderedProminent)
                .tint(Color("BrandAccent"))
                .foregroundStyle(Color("SurfacePrimary"))
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityLabel("낮잠 종료")
                .accessibilityHint("현재 낮잠을 종료합니다")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 12)
        .padding(.top, 10)
    }
}

#if DEBUG
#Preview("Pre-Nap · 40mm · 162×197") {
    ContentView(previewState: .preNap)
        .frame(width: 162, height: 197)
}

#Preview("Alarm · 41mm · 176×215") {
    ContentView(previewState: .alarm)
        .frame(width: 176, height: 215)
}

#Preview("Active · 45mm · 198×242") {
    ContentView(previewState: .active)
        .frame(width: 198, height: 242)
}

#Preview("End · 40mm · 162×197") {
    ContentView(previewState: .end)
        .frame(width: 162, height: 197)
}

#Preview("Alarm · 40mm · Accessibility 5") {
    ContentView(previewState: .alarm)
        .environment(\.dynamicTypeSize, .accessibility5)
        .frame(width: 162, height: 197)
}
#endif
