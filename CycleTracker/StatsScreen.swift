import SwiftUI
import SwiftData
import Charts

struct StatsScreen: View {
    @Query(sort: \Cycle.startDate) private var cycles: [Cycle]
    @Query private var logs: [DailyLog]

    private var analysis: CycleAnalysis { CyclePredictor.analyze(cycles: cycles) }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 14) {
                        overviewGrid
                        if let next = analysis.nextPredictedStart {
                            nextPeriodCard(next)
                        }
                        if analysis.cycleLengths.count >= 2 {
                            trendCard
                        }
                        if !painData.isEmpty {
                            painCard
                        }
                        if cycles.count >= 2 {
                            historyCard
                        }
                        if cycles.count < 3 {
                            hintCard
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("统计")
        }
    }

    // MARK: - 概览四宫格

    private var overviewGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
            statCard(icon: "arrow.triangle.2.circlepath", color: .follicularBlue,
                     value: "\(analysis.avgCycleLength)", unit: "天", title: "平均周期")
            statCard(icon: "drop.fill", color: .periodRed,
                     value: "\(analysis.avgPeriodLength)", unit: "天", title: "平均经期")
            statCard(icon: "list.number", color: .ovulationViolet,
                     value: "\(cycles.count)", unit: "次", title: "已记录周期")
            statCard(icon: "target", color: .fertileTeal,
                     value: "\(Int(analysis.confidence * 100))", unit: "%", title: "预测可信度")
        }
    }

    private func statCard(icon: String, color: Color, value: String, unit: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.11), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text(unit)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func nextPeriodCard(_ next: Date) -> some View {
        let days = next.days(since: Date().startOfDay)
        return HStack(spacing: 14) {
            Image(systemName: "calendar.badge.clock")
                .font(.title3)
                .foregroundStyle(Color.brandRose)
                .frame(width: 44, height: 44)
                .background(Color.brandRose.opacity(0.1), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text("下次经期预测")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(next.formatted(.dateTime.year().month().day().weekday()))
                    .font(.system(.headline, design: .rounded))
            }
            Spacer()
            if days > 0 {
                VStack(spacing: 0) {
                    Text("\(days)")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.brandRose)
                    Text("天后")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .card()
    }

    // MARK: - 图表卡片

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("周期长度趋势", systemImage: "chart.line.uptrend.xyaxis")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.brandRose)
            Chart(Array(analysis.cycleLengths.enumerated()), id: \.offset) { i, len in
                AreaMark(x: .value("第几次", i + 1), y: .value("天数", len))
                    .foregroundStyle(
                        LinearGradient(colors: [Color.brandRose.opacity(0.25), .clear],
                                       startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.catmullRom)
                LineMark(x: .value("第几次", i + 1), y: .value("天数", len))
                    .foregroundStyle(Color.brandRose)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .interpolationMethod(.catmullRom)
                PointMark(x: .value("第几次", i + 1), y: .value("天数", len))
                    .foregroundStyle(Color.brandRose)
                    .symbolSize(36)
                RuleMark(y: .value("平均", analysis.avgCycleLength))
                    .foregroundStyle(Color.secondary.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .frame(height: 190)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var painCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("疼痛记录（近 90 天）", systemImage: "bolt.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.lutealAmber)
            Chart(painData, id: \.date) { item in
                BarMark(x: .value("日期", item.date, unit: .day),
                        y: .value("疼痛", item.pain), width: 5)
                    .foregroundStyle(
                        LinearGradient(colors: [Color.lutealAmber, Color.lutealAmber.opacity(0.5)],
                                       startPoint: .top, endPoint: .bottom))
                    .cornerRadius(2.5)
            }
            .chartYScale(domain: 0...3)
            .frame(height: 140)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: - 周期历史

    private var historyCard: some View {
        let sorted = cycles.sorted { $0.startDate < $1.startDate }
        let maxLen = analysis.cycleLengths.max() ?? 1
        return VStack(alignment: .leading, spacing: 12) {
            Label("周期历史", systemImage: "clock.arrow.circlepath")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.ovulationViolet)
            ForEach(Array(sorted.enumerated().reversed()), id: \.element.persistentModelID) { i, c in
                let len: Int? = i + 1 < sorted.count
                    ? sorted[i + 1].startDate.days(since: c.startDate)
                    : nil
                HStack(spacing: 10) {
                    Text(c.startDate.formatted(.dateTime.year(.twoDigits).month().day()))
                        .font(.system(.footnote, design: .rounded))
                        .frame(width: 88, alignment: .leading)
                        .foregroundStyle(.secondary)
                    if let len {
                        GeometryReader { geo in
                            Capsule()
                                .fill(LinearGradient(colors: [Color.brandRose.opacity(0.7), Color.brandRose],
                                                     startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * CGFloat(len) / CGFloat(max(maxLen, 1)))
                                .frame(maxHeight: .infinity, alignment: .center)
                        }
                        .frame(height: 8)
                        Text("\(len) 天")
                            .font(.system(.footnote, design: .rounded).weight(.semibold))
                            .frame(width: 44, alignment: .trailing)
                    } else {
                        Spacer()
                        Text("最近一次")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var hintCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(Color.lutealAmber)
            Text("记录满 3 个周期后，趋势图和预测会更完整、更准确")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var painData: [(date: Date, pain: Int)] {
        let cutoff = Date().adding(days: -90)
        return logs.filter { $0.pain > 0 && $0.date >= cutoff }
            .sorted { $0.date < $1.date }
            .map { ($0.date, $0.pain) }
    }
}
