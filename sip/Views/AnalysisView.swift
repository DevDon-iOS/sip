//
//  AnalysisView.swift
//  sip
//
//  Created by 이돈혁 on 7/15/25.
//

import Charts
import SwiftUI

struct AnalysisView: View {
    private let initialRecords: [SleepRecord]?
    @State private var records: [SleepRecord]?
    @State private var isConditionCheckInPresented = false

    init(records: [SleepRecord]? = nil) {
        initialRecords = records
        _records = State(initialValue: records)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("기록")
                        .font(NotoSansKR.font(size: 28, weight: .bold, relativeTo: .largeTitle))
                        .foregroundStyle(Color("TextPrimary"))
                        .frame(minHeight: 38)
                        .accessibilityAddTraits(.isHeader)

                    if let records {
                        if records.isEmpty {
                            RecordsEmptyView {
                                isConditionCheckInPresented = true
                            }
                            .padding(.top, 21)
                        } else {
                            RecordsContent(records: records)
                                .padding(.top, 21)
                        }
                    } else {
                        ProgressView()
                            .tint(Color("BrandAccent"))
                            .frame(maxWidth: .infinity, minHeight: 210)
                            .accessibilityLabel("기록 불러오는 중")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 32)
                .containerRelativeFrame(.horizontal)
            }
            .background(Color("BackgroundCanvas").ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $isConditionCheckInPresented) {
                ConditionCheckInView(record: nil)
            }
            .task {
                guard initialRecords == nil, records == nil else { return }

                do {
                    records = try await HealthKitService.shared.fetchRecentNaps()
                } catch {
                    records = []
                }
            }
        }
    }
}

private struct RecordsContent: View {
    let records: [SleepRecord]

    private var recentRecords: [SleepRecord] {
        records.sorted { $0.endDate > $1.endDate }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TrendCard(records: recentRecords)

            Text("낮잠 기록 \(recentRecords.count)")
                .font(NotoSansKR.font(size: 16, weight: .bold, relativeTo: .callout))
                .foregroundStyle(Color("TextPrimary"))
                .frame(minHeight: 24)
                .padding(.top, 20)
                .padding(.bottom, 12)
                .accessibilityAddTraits(.isHeader)

            LazyVStack(spacing: 8) {
                ForEach(recentRecords) { record in
                    NavigationLink(value: record) {
                        RecordRow(record: record)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationDestination(for: SleepRecord.self) { record in
            RecordFlowDestination(
                record: record,
                checkIn: ConditionCheckInStorage.checkIn(for: record.id)
            )
        }
    }
}

private struct TrendCard: View {
    let records: [SleepRecord]

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var trend: [DailyNapDuration] {
        DailyNapDuration.recentSevenDays(from: records)
    }

    private var recordedTrend: [DailyNapDuration] {
        trend.filter { $0.minutes != nil }
    }

    private var averageMinutes: Int {
        guard !recordedTrend.isEmpty else { return 0 }
        let total = recordedTrend.compactMap(\.minutes).reduce(0, +)
        return Int((Double(total) / Double(recordedTrend.count)).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    title
                    Spacer(minLength: 8)
                    summary
                }

                VStack(alignment: .leading, spacing: 2) {
                    title
                    summary
                }
            }

            if recordedTrend.count >= 3 {
                Chart {
                    ForEach(recordedTrend) { item in
                        if let minutes = item.minutes {
                            LineMark(
                                x: .value("요일", item.dayIndex),
                                y: .value("낮잠 시간", minutes)
                            )
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                            .foregroundStyle(Color("BrandAccent"))

                            PointMark(
                                x: .value("요일", item.dayIndex),
                                y: .value("낮잠 시간", minutes)
                            )
                            .symbolSize(36)
                            .foregroundStyle(Color("BrandAccent"))
                            .annotation(position: .top, spacing: 4) {
                                Text("\(minutes)")
                                    .font(NotoSansKR.font(size: 10, weight: .medium, relativeTo: .caption2))
                                    .foregroundStyle(Color("BrandAccent"))
                            }
                        }
                    }
                }
                .chartXScale(domain: 0...6)
                .chartYScale(domain: 20...40)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartPlotStyle { plotArea in
                    plotArea
                        .padding(.top, 12)
                        .padding(.horizontal, 18)
                }
                .frame(height: dynamicTypeSize.isAccessibilitySize ? 135 : 105)
                .padding(.top, 10)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("최근 7일 낮잠 추세")
                .accessibilityValue(accessibilitySummary)

                Rectangle()
                    .fill(Color("BorderSubtle"))
                    .frame(height: 1)
                    .padding(.top, 8)
                    .accessibilityHidden(true)

                HStack(spacing: 0) {
                    ForEach(trend) { item in
                        Text(item.weekdayLabel)
                            .font(NotoSansKR.font(size: 10, weight: .regular, relativeTo: .caption2))
                            .foregroundStyle(Color("TextSecondary"))
                            .frame(maxWidth: .infinity, minHeight: 15)
                    }
                }
                .padding(.top, 8)
            } else {
                Spacer(minLength: 16)
                Rectangle()
                    .fill(Color("BorderSubtle"))
                    .frame(height: 1)
                    .accessibilityHidden(true)
                Spacer(minLength: 16)
            }
        }
        .frame(maxWidth: .infinity, minHeight: dynamicTypeSize.isAccessibilitySize ? 208 : 178, alignment: .topLeading)
        .padding(16)
        .background(Color("SurfacePrimary"), in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color("BorderSubtle"), lineWidth: 1)
        }
    }

    private var title: some View {
        Text("최근 7일")
            .font(NotoSansKR.font(size: 16, weight: .bold, relativeTo: .callout))
            .foregroundStyle(Color("TextPrimary"))
            .frame(minHeight: 24)
    }

    private var summary: some View {
        Text("평균 \(averageMinutes)분 · \(recordedTrend.count)회")
            .font(NotoSansKR.font(size: 12, weight: .medium, relativeTo: .caption1))
            .foregroundStyle(Color("TextSecondary"))
            .frame(minHeight: 18)
    }

    private var accessibilitySummary: String {
        recordedTrend.compactMap { item in
            guard let minutes = item.minutes else { return nil }
            return "\(item.weekdayLabel)요일 \(minutes)분"
        }
        .joined(separator: ", ")
    }
}

private struct RecordRow: View {
    let record: SleepRecord

    var body: some View {
        HStack(spacing: 12) {
            Text(record.dateLabel)
                .font(NotoSansKR.font(size: 13, weight: .regular, relativeTo: .footnote))
                .foregroundStyle(Color("TextSecondary"))
                .lineLimit(1)

            Spacer(minLength: 8)

            Text("\(record.durationMinutes)분")
                .font(NotoSansKR.font(size: 15, weight: .bold, relativeTo: .body))
                .foregroundStyle(Color("TextPrimary"))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 64)
        .padding(.horizontal, 16)
        .background(Color("SurfacePrimary"), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color("BorderSubtle"), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(record.dateLabel), \(record.durationMinutes)분")
    }
}

private struct DailyNapDuration: Identifiable {
    let dayIndex: Int
    let date: Date
    let weekdayLabel: String
    let minutes: Int?

    var id: Int { dayIndex }

    static func recentSevenDays(
        from records: [SleepRecord],
        calendar: Calendar = .current,
        now: Date = .now
    ) -> [DailyNapDuration] {
        let today = calendar.startOfDay(for: now)

        return (0..<7).compactMap { index in
            guard let date = calendar.date(byAdding: .day, value: index - 6, to: today) else {
                return nil
            }

            let minutes = records
                .filter { calendar.isDate($0.endDate, inSameDayAs: date) }
                .map(\.durationMinutes)
                .reduce(0, +)

            return DailyNapDuration(
                dayIndex: index,
                date: date,
                weekdayLabel: weekdayFormatter.string(from: date),
                minutes: minutes > 0 ? minutes : nil
            )
        }
    }

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "EEEEE"
        return formatter
    }()
}

#if DEBUG
extension SleepRecord {
    static let figmaDetected = previewRecord(
        daysAgo: 0,
        hour: 13,
        minute: 50,
        durationMinutes: 42
    )

    static let figmaRecords: [SleepRecord] = [
        previewRecord(daysAgo: 0, hour: 13, minute: 24, durationMinutes: 36),
        previewRecord(daysAgo: 2, hour: 14, minute: 8, durationMinutes: 26),
        previewRecord(daysAgo: 4, hour: 13, minute: 40, durationMinutes: 34),
        previewRecord(daysAgo: 6, hour: 12, minute: 58, durationMinutes: 28)
    ]

    private static func previewRecord(
        daysAgo: Int,
        hour: Int,
        minute: Int,
        durationMinutes: Int
    ) -> SleepRecord {
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
        let endDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        return SleepRecord(
            startDate: endDate.addingTimeInterval(TimeInterval(-durationMinutes * 60)),
            endDate: endDate
        )
    }
}
#endif

#if DEBUG
#Preview("Records · Data") {
    AnalysisView(records: SleepRecord.figmaRecords)
        .preferredColorScheme(.light)
}
#endif
