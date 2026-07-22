import WidgetKit
import SwiftUI

// 小组件独立色板（不依赖主 App 的 Theme）
private extension Color {
    init(whex: UInt32) {
        self.init(.sRGB,
                  red: Double((whex >> 16) & 0xFF) / 255,
                  green: Double((whex >> 8) & 0xFF) / 255,
                  blue: Double(whex & 0xFF) / 255)
    }
    static let wPeriod = Color(whex: 0xF43F5E)
    static let wFertile = Color(whex: 0x00C9A7)
    static let wOvulation = Color(whex: 0x9B5CFF)
    static let wLuteal = Color(whex: 0xFFA726)
    static let wFollicular = Color(whex: 0x38A8FF)
    static let wRose = Color(whex: 0xFF4F7B)
}

private func phaseColor(_ index: Int) -> Color {
    switch index {
    case 0: return .wPeriod
    case 1: return .wFertile
    case 2: return .wOvulation
    case 3: return .wLuteal
    default: return .wFollicular
    }
}

struct CycleEntry: TimelineEntry {
    let date: Date
    let data: SharedCycleData?
}

struct CycleProvider: TimelineProvider {
    func placeholder(in context: Context) -> CycleEntry {
        CycleEntry(date: Date(), data: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (CycleEntry) -> Void) {
        completion(CycleEntry(date: Date(), data: SharedCycleStore.load() ?? .sample))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CycleEntry>) -> Void) {
        let data = SharedCycleStore.load()
        let cal = Calendar.current
        var entries: [CycleEntry] = [CycleEntry(date: Date(), data: data)]
        // 之后 7 天，每天零点刷新一条
        for i in 1...7 {
            if let midnight = cal.date(byAdding: .day, value: i, to: cal.startOfDay(for: Date())) {
                entries.append(CycleEntry(date: midnight, data: data))
            }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - 小尺寸：倒计时

struct SmallWidgetView: View {
    let entry: CycleEntry

    var body: some View {
        if let data = entry.data {
            let result = data.daysUntilNextPeriod(from: entry.date)
            let phase = data.phaseIndex(on: entry.date)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: "drop.fill")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                    Text("下次经期")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.9))
                }
                Spacer()
                if result.days == 0 {
                    Text("今天")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("注意休息 💗")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.85))
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(result.days)")
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                        Text("天后")
                            .font(.footnote.weight(.medium))
                    }
                    .foregroundStyle(.white)
                    Text(result.start.formatted(.dateTime.month().day().weekday()))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .containerBackground(for: .widget) {
                LinearGradient(colors: [phaseColor(phase), phaseColor(phase).opacity(0.7)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        } else {
            placeholderView
        }
    }
}

// MARK: - 中尺寸：倒计时 + 未来 7 天阶段条

struct MediumWidgetView: View {
    let entry: CycleEntry

    var body: some View {
        if let data = entry.data {
            let result = data.daysUntilNextPeriod(from: entry.date)
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("下次经期")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    if result.days == 0 {
                        Text("今天")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.wRose)
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text("\(result.days)")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.wRose)
                            Text("天后")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(result.start.formatted(.dateTime.month().day().weekday()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 7) {
                    Text("未来 7 天")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    HStack(spacing: 5) {
                        ForEach(0..<7, id: \.self) { i in
                            let day = Calendar.current.date(byAdding: .day, value: i, to: entry.date) ?? entry.date
                            let p = data.phaseIndex(on: day)
                            VStack(spacing: 3) {
                                Text(day.formatted(.dateTime.weekday(.narrow)))
                                    .font(.system(size: 8))
                                    .foregroundStyle(.tertiary)
                                Circle()
                                    .fill(phaseColor(p).opacity(i == 0 ? 1 : 0.75))
                                    .frame(width: 13, height: 13)
                                    .overlay {
                                        if i == 0 {
                                            Circle().strokeBorder(.white, lineWidth: 1.5)
                                        }
                                    }
                            }
                        }
                    }
                }
            }
            .containerBackground(for: .widget) {
                LinearGradient(colors: [Color(whex: 0xFFF0F4), Color(whex: 0xFDE4EF)],
                               startPoint: .top, endPoint: .bottom)
            }
        } else {
            placeholderView
        }
    }
}

private var placeholderView: some View {
    VStack(spacing: 6) {
        Image(systemName: "drop.fill")
            .foregroundStyle(Color.wRose)
        Text("打开 App 记录经期\n即可显示预测")
            .font(.caption2)
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
    }
    .containerBackground(for: .widget) { Color(whex: 0xFFF0F4) }
}

// MARK: - Widget 声明

struct CycleCountdownWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CycleCountdownWidget", provider: CycleProvider()) { entry in
            SmallWidgetView(entry: entry)
        }
        .configurationDisplayName("经期倒计时")
        .description("显示距下次经期的天数和日期")
        .supportedFamilies([.systemSmall])
    }
}

struct CycleWeekWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CycleWeekWidget", provider: CycleProvider()) { entry in
            MediumWidgetView(entry: entry)
        }
        .configurationDisplayName("经期一周预览")
        .description("倒计时 + 未来 7 天周期阶段")
        .supportedFamilies([.systemMedium])
    }
}

@main
struct CycleWidgetBundle: WidgetBundle {
    var body: some Widget {
        CycleCountdownWidget()
        CycleWeekWidget()
    }
}
