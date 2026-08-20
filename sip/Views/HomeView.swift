//
//  HomeView.swift
//  sip
//
//  Created by 이돈혁 on 7/15/25.
//

import SwiftUI

struct HomeView: View {
    @State private var windows: [NapWindow]
    @State private var activeSession: ActiveNapSession?
    @State private var route: HomeRoute?
    @ScaledMetric(relativeTo: .callout) private var sectionLineHeight = 24.0

    init(windows: [NapWindow]? = nil) {
        let storedActiveSession = ActiveNapSessionStorage.load()
        _windows = State(
            initialValue: windows ?? NapWindowStorage.load() ?? NapWindow.figmaHomeFixtures
        )
        _activeSession = State(initialValue: storedActiveSession)
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-SIPPreviewSchedule") {
            _route = State(initialValue: .schedule(.defaultDraft))
        } else if arguments.contains("-SIPPreviewActiveNap") {
            _route = State(
                initialValue: .active(
                    .figmaPreview,
                    fixedNow: ActiveNapSession.figmaPreviewNow
                )
            )
        } else {
            _route = State(
                initialValue: storedActiveSession.map { .active($0, fixedNow: nil) }
            )
        }
#else
        _route = State(
            initialValue: storedActiveSession.map { .active($0, fixedNow: nil) }
        )
#endif
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let upcomingWindow {
                        NapWindowButton(
                            window: upcomingWindow,
                            presentation: .upcoming,
                            onEdit: edit,
                            onSetEnabled: setEnabled
                        )
                    }

                    Text("낮잠 가능 시간")
                        .font(NotoSansKR.font(size: 16, weight: .bold, relativeTo: .callout))
                        .foregroundStyle(Color("TextPrimary"))
                        .frame(minHeight: sectionLineHeight)
                        .padding(.top, 24)
                        .padding(.bottom, 12)

                    LazyVStack(spacing: 8) {
                        ForEach(remainingWindows) { window in
                            NapWindowButton(
                                window: window,
                                presentation: window.isEnabled ? .enabled : .disabled,
                                onEdit: edit,
                                onSetEnabled: setEnabled
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 32)
                .containerRelativeFrame(.horizontal)
            }
            .background(Color("BackgroundCanvas").ignoresSafeArea())
            .toolbar {
                if #available(iOS 26.0, *) {
                    ToolbarItem(placement: .topBarLeading) {
                        SipWordmark()
                            .fixedSize()
                    }
                    .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .topBarLeading) {
                        SipWordmark()
                            .fixedSize()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: addWindow) {
                        Image("IconoirPlus")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                    }
                    .tint(Color("TextPrimary"))
                    .accessibilityLabel("낮잠 가능 시간 추가")
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(item: $route) { route in
                switch route {
                case .schedule(let window):
                    ScheduleEditView(window: window, onSave: save)
                case .active(let session, let fixedNow):
                    NapActiveView(
                        session: session,
                        fixedNow: fixedNow,
                        onUpdate: updateActiveSession,
                        onEnd: endActiveSession
                    )
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .napWindowsDidChangeFromWatch)) { _ in
                if let storedWindows = NapWindowStorage.load() {
                    windows = storedWindows
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .activeNapSessionDidChangeFromWatch)) { _ in
                activeSession = ActiveNapSessionStorage.load()
                if let activeSession {
                    route = .active(activeSession, fixedNow: nil)
                } else if case .active = route {
                    route = nil
                }
            }
        }
    }

    private var upcomingWindow: NapWindow? {
        windows.first(where: \.isEnabled)
    }

    private var remainingWindows: [NapWindow] {
        guard let upcomingWindow else { return windows }
        return windows.filter { $0.id != upcomingWindow.id }
    }

    private func addWindow() {
        route = .schedule(.defaultDraft)
    }

    private func edit(_ window: NapWindow) {
        route = .schedule(window)
    }

    private func save(_ window: NapWindow) {
        if let index = windows.firstIndex(where: { $0.id == window.id }) {
            windows[index] = window
        } else {
            windows.append(window)
        }
        NapWindowStorage.save(windows)
        PhoneConnectivityCoordinator.shared.publish(windows: windows, activeSession: activeSession)
    }

    private func setEnabled(_ window: NapWindow, _ isEnabled: Bool) {
        guard let index = windows.firstIndex(where: { $0.id == window.id }) else { return }
        windows[index].isEnabled = isEnabled
        NapWindowStorage.save(windows)
        PhoneConnectivityCoordinator.shared.publish(windows: windows, activeSession: activeSession)
    }

    private func updateActiveSession(_ session: ActiveNapSession) {
        activeSession = session
        ActiveNapSessionStorage.save(session)
        PhoneConnectivityCoordinator.shared.publish(windows: windows, activeSession: session)
    }

    private func endActiveSession(_ session: ActiveNapSession) {
        guard activeSession?.id == session.id || activeSession == nil else { return }
        activeSession = nil
        ActiveNapSessionStorage.remove()
        PhoneConnectivityCoordinator.shared.notifySessionEnded(session.id)
        PhoneConnectivityCoordinator.shared.publish(windows: windows, activeSession: nil)
    }
}

private enum HomeRoute: Identifiable, Hashable {
    case schedule(NapWindow)
    case active(ActiveNapSession, fixedNow: Date?)

    var id: String {
        switch self {
        case .schedule(let window): "schedule-\(window.id.uuidString)"
        case .active(let session, _): "active-\(session.id.uuidString)"
        }
    }
}

private struct SipWordmark: View {
    var body: some View {
        Text("sip")
            .font(NotoSansKR.font(size: 30, weight: .black, relativeTo: .largeTitle))
            .tracking(-1.4)
            .foregroundStyle(Color("BrandAccent"))
            .accessibilityAddTraits(.isHeader)
    }
}

private struct NapWindowButton: View {
    let window: NapWindow
    let presentation: NapWindowPresentation
    let onEdit: (NapWindow) -> Void
    let onSetEnabled: (NapWindow, Bool) -> Void

    var body: some View {
        Button {
            onEdit(window)
        } label: {
            NapWindowCard(window: window, presentation: presentation)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onSetEnabled(window, !window.isEnabled)
            } label: {
                Label(
                    window.isEnabled ? "시간 비활성화" : "시간 활성화",
                    systemImage: window.isEnabled ? "pause.circle" : "play.circle"
                )
            }
        }
        .accessibilityAction(named: window.isEnabled ? "시간 비활성화" : "시간 활성화") {
            onSetEnabled(window, !window.isEnabled)
        }
        .accessibilityHint("두 번 탭하여 편집하고 길게 눌러 활성 상태를 변경합니다")
    }
}

private struct NapWindowCard: View {
    let window: NapWindow
    let presentation: NapWindowPresentation

    @ScaledMetric(relativeTo: .footnote) private var eyebrowLineHeight = 20.0
    @ScaledMetric(relativeTo: .title2) private var timeLineHeight = 34.0
    @ScaledMetric(relativeTo: .footnote) private var relativeTimeLineHeight = 20.0
    @ScaledMetric(relativeTo: .caption) private var alarmLineHeight = 18.0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(presentation.eyebrow)
                .font(NotoSansKR.font(size: 13, weight: .bold, relativeTo: .footnote))
                .foregroundStyle(Color("TextSecondary"))
                .frame(minHeight: eyebrowLineHeight)

            Text(window.timeRange)
                .font(NotoSansKR.font(size: 24, weight: .bold, relativeTo: .title2))
                .foregroundStyle(Color("TextPrimary"))
                .frame(minHeight: timeLineHeight)

            if let relativeTime = presentation.relativeTime {
                Text(relativeTime)
                    .font(NotoSansKR.font(size: 13, weight: .regular, relativeTo: .footnote))
                    .foregroundStyle(Color("TextSecondary"))
                    .frame(minHeight: relativeTimeLineHeight)
            }

            WeekdayRow(activeWeekdays: window.activeWeekdays)

            if window.isEndAlarmEnabled {
                Text("알람 \(window.alarmTimeLabel)")
                    .font(NotoSansKR.font(size: 12, weight: .medium, relativeTo: .caption1))
                    .foregroundStyle(Color("TextSecondary"))
                    .frame(minHeight: alarmLineHeight)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color("SurfacePrimary"), in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color("BorderSubtle"), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }
}

private struct WeekdayRow: View {
    let activeWeekdays: Set<Weekday>

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.flexible(), spacing: 6),
                        count: accessibilityColumnCount
                    ),
                    alignment: .leading,
                    spacing: 6
                ) {
                    weekdayChips
                }
            } else {
                HStack(spacing: 6) {
                    weekdayChips
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("반복 요일")
        .accessibilityValue(
            Weekday.allCases
                .filter(activeWeekdays.contains)
                .map(\.fullName)
                .joined(separator: ", ")
        )
    }

    private var accessibilityColumnCount: Int {
        dynamicTypeSize >= .accessibility4 ? 2 : 4
    }

    @ViewBuilder
    private var weekdayChips: some View {
        ForEach(Weekday.allCases) { weekday in
            WeekdayChip(
                weekday: weekday,
                isActive: activeWeekdays.contains(weekday),
                fillsGridCell: dynamicTypeSize.isAccessibilitySize
            )
        }
    }
}

private struct WeekdayChip: View {
    let weekday: Weekday
    let isActive: Bool
    let fillsGridCell: Bool

    @ScaledMetric(relativeTo: .caption2) private var minimumSize = 28.0

    var body: some View {
        Text(weekday.shortName)
            .font(NotoSansKR.font(size: 11, weight: .medium, relativeTo: .caption2))
            .foregroundStyle(isActive ? Color("SurfacePrimary") : Color("TextSecondary"))
            .frame(
                minWidth: minimumSize,
                maxWidth: fillsGridCell ? .infinity : minimumSize,
                minHeight: minimumSize
            )
            .background(
                isActive ? Color("BrandAccent") : Color("SurfaceSecondary"),
                in: Capsule()
            )
    }
}

private enum NapWindowPresentation {
    case upcoming
    case enabled
    case disabled

    var eyebrow: String {
        switch self {
        case .upcoming: "오늘 열리는 시간"
        case .enabled: "활성화된 시간"
        case .disabled: "비활성화된 시간"
        }
    }

    var relativeTime: String? {
        self == .upcoming ? "1시간 12분 후 열려요" : nil
    }
}

#Preview("Home · Default") {
    HomeView()
        .preferredColorScheme(.light)
}
