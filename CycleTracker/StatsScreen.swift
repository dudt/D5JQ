import SwiftUI
import SwiftData
import Charts

struct StatsScreen: View {
    @Query(sort: \Cycle.startDate) private var cycles: [Cycle]
    @Query private var logs: [DailyLog]

    private var analysis: CycleAnalysis { CyclePredictor.analyze(cycles: cycles) }

    var body: some View {
        NavigationStack {
            List {
                Section("概览") {
                    row("平均周期长度", "\(analysis.avgCycleLength) 天")
                    row("平均经期长度", "\(analysis.avgPeriodLength) 天")
                    row("已记录周期数", "\(cycles.count) 次")
                    row("预测可信度", "\(Int(analysis.confidence * 100))%")
                    if let next = analysis.nextPredictedStart {
                        row("下次经期预测", next.formatted(.dateTime.year().month().day()))
                    }
                }
                if analysis.cycleLengths.count >= 2 {
                    Section("周期长度趋势") {
                        Chart(Array(analysis.cycleLengths.enumerated()), id: \.offset) { i, len in
                            LineMark(x: .value("第几次", i + 1), y: .value("天数", len))
                                .foregroundStyle(.pink)
                            PointMark(x: .value("第几次", i + 1), y: .value("天数", len))
                                .foregroundStyle(.pink)
                        }
                        .chartYScale(domain: .automatic(includesZero: false))
                        .frame(height: 200)
                        .padding(.vertical, 8)
                    }
                }
                if !painData.isEmpty {
                    Section("疼痛记录（近 90 天）") {
                        Chart(painData, id: \.date) { item in
                            BarMark(x: .value("日期", item.date, unit: .day),
                                    y: .value("疼痛", item.pain))
                                .foregroundStyle(.orange)
                        }
                        .frame(height: 150)
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("统计")
        }
    }

    private var painData: [(date: Date, pain: Int)] {
        let cutoff = Date().adding(days: -90)
        return logs.filter { $0.pain > 0 && $0.date >= cutoff }
            .sorted { $0.date < $1.date }
            .map { ($0.date, $0.pain) }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }
}
