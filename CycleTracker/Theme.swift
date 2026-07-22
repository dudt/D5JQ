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

// MARK: - 全局背景：缓慢流动的网格渐变

struct AppBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let x1 = Float(0.5 + 0.28 * sin(t * 0.13))
            let y1 = Float(0.42 + 0.10 * cos(t * 0.11))
            let x2 = Float(0.5 + 0.30 * cos(t * 0.09))
            MeshGradient(
                width: 3, height: 3,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.5], [x1, y1], [1, 0.5],
                    [0, 1], [x2, 1], [1, 1],
                ],
                colors: scheme == .dark
                    ? [
                        Color(hex: 0x27121A), Color(hex: 0x1B1120), Color(hex: 0x101018),
                        Color(hex: 0x2B1420), Color(hex: 0x321523), Color(hex: 0x151C22),
                        Color(hex: 0x120E14), Color(hex: 0x1E1220), Color(hex: 0x0E1418),
                    ]
                    : [
                        Color(hex: 0xFFE4EC), Color(hex: 0xF6E7FA), Color(hex: 0xE4F0FB),
                        Color(hex: 0xFBD9E4), Color(hex: 0xFCE8F0), Color(hex: 0xE0F2F0),
                        Color(hex: 0xFDEFF3), Color(hex: 0xF3E4F6), Color(hex: 0xE7F3F4),
                    ])
        }
        .ignoresSafeArea()
    }
}

// MARK: - 卡片：iOS 26 液态玻璃

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

extension View {
    func card() -> some View { modifier(CardStyle()) }
}

// MARK: - 周期环（签名元素）

struct CycleRingView: View {
    let analysis: CycleAnalysis
    @State private var appeared = false

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
                // 彩色光晕
                Circle()
                    .stroke(analysis.phase(on: today).color.opacity(0.35), lineWidth: 26)
                    .blur(radius: 22)
                    .padding(6)
                ring(segment: seg, total: total)
                todayMarker(dayIndex: dayIndex, total: total)
                center(seg: seg, dayIndex: dayIndex)
            }
            .frame(width: 236, height: 236)
            .scaleEffect(appeared ? 1 : 0.85)
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) {
                    appeared = true
                }
            }
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
                .stroke(phase.color.opacity(day < today ? 0.42 : 1),
                        style: StrokeStyle(lineWidth: 13, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }

    private func todayMarker(dayIndex: Int, total: Int) -> some View {
        let angle = (Double(dayIndex) + 0.5) / Double(total) * 360 - 90
        let color = analysis.phase(on: today).color
        return Circle()
            .fill(color)
            .frame(width: 21, height: 21)
            .overlay(Circle().strokeBorder(.white, lineWidth: 3))
            .shadow(color: color.opacity(0.6), radius: 6)
            .offset(x: 118 * cos(angle * .pi / 180),
                    y: 118 * sin(angle * .pi / 180))
    }

    private func center(seg: CycleSegment, dayIndex: Int) -> some View {
        let phase = analysis.phase(on: today)
        return VStack(spacing: 4) {
            Text("周期第")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("\(dayIndex + 1)")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [phase.color, phase.color.opacity(0.65)],
                                   startPoint: .top, endPoint: .bottom))
                .contentTransition(.numericText())
            Text("天")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Label(phase.label, systemImage: phase.symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(phase.color)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .glassEffect(.regular.tint(phase.color.opacity(0.14)), in: Capsule())
        }
    }

    private var emptyRing: some View {
        ZStack {
            Circle()
                .stroke(Color.brandRose.opacity(0.2),
                        style: StrokeStyle(lineWidth: 13, dash: [1, 7]))
            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.title)
                    .foregroundStyle(Color.brandRose)
                    .symbolEffect(.breathe)
                Text("记录第一次经期\n开启智能预测")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 236, height: 236)
    }
}
