//
//  ConditionRecordViews.swift
//  sip
//
//  Created by 이돈혁 on 8/20/26.
//

import SwiftUI

struct ConditionCheckInView: View {
    let record: SleepRecord?
    let shouldDismissOnSave: Bool
    let onSave: (ConditionCheckIn) -> Void

    @State private var energy = 0.5
    @State private var focus = 0.5
    @State private var mood = 0.5
    @State private var isSaveErrorPresented = false

    @Environment(\.dismiss) private var dismiss

    init(
        record: SleepRecord?,
        shouldDismissOnSave: Bool = true,
        onSave: @escaping (ConditionCheckIn) -> Void = { _ in }
    ) {
        self.record = record
        self.shouldDismissOnSave = shouldDismissOnSave
        self.onSave = onSave
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let record {
                    NapRecordSummary(record: record)
                } else {
                    NoNapSummary()
                }

                Text("지금 상태는 어떤가요?")
                    .font(NotoSansKR.font(size: 16, weight: .bold, relativeTo: .callout))
                    .foregroundStyle(Color("TextPrimary"))
                    .frame(minHeight: 24)
                    .accessibilityAddTraits(.isHeader)

                ConditionSlidersCard(
                    energy: $energy,
                    focus: $focus,
                    mood: $mood
                )

                Button("나중에") {
                    dismiss()
                }
                .font(NotoSansKR.font(size: 14, weight: .bold, relativeTo: .body))
                .foregroundStyle(Color("TextSecondary"))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color("SurfacePrimary"), in: RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color("BorderSubtle"), lineWidth: 1)
                }
                .accessibilityHint("상태를 저장하지 않고 이전 화면으로 돌아갑니다")
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
                Text(record == nil ? "결과" : "기상 후 상태")
                    .font(NotoSansKR.font(size: 16, weight: .bold, relativeTo: .headline))
                    .foregroundStyle(Color("TextPrimary"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .accessibilityAddTraits(.isHeader)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(action: save) {
                    Image("IconoirCheck")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color("BrandAccent"))
                .accessibilityLabel("상태 저장")
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .alert("상태를 저장하지 못했어요", isPresented: $isSaveErrorPresented) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("잠시 후 다시 시도해 주세요.")
        }
    }

    private func save() {
        let checkIn = ConditionCheckIn(
            napSessionID: record?.id,
            energy: energy,
            focus: focus,
            mood: mood
        )

        do {
            try ConditionCheckInStorage.save(checkIn)
            onSave(checkIn)
            if shouldDismissOnSave {
                dismiss()
            }
        } catch {
            isSaveErrorPresented = true
        }
    }
}

struct RecordDetailView: View {
    let record: SleepRecord
    let checkIn: ConditionCheckIn

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                NapRecordSummary(record: record)

                RecordSectionTitle("기상 후 상태")
                ConditionSummaryCard(checkIn: checkIn)

                RecordSectionTitle("시간")
                TimeDetailsCard(record: record)
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
                Text("낮잠 기록")
                    .font(NotoSansKR.font(size: 16, weight: .bold, relativeTo: .headline))
                    .foregroundStyle(Color("TextPrimary"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

struct RecordFlowDestination: View {
    let record: SleepRecord
    @State private var checkIn: ConditionCheckIn?

    init(record: SleepRecord, checkIn: ConditionCheckIn?) {
        self.record = record
        _checkIn = State(initialValue: checkIn)
    }

    var body: some View {
        if let checkIn {
            RecordDetailView(record: record, checkIn: checkIn)
        } else {
            ConditionCheckInView(
                record: record,
                shouldDismissOnSave: false
            ) { savedCheckIn in
                checkIn = savedCheckIn
            }
        }
    }
}

private struct NapRecordSummary: View {
    let record: SleepRecord

    var body: some View {
        VStack(spacing: 4) {
            Text("기록됨")
                .font(NotoSansKR.font(size: 12, weight: .bold, relativeTo: .caption1))
                .foregroundStyle(Color("BrandAccent"))
                .frame(minHeight: 18)

            Text("\(record.durationMinutes)분")
                .font(NotoSansKR.font(size: 36, weight: .bold, relativeTo: .largeTitle))
                .foregroundStyle(Color("TextPrimary"))
                .frame(minHeight: 48)

            Text(record.timeRangeLabel)
                .font(NotoSansKR.font(size: 14, weight: .medium, relativeTo: .body))
                .foregroundStyle(Color("TextSecondary"))
                .frame(minHeight: 22)

            Text(record.dayLabel)
                .font(NotoSansKR.font(size: 13, weight: .medium, relativeTo: .footnote))
                .foregroundStyle(Color("TextSecondary"))
                .frame(minHeight: 20)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 160)
        .background(Color("SurfacePrimary"), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("기록된 낮잠")
        .accessibilityValue(
            "\(record.durationMinutes)분, \(record.timeRangeLabel), \(record.dayLabel)"
        )
    }
}

private struct NoNapSummary: View {
    var body: some View {
        VStack(spacing: 6) {
            Text("잠든 기록이 없어요")
                .font(NotoSansKR.font(size: 20, weight: .bold, relativeTo: .title3))
                .foregroundStyle(Color("TextPrimary"))
                .frame(minHeight: 30)

            Text("상태만 남길 수 있어요")
                .font(NotoSansKR.font(size: 13, weight: .medium, relativeTo: .footnote))
                .foregroundStyle(Color("TextSecondary"))
                .frame(minHeight: 20)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 96)
        .background(Color("SurfacePrimary"), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}

private struct ConditionSlidersCard: View {
    @Binding var energy: Double
    @Binding var focus: Double
    @Binding var mood: Double

    var body: some View {
        VStack(spacing: 10) {
            ConditionSlider(metric: .energy, value: $energy)
            ConditionSlider(metric: .focus, value: $focus)
            ConditionSlider(metric: .mood, value: $mood)
        }
        .padding(16)
        .background(Color("SurfacePrimary"), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct ConditionSlider: View {
    let metric: ConditionMetric
    @Binding var value: Double

    private var feedbackStep: Int {
        Int((value * 4).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(metric.title)
                .font(NotoSansKR.font(size: 14, weight: .bold, relativeTo: .body))
                .foregroundStyle(Color("TextPrimary"))
                .frame(minHeight: 22)

            ZStack {
                HStack {
                    ForEach(0..<5, id: \.self) { index in
                        Circle()
                            .fill(Color("BorderSubtle"))
                            .frame(width: 4, height: 4)
                        if index != 4 { Spacer() }
                    }
                }
                .padding(.horizontal, 18)
                .offset(y: 11)
                .accessibilityHidden(true)

                Slider(value: $value, in: 0...1)
                    .tint(metric.color)
                    .accessibilityLabel(metric.title)
                    .accessibilityValue(metric.accessibilityValue(for: value))
                    .sensoryFeedback(.selection, trigger: feedbackStep)
            }
            .frame(height: 40)

            ViewThatFits(in: .horizontal) {
                HStack {
                    Text(metric.minimumLabel)
                    Spacer(minLength: 8)
                    Text(metric.maximumLabel)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(metric.minimumLabel)
                    Text(metric.maximumLabel)
                }
            }
            .font(NotoSansKR.font(size: 11, weight: .medium, relativeTo: .caption2))
            .foregroundStyle(Color("TextTertiary"))
            .frame(minHeight: 16)
            .accessibilityHidden(true)
        }
        .frame(minHeight: 82)
    }
}

private enum ConditionMetric {
    case energy
    case focus
    case mood

    var title: String {
        switch self {
        case .energy: "에너지"
        case .focus: "집중"
        case .mood: "기분"
        }
    }

    var minimumLabel: String {
        switch self {
        case .energy: "기운이 없어요"
        case .focus: "흐릿해요"
        case .mood: "불편해요"
        }
    }

    var maximumLabel: String {
        switch self {
        case .energy: "활력이 있어요"
        case .focus: "또렷해요"
        case .mood: "편안해요"
        }
    }

    var color: Color {
        switch self {
        case .energy: Color("ConditionEnergy")
        case .focus: Color("BrandAccent")
        case .mood: Color("ConditionMood")
        }
    }

    func accessibilityValue(for value: Double) -> String {
        if value < 0.34 { return minimumLabel }
        if value > 0.66 { return maximumLabel }
        return "중간"
    }

    func savedValueLabel(for value: Double) -> String {
        value < 0.5 ? minimumLabel : maximumLabel
    }
}

private struct RecordSectionTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(NotoSansKR.font(size: 16, weight: .bold, relativeTo: .callout))
            .foregroundStyle(Color("TextPrimary"))
            .frame(minHeight: 24)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct ConditionSummaryCard: View {
    let checkIn: ConditionCheckIn

    var body: some View {
        VStack(spacing: 0) {
            ConditionSummaryRow(metric: .energy, value: checkIn.energy)
            RecordDivider()
            ConditionSummaryRow(metric: .focus, value: checkIn.focus)
            RecordDivider()
            ConditionSummaryRow(metric: .mood, value: checkIn.mood)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(Color("SurfacePrimary"), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct ConditionSummaryRow: View {
    let metric: ConditionMetric
    let value: Double

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(metric.color)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)

            Text(metric.title)
                .font(NotoSansKR.font(size: 14, weight: .bold, relativeTo: .body))
                .foregroundStyle(Color("TextPrimary"))

            Spacer(minLength: 8)

            Text(metric.savedValueLabel(for: value))
                .font(NotoSansKR.font(size: 14, weight: .medium, relativeTo: .body))
                .foregroundStyle(Color("TextSecondary"))
        }
        .frame(minHeight: 52)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(metric.title)
        .accessibilityValue(metric.savedValueLabel(for: value))
    }
}

private struct TimeDetailsCard: View {
    let record: SleepRecord

    var body: some View {
        VStack(spacing: 0) {
            TimeDetailRow(label: "시작", value: Self.timeFormatter.string(from: record.startDate))
            RecordDivider()
            TimeDetailRow(label: "종료", value: Self.timeFormatter.string(from: record.endDate))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(Color("SurfacePrimary"), in: RoundedRectangle(cornerRadius: 16))
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

private struct TimeDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(Color("TextPrimary"))
            Spacer(minLength: 8)
            Text(value)
                .foregroundStyle(Color("TextSecondary"))
        }
        .font(NotoSansKR.font(size: 14, weight: .medium, relativeTo: .body))
        .frame(minHeight: 52)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }
}

private struct RecordDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color("BorderSubtle"))
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

#if DEBUG
private struct ConditionPreviewContainer<Content: View>: View {
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

#Preview("Condition Detected · iPhone 13 mini") {
    ConditionPreviewContainer {
        ConditionCheckInView(record: .figmaDetected)
    }
    .frame(width: 375, height: 812)
}

#Preview("Condition Detected · iPhone SE") {
    ConditionPreviewContainer {
        ConditionCheckInView(record: .figmaDetected)
    }
    .frame(width: 375, height: 667)
}

#Preview("Condition Detected · iPhone 15 Pro") {
    ConditionPreviewContainer {
        ConditionCheckInView(record: .figmaDetected)
    }
    .frame(width: 393, height: 852)
}

#Preview("No Nap · iPhone 13 mini") {
    ConditionPreviewContainer {
        ConditionCheckInView(record: nil)
    }
    .frame(width: 375, height: 812)
}

#Preview("No Nap · iPhone SE") {
    ConditionPreviewContainer {
        ConditionCheckInView(record: nil)
    }
    .frame(width: 375, height: 667)
}

#Preview("No Nap · iPhone 15 Pro") {
    ConditionPreviewContainer {
        ConditionCheckInView(record: nil)
    }
    .frame(width: 393, height: 852)
}

#Preview("Record Detail · iPhone 13 mini") {
    ConditionPreviewContainer {
        RecordDetailView(
            record: .figmaDetected,
            checkIn: .figmaSaved(for: .figmaDetected)
        )
    }
    .frame(width: 375, height: 812)
}

#Preview("Record Detail · iPhone SE") {
    ConditionPreviewContainer {
        RecordDetailView(
            record: .figmaDetected,
            checkIn: .figmaSaved(for: .figmaDetected)
        )
    }
    .frame(width: 375, height: 667)
}

#Preview("Record Detail · iPhone 15 Pro") {
    ConditionPreviewContainer {
        RecordDetailView(
            record: .figmaDetected,
            checkIn: .figmaSaved(for: .figmaDetected)
        )
    }
    .frame(width: 393, height: 852)
}
#endif
