import SwiftUI

// MARK: - Design Tokens

enum DS {
    // 间距（4pt 网格）
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 20
    static let s6: CGFloat = 24

    // 圆角
    static let rCard: CGFloat = 30
    static let rChip: CGFloat = 16
    static let rButton: CGFloat = 20
}

extension Font {
    /// 超大展示数字
    static func dsDisplay(_ size: CGFloat = 56) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
    /// 页面大标题
    static let dsTitle = Font.system(.title2, design: .rounded).weight(.bold)
    /// 卡片小节标题
    static let dsSection = Font.footnote.weight(.semibold)
}

extension DayPhase {
    /// 每个阶段的品牌渐变
    var gradient: LinearGradient {
        LinearGradient(colors: [color, color.opacity(0.66)],
                       startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - 通用小节标题（眉标）

struct SectionHeader: View {
    let icon: String
    let title: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(title)
                .font(.dsSection)
                .tracking(0.5)
        }
        .foregroundStyle(tint)
    }
}

// MARK: - 首页问候头部

struct GreetingHeader: View {
    var onImport: () -> Void

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11: return "早上好"
        case 11..<13: return "中午好"
        case 13..<18: return "下午好"
        default: return "晚上好"
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: DS.s3) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color.brandRose, Color.ovulationViolet],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                Text("🌸")
                    .font(.title3)
            }
            .frame(width: 44, height: 44)
            .shadow(color: Color.brandRose.opacity(0.4), radius: 8, y: 3)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(greeting)，思雨 🎀")
                    .font(.dsTitle)
                Text(Date().formatted(.dateTime.month().day().weekday(.wide)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onImport) {
                Image(systemName: "square.and.arrow.down")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.brandRose)
                    .frame(width: 42, height: 42)
                    .glassEffect(.regular.interactive(), in: Circle())
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - 本周速览条

struct WeekStrip: View {
    let analysis: CycleAnalysis
    var onTap: (Date) -> Void

    private var weekDays: [Date] {
        let cal = Calendar.current
        let today = Date().startOfDay
        guard let interval = cal.dateInterval(of: .weekOfYear, for: today) else { return [] }
        return (0..<7).map { interval.start.adding(days: $0) }
    }

    var body: some View {
        HStack(spacing: DS.s2) {
            ForEach(weekDays, id: \.self) { day in
                let phase = analysis.phase(on: day)
                let isToday = day == Date().startOfDay
                Button {
                    onTap(day)
                } label: {
                    VStack(spacing: 5) {
                        Text(day.formatted(.dateTime.weekday(.narrow)))
                            .font(.caption2)
                            .foregroundStyle(isToday ? Color.brandRose : .secondary)
                        Text("\(Calendar.current.component(.day, from: day))")
                            .font(.system(.subheadline, design: .rounded)
                                .weight(isToday ? .bold : .medium))
                        Circle()
                            .fill(phase == .none ? Color.clear : phase.color)
                            .frame(width: 5, height: 5)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background {
                        if isToday {
                            RoundedRectangle(cornerRadius: DS.rChip, style: .continuous)
                                .fill(Color.brandRose.opacity(0.13))
                        }
                    }
                    .overlay {
                        if isToday {
                            RoundedRectangle(cornerRadius: DS.rChip, style: .continuous)
                                .strokeBorder(Color.brandRose.opacity(0.5), lineWidth: 1)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .card()
    }
}
