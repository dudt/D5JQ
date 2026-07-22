import SwiftUI
import SwiftData

struct CalendarScreen: View {
    @Query(sort: \Cycle.startDate) private var cycles: [Cycle]
    @Query private var logs: [DailyLog]
    @State private var monthOffset = 0
    @State private var selectedDate: Date? = nil
    @State private var showImport = false

    private var analysis: CycleAnalysis { CyclePredictor.analyze(cycles: cycles) }

    /// 周期数据指纹：任何开始/结束日期变化都会触发小组件同步
    private var cycleFingerprint: [Date] {
        cycles.flatMap { [$0.startDate, $0.endDate ?? Date.distantPast] }
    }

    private var displayMonth: Date {
        Calendar.current.date(byAdding: .month, value: monthOffset, to: Date().startOfDay) ?? Date()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: DS.s4) {
                        GreetingHeader { showImport = true }
                            .padding(.top, DS.s2)
                        heroCard
                        WeekStrip(analysis: analysis) { day in
                            selectedDate = day
                        }
                        tipCard
                        calendarCard
                        LegendView()
                            .padding(.bottom, DS.s2)
                    }
                    .padding(.horizontal)
                }
            }
            .toolbarVisibility(.hidden, for: .navigationBar)
            .sensoryFeedback(.selection, trigger: selectedDate)
            .sensoryFeedback(.impact(flexibility: .soft), trigger: monthOffset)
            .onAppear { WidgetSync.push(analysis: analysis) }
            .onChange(of: cycleFingerprint) { _, _ in
                WidgetSync.push(analysis: analysis)
            }
            .sheet(item: $selectedDate) { day in
                DaySheet(date: day)
                    .presentationDetents([.medium, .large])
                    .presentationCornerRadius(28)
            }
            .sheet(isPresented: $showImport) {
                ImportHistoryView()
                    .presentationCornerRadius(28)
            }
        }
    }

    // MARK: - 首屏：周期环卡片

    private var heroCard: some View {
        VStack(spacing: 14) {
            CycleRingView(analysis: analysis)
                .padding(.top, 6)

            if let next = analysis.nextPredictedStart {
                let days = next.days(since: Date().startOfDay)
                if days > 0 {
                    Text("距下次经期还有 \(days) 天 · \(next.formatted(.dateTime.month().day()))")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                statChip(icon: "arrow.triangle.2.circlepath", title: "周期",
                         value: "\(analysis.avgCycleLength) 天", color: .follicularBlue)
                statChip(icon: "drop.fill", title: "经期",
                         value: "\(analysis.avgPeriodLength) 天", color: .periodRed)
                statChip(icon: "target", title: "可信度",
                         value: "\(Int(analysis.confidence * 100))%", color: .fertileTeal)
            }
        }
        .frame(maxWidth: .infinity)
        .card()
        .overlay(alignment: .topLeading) {
            Image(systemName: "sparkle")
                .font(.system(size: 15))
                .foregroundStyle(Color.ovulationViolet.opacity(0.55))
                .padding(18)
        }
        .overlay(alignment: .topTrailing) {
            Image(systemName: "camera.macro")
                .font(.system(size: 17))
                .foregroundStyle(Color.brandRose.opacity(0.5))
                .padding(16)
        }
        .overlay(alignment: .bottomLeading) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 13))
                .foregroundStyle(Color.fertileTeal.opacity(0.45))
                .padding(18)
        }
    }

    private func statChip(icon: String, title: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.system(.callout, design: .rounded).weight(.bold))
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .glassEffect(.regular.tint(color.opacity(0.10)),
                     in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    // MARK: - 今日贴士

    @ViewBuilder
    private var tipCard: some View {
        let phase = analysis.phase(on: Date().startOfDay)
        if phase != .none {
            HStack(spacing: 12) {
                Image(systemName: "heart.text.square.fill")
                    .font(.title3)
                    .foregroundStyle(phase.color)
                    .symbolEffect(.breathe)
                    .frame(width: 40, height: 40)
                    .background(phase.color.opacity(0.11),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("今日贴士 · \(phase.label)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(phase.color)
                    Text(tip(for: phase))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .card()
        }
    }

    private func tip(for phase: DayPhase) -> String {
        switch phase {
        case .period:          return "注意保暖，多喝温水，避免剧烈运动和生冷饮食"
        case .predictedPeriod: return "经期可能随时开始，记得随身携带卫生用品"
        case .fertile:         return "处于易孕窗口，如有备孕或避孕计划请多加注意"
        case .ovulation:       return "预测排卵日，受孕几率最高，可能伴有轻微腹痛"
        case .luteal:          return "黄体期易出现经前情绪波动，保持规律作息和好心情"
        case .follicular:      return "卵泡期精力较好，适合运动、学习和高效工作"
        case .none:            return ""
        }
    }

    // MARK: - 日历卡片

    private var calendarCard: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    withAnimation(.snappy) { monthOffset -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 32, height: 32)
                        .glassEffect(.regular.interactive(), in: Circle())
                }
                Spacer()
                Text(displayMonth.formatted(.dateTime.year().month()))
                    .font(.system(.headline, design: .rounded))
                    .onTapGesture { withAnimation(.snappy) { monthOffset = 0 } }
                Spacer()
                Button {
                    withAnimation(.snappy) { monthOffset += 1 }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 32, height: 32)
                        .glassEffect(.regular.interactive(), in: Circle())
                }
            }
            .tint(.primary)

            MonthGrid(month: displayMonth, analysis: analysis,
                      loggedDates: Set(logs.map { $0.date })) { day in
                selectedDate = day
            }
        }
        .card()
        .gesture(
            DragGesture(minimumDistance: 30).onEnded { g in
                withAnimation(.snappy) {
                    if g.translation.width < -30 { monthOffset += 1 }
                    if g.translation.width > 30 { monthOffset -= 1 }
                }
            })
    }
}

extension Date: @retroactive Identifiable {
    public var id: TimeInterval { timeIntervalSince1970 }
}

// MARK: - 月网格

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
        VStack(spacing: 8) {
            HStack {
                ForEach(weekdaySymbols, id: \.self) { s in
                    Text(s)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 8) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let day {
                        DayCell(date: day,
                                phase: analysis.phase(on: day),
                                hasLog: loggedDates.contains(day),
                                isToday: day == Date().startOfDay)
                            .onTapGesture { onTap(day) }
                    } else {
                        Color.clear.frame(height: 46)
                    }
                }
            }
        }
    }
}

// MARK: - 单日格：圆形胶囊

struct DayCell: View {
    let date: Date
    let phase: DayPhase
    let hasLog: Bool
    let isToday: Bool

    private var isFuture: Bool { date > Date().startOfDay }

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                switch phase {
                case .none:
                    Circle().fill(.clear)
                case .predictedPeriod:
                    Circle()
                        .fill(Color.predictedRose.opacity(0.16))
                    Circle()
                        .strokeBorder(Color.predictedRose,
                                      style: StrokeStyle(lineWidth: 1.2, dash: [2.5, 2.5]))
                case .period:
                    Circle()
                        .fill(LinearGradient(colors: [Color.periodRed, Color(hex: 0xC93A56)],
                                             startPoint: .top, endPoint: .bottom))
                case .ovulation:
                    Circle()
                        .fill(LinearGradient(colors: [Color.ovulationViolet, Color(hex: 0x7C4DDB)],
                                             startPoint: .top, endPoint: .bottom))
                default:
                    Circle().fill(phase.color.opacity(isFuture ? 0.13 : 0.20))
                }

                if isToday && phase == .none {
                    Circle().strokeBorder(Color.brandRose, lineWidth: 1.6)
                }

                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(.subheadline, design: .rounded)
                        .weight(isToday || phase == .period || phase == .ovulation ? .bold : .regular))
                    .foregroundStyle(
                        phase == .period || phase == .ovulation ? .white :
                        isToday ? Color.brandRose : .primary)
            }
            .frame(width: 38, height: 38)
            .overlay(alignment: .top) {
                if isToday && phase != .none {
                    Circle()
                        .fill(Color.brandRose)
                        .frame(width: 5, height: 5)
                        .offset(y: -8)
                }
            }

            Group {
                if phase == .ovulation {
                    Image(systemName: "star.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(Color.ovulationViolet)
                } else if hasLog {
                    Circle().fill(Color.brandRose.opacity(0.5))
                        .frame(width: 4, height: 4)
                } else {
                    Color.clear.frame(width: 4, height: 4)
                }
            }
            .frame(height: 8)
        }
        .frame(height: 46)
        .contentShape(Rectangle())
    }
}

// MARK: - 图例：横向胶囊

struct LegendView: View {
    private let phases: [DayPhase] = [.period, .predictedPeriod, .fertile, .ovulation, .luteal, .follicular]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(phases, id: \.label) { p in
                        HStack(spacing: 5) {
                            Image(systemName: p.symbol)
                                .font(.system(size: 10))
                            Text(p.label)
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(p.color)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .glassEffect(.regular.tint(p.color.opacity(0.12)), in: Capsule())
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }
}
