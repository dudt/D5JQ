import SwiftUI
import SwiftData

struct CalendarScreen: View {
    @Query(sort: \Cycle.startDate) private var cycles: [Cycle]
    @Query private var logs: [DailyLog]
    @State private var monthOffset = 0
    @State private var selectedDate: Date? = nil
    @State private var showImport = false

    private var analysis: CycleAnalysis { CyclePredictor.analyze(cycles: cycles) }

    private var displayMonth: Date {
        Calendar.current.date(byAdding: .month, value: monthOffset, to: Date().startOfDay) ?? Date()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    summaryCard
                    monthHeader
                    MonthGrid(month: displayMonth, analysis: analysis,
                              loggedDates: Set(logs.map { $0.date })) { day in
                        selectedDate = day
                    }
                    LegendView()
                }
                .padding(.horizontal)
            }
            .navigationTitle("经期助手")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showImport = true
                    } label: {
                        Label("导入历史", systemImage: "square.and.arrow.down")
                    }
                }
            }
            .sheet(item: $selectedDate) { day in
                DaySheet(date: day)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showImport) {
                ImportHistoryView()
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            let today = Date().startOfDay
            let phase = analysis.phase(on: today)
            HStack {
                Image(systemName: phase == .none ? "calendar" : phase.symbol)
                    .foregroundStyle(phase == .none ? .secondary : phase.color)
                Text(phase == .none ? "暂无数据，请先记录或导入经期" : "今天：\(phase.label)")
                    .font(.headline)
            }
            if let next = analysis.nextPredictedStart {
                let days = next.days(since: today)
                if days > 0 {
                    Text("距下次经期约 \(days) 天（\(next.formatted(.dateTime.month().day()))）")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else if phase == .predictedPeriod || phase == .period {
                    Text("经期进行中").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 16) {
                Label("周期约 \(analysis.avgCycleLength) 天", systemImage: "arrow.triangle.2.circlepath")
                Label("经期约 \(analysis.avgPeriodLength) 天", systemImage: "drop")
            }
            .font(.footnote).foregroundStyle(.secondary)
            ProgressView(value: analysis.confidence) {
                Text("预测可信度 \(Int(analysis.confidence * 100))%（记录越多越准）")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .tint(.pink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.pink.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    private var monthHeader: some View {
        HStack {
            Button { monthOffset -= 1 } label: { Image(systemName: "chevron.left") }
            Spacer()
            Text(displayMonth.formatted(.dateTime.year().month()))
                .font(.title3.bold())
                .onTapGesture { monthOffset = 0 }
            Spacer()
            Button { monthOffset += 1 } label: { Image(systemName: "chevron.right") }
        }
        .padding(.horizontal, 8)
    }
}

extension Date: @retroactive Identifiable {
    public var id: TimeInterval { timeIntervalSince1970 }
}

struct MonthGrid: View {
    let month: Date
    let analysis: CycleAnalysis
    let loggedDates: Set<Date>
    let onTap: (Date) -> Void

    private var days: [Date?] {
        let cal = Calendar.current
        guard let interval = cal.dateInterval(of: .month, for: month) else { return [] }
        let firstWeekday = cal.component(.weekday, from: interval.start)
        let leading = (firstWeekday - cal.firstWeekday + 7) % 7
        let count = cal.range(of: .day, in: .month, for: month)?.count ?? 30
        var result: [Date?] = Array(repeating: nil, count: leading)
        for d in 0..<count {
            result.append(interval.start.adding(days: d))
        }
        return result
    }

    private var weekdaySymbols: [String] {
        let cal = Calendar.current
        let symbols = cal.veryShortWeekdaySymbols
        let start = cal.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                ForEach(weekdaySymbols, id: \.self) { s in
                    Text(s).font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let day {
                        DayCell(date: day,
                                phase: analysis.phase(on: day),
                                hasLog: loggedDates.contains(day),
                                isToday: day == Date().startOfDay)
                            .onTapGesture { onTap(day) }
                    } else {
                        Color.clear.frame(height: 48)
                    }
                }
            }
        }
    }
}

struct DayCell: View {
    let date: Date
    let phase: DayPhase
    let hasLog: Bool
    let isToday: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.callout)
                .fontWeight(isToday ? .bold : .regular)
            if phase != .none {
                Image(systemName: phase.symbol)
                    .font(.system(size: 9))
                    .foregroundStyle(phase.color)
            } else {
                Circle().fill(hasLog ? Color.gray : .clear)
                    .frame(width: 4, height: 4)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(phase.color.opacity(phase == .predictedPeriod ? 0.15 : phase == .none ? 0 : 0.18))
        )
        .overlay {
            if phase == .predictedPeriod {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.pink, style: StrokeStyle(lineWidth: 1, dash: [3]))
            } else if isToday {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.pink, lineWidth: 1.5)
            }
        }
    }
}

struct LegendView: View {
    private let phases: [DayPhase] = [.period, .predictedPeriod, .fertile, .ovulation, .luteal, .follicular]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(phases, id: \.label) { p in
                HStack(spacing: 4) {
                    Image(systemName: p.symbol).font(.caption2).foregroundStyle(p.color)
                    Text(p.label).font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(.gray.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }
}
