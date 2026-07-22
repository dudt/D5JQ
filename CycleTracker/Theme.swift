import SwiftUI

// MARK: - 色板

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255)
    }

    static let periodRed      = Color(hex: 0xE5484D)
    static let predictedRose  = Color(hex: 0xF2A0B5)
    static let fertileTeal    = Color(hex: 0x14B8A6)
    static let ovulationViolet = Color(hex: 0x8B5CF6)
    static let lutealAmber    = Color(hex: 0xE8A33D)
    static let follicularBlue = Color(hex: 0x60A5FA)
    static let brandRose      = Color(hex: 0xE0526E)
}

// MARK: - 全局背景

struct AppBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            (scheme == .dark ? Color.black : Color(hex: 0xFBF6F7))
                .ignoresSafeArea()
            LinearGradient(
                colors: scheme == .dark
                    ? [Color.brandRose.opacity(0.12), .clear]
                    : [Color.brandRose.opacity(0.10), .clear],
                startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
        }
    }
}

// MARK: - 卡片样式

struct CardStyle: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(scheme == .dark ? Color(hex: 0x1C1A1D) : .white)
                    .shadow(color: Color.brandRose.opacity(scheme == .dark ? 0 : 0.10),
                            radius: 16, y: 6))
    }
}

extension View {
    func card() -> some View { modifier(CardStyle()) }
}

// MARK: - 周期环（签名元素）

struct CycleRingView: View {
    let analysis: CycleAnalysis

    private var today: Date { Date().startOfDay }

    /// 包含今天的周期段
    private var segment: CycleSegment? {
        analysis.segments.first { today >= $0.start && today < $0.nextStart }
    }

    var body: some View {
        if let seg = segment {
            let total = max(seg.nextStart.days(since: seg.start), 1)
            let dayIndex = today.days(since: seg.start)
            ZStack {
                ring(segment: seg, total: total)
                todayMarker(dayIndex: dayIndex, total: total)
                center(seg: seg, dayIndex: dayIndex)
            }
            .frame(width: 232, height: 232)
        } else {
            emptyRing
        }
    }

    private func ring(segment seg: CycleSegment, total: Int) -> some View {
        ForEach(0..<total, id: \.self) { i in
            let day = seg.start.adding(days: i)
            let phase = analysis.phase(on: day)
            let f0 = Double(i) / Double(total)
            let f1 = Double(i + 1) / Double(total)
            let gap = min(0.15 / Double(total), 0.004)
            Circle()
                .trim(from: f0 + gap, to: f1 - gap)
                .stroke(phase.color.opacity(day < today ? 0.45 : 1),
                        style: StrokeStyle(lineWidth: 13, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }

    private func todayMarker(dayIndex: Int, total: Int) -> some View {
        let angle = (Double(dayIndex) + 0.5) / Double(total) * 360 - 90
        return Circle()
            .fill(analysis.phase(on: today).color)
            .frame(width: 21, height: 21)
            .overlay(Circle().strokeBorder(.white, lineWidth: 3))
            .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
            .offset(x: 116 * cos(angle * .pi / 180),
                    y: 116 * sin(angle * .pi / 180))
    }

    private func center(seg: CycleSegment, dayIndex: Int) -> some View {
        let phase = analysis.phase(on: today)
        return VStack(spacing: 4) {
            Text("周期第")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("\(dayIndex + 1)")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(phase.color)
                .contentTransition(.numericText())
            Text("天")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Label(phase.label, systemImage: phase.symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(phase.color)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(phase.color.opacity(0.13), in: Capsule())
        }
    }

    private var emptyRing: some View {
        ZStack {
            Circle()
                .stroke(Color.brandRose.opacity(0.15),
                        style: StrokeStyle(lineWidth: 13, dash: [1, 7], dashPhase: 0))
            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.title)
                    .foregroundStyle(Color.brandRose)
                Text("记录第一次经期\n开启智能预测")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 232, height: 232)
    }
}
