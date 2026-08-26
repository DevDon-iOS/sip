//
//  ScheduleEditView.swift
//  sip
//
//  Created by 이돈혁 on 8/20/26.
//

import SwiftUI

struct ScheduleEditView: View {
    @State private var draft: NapWindow

    private let onSave: (NapWindow) -> Void
    @Environment(\.dismiss) private var dismiss

    init(
        window: NapWindow = .defaultDraft,
        onSave: @escaping (NapWindow) -> Void = { _ in }
    ) {
        _draft = State(initialValue: window)
        self.onSave = onSave
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScheduleSectionTitle("시간")

                ScheduleCard {
                    TimePickerRow(
                        label: "시작",
                        accessibilityLabel: "시작 시간",
                        selection: $draft.startTime
                    )
                    ScheduleDivider()
                    TimePickerRow(
                        label: "종료",
                        accessibilityLabel: "종료 시간",
                        selection: $draft.endTime
                    )
                }

                ScheduleSectionTitle("반복 요일")

                WeekdaySelectionCard(selection: $draft.activeWeekdays)

                ScheduleSectionTitle("종료 알람")

                ScheduleCard {
                    Toggle(isOn: $draft.isEndAlarmEnabled) {
                        ScheduleRowLabel("종료 알람")
                    }
                    .toggleStyle(.switch)
                    .tint(Color("BrandAccent"))
                    .frame(minHeight: 44)
                    .accessibilityHint("시간대 종료 시 알람을 울립니다")

                    if draft.isEndAlarmEnabled {
                        ScheduleDivider()
                        TimePickerRow(
                            label: "알람 시간",
                            accessibilityLabel: "알람 시간",
                            selection: $draft.alarmTime
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 26)
            .padding(.bottom, 24)
        }
        .background(Color("BackgroundCanvas").ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("시간 편집")
                    .font(NotoSansKR.font(size: 16, weight: .bold, relativeTo: .headline))
                    .foregroundStyle(Color("TextPrimary"))
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
                .disabled(draft.activeWeekdays.isEmpty)
                .accessibilityLabel("시간 저장")
                .accessibilityHint("편집한 낮잠 가능 시간을 저장합니다")
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func save() {
        guard !draft.activeWeekdays.isEmpty else { return }
        onSave(draft)
        dismiss()
    }
}

private struct ScheduleSectionTitle: View {
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

private struct ScheduleCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(Color("SurfacePrimary"), in: RoundedRectangle(cornerRadius: 16))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct TimePickerRow: View {
    let label: String
    let accessibilityLabel: String
    @Binding var selection: Date

    var body: some View {
        HStack(spacing: 12) {
            ScheduleRowLabel(label)
            Spacer(minLength: 8)
            DatePicker(
                "",
                selection: $selection,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .font(NotoSansKR.font(size: 15, weight: .medium, relativeTo: .body))
            .tint(Color("BrandAccent"))
            .environment(\.locale, Locale(identifier: "en_GB"))
            .accessibilityLabel(accessibilityLabel)
        }
        .frame(minHeight: 44)
    }
}

private struct ScheduleRowLabel: View {
    let label: String

    init(_ label: String) {
        self.label = label
    }

    var body: some View {
        Text(label)
            .font(NotoSansKR.font(size: 14, weight: .medium, relativeTo: .body))
            .foregroundStyle(Color("TextPrimary"))
            .frame(minHeight: 22)
    }
}

private struct ScheduleDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color("BorderSubtle"))
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

private struct WeekdaySelectionCard: View {
    @Binding var selection: Set<Weekday>
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: dynamicTypeSize.isAccessibilitySize ? 12 : 7) {
            if dynamicTypeSize.isAccessibilitySize {
                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.flexible(), spacing: 6),
                        count: dynamicTypeSize >= .accessibility4 ? 2 : 4
                    ),
                    spacing: 6
                ) {
                    weekdayButtons
                }
            } else {
                HStack(spacing: 6) {
                    weekdayButtons
                }
            }

            Text("요일은 여러 개 선택할 수 있어요")
                .font(NotoSansKR.font(size: 12, weight: .medium, relativeTo: .caption1))
                .foregroundStyle(Color("TextSecondary"))
                .frame(minHeight: 18)
        }
        .padding(.horizontal, 16)
        .padding(.top, dynamicTypeSize.isAccessibilitySize ? 16 : 11)
        .padding(.bottom, 16)
        .background(Color("SurfacePrimary"), in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var weekdayButtons: some View {
        ForEach(Weekday.allCases) { weekday in
            let isSelected = selection.contains(weekday)

            Button {
                if isSelected {
                    selection.remove(weekday)
                } else {
                    selection.insert(weekday)
                }
            } label: {
                Text(weekday.shortName)
                    .font(NotoSansKR.font(size: 12, weight: .medium, relativeTo: .caption1))
                    .foregroundStyle(isSelected ? Color("SurfacePrimary") : Color("TextSecondary"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background(
                        isSelected ? Color("BrandAccent") : Color("SurfaceSecondary"),
                        in: Capsule()
                    )
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, minHeight: 44)
            .accessibilityLabel(weekday.fullName)
            .accessibilityValue(isSelected ? "선택됨" : "선택 안 됨")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }
}

#Preview("Schedule Edit · iPhone 13 mini") {
    NavigationStack {
        ScheduleEditView()
    }
    .frame(width: 375, height: 812)
    .preferredColorScheme(.light)
}

#Preview("Schedule Edit · iPhone SE") {
    NavigationStack {
        ScheduleEditView()
    }
    .frame(width: 375, height: 667)
    .preferredColorScheme(.light)
}

#Preview("Schedule Edit · iPhone 15 Pro") {
    NavigationStack {
        ScheduleEditView()
    }
    .frame(width: 393, height: 852)
    .preferredColorScheme(.light)
}
