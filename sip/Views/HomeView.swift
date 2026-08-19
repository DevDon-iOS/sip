//
//  HomeView.swift
//  sip
//
//  Created by 이돈혁 on 7/15/25.
//

import SwiftUI

struct HomeView: View {
    private let onAddWindow: () -> Void
    @ScaledMetric(relativeTo: .callout) private var sectionLineHeight = 24.0

    init(onAddWindow: @escaping () -> Void = {}) {
        self.onAddWindow = onAddWindow
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    NapWindowCard(model: .upcoming)

                    Text("낮잠 가능 시간")
                        .font(NotoSansKR.font(size: 16, weight: .bold, relativeTo: .callout))
                        .foregroundStyle(Color("TextPrimary"))
                        .frame(minHeight: sectionLineHeight)
                        .padding(.top, 24)
                        .padding(.bottom, 12)

                    NapWindowCard(model: .disabled)
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
                    Button(action: onAddWindow) {
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

private struct NapWindowCard: View {
    let model: NapWindowCardModel

    @ScaledMetric(relativeTo: .footnote) private var eyebrowLineHeight = 20.0
    @ScaledMetric(relativeTo: .title2) private var timeLineHeight = 34.0
    @ScaledMetric(relativeTo: .footnote) private var relativeTimeLineHeight = 20.0
    @ScaledMetric(relativeTo: .caption) private var alarmLineHeight = 18.0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.eyebrow)
                .font(NotoSansKR.font(size: 13, weight: .bold, relativeTo: .footnote))
                .foregroundStyle(Color("TextSecondary"))
                .frame(minHeight: eyebrowLineHeight)

            Text(model.timeRange)
                .font(NotoSansKR.font(size: 24, weight: .bold, relativeTo: .title2))
                .foregroundStyle(Color("TextPrimary"))
                .frame(minHeight: timeLineHeight)

            if let relativeTime = model.relativeTime {
                Text(relativeTime)
                    .font(NotoSansKR.font(size: 13, weight: .regular, relativeTo: .footnote))
                    .foregroundStyle(Color("TextSecondary"))
                    .frame(minHeight: relativeTimeLineHeight)
            }

            WeekdayRow(activeWeekdays: model.activeWeekdays)

            if let alarmTime = model.alarmTime {
                Text("알람 \(alarmTime)")
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

private struct NapWindowCardModel {
    let eyebrow: String
    let timeRange: String
    let relativeTime: String?
    let activeWeekdays: Set<Weekday>
    let alarmTime: String?

    static let upcoming = NapWindowCardModel(
        eyebrow: "오늘 열리는 시간",
        timeRange: "13:00–14:00",
        relativeTime: "1시간 12분 후 열려요",
        activeWeekdays: [.monday, .tuesday, .wednesday, .thursday, .friday],
        alarmTime: "14:00"
    )

    static let disabled = NapWindowCardModel(
        eyebrow: "비활성화된 시간",
        timeRange: "13:00–14:00",
        relativeTime: nil,
        activeWeekdays: [.saturday, .sunday],
        alarmTime: nil
    )
}

private enum Weekday: Int, CaseIterable, Identifiable, Hashable {
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
    case sunday

    var id: Int { rawValue }

    var shortName: String {
        switch self {
        case .monday: "월"
        case .tuesday: "화"
        case .wednesday: "수"
        case .thursday: "목"
        case .friday: "금"
        case .saturday: "토"
        case .sunday: "일"
        }
    }

    var fullName: String {
        switch self {
        case .monday: "월요일"
        case .tuesday: "화요일"
        case .wednesday: "수요일"
        case .thursday: "목요일"
        case .friday: "금요일"
        case .saturday: "토요일"
        case .sunday: "일요일"
        }
    }
}

#Preview("Home · Default") {
    HomeView()
        .preferredColorScheme(.light)
}
