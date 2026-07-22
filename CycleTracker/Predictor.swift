import Foundation
import SwiftUI

enum DayPhase {
    case period          // 月经期（已记录）
    case predictedPeriod // 预测经期
    case fertile         // 排卵期（易孕窗口）
    case ovulation       // 排卵日
    case luteal          // 黄体期
    case follicular      // 卵泡期
    case none

    var color: Color {
        switch self {
        case .period:          return .red
        case .predictedPeriod: return .pink
        case .fertile:         return .green
        case .ovulation:       return .purple
        case .luteal:          return .orange
        case .follicular:      return .blue
        case .none:            return .clear
        }
    }

    var label: String {
        switch self {
        case .period:          return "月经期"
        case .predictedPeriod: return "预测经期"
        case .fertile:         return "排卵期"
        case .ovulation:       return "排卵日"
        case .luteal:          return "黄体期"
        case .follicular:      return "卵泡期"
        case .none:            return ""
        }
    }

    var symbol: String {
        switch self {
        case .period:          return "drop.fill"
        case .predictedPeriod: return "drop"
        case .fertile:         return "leaf.fill"
        case .ovulation:       return "star.fill"
        case .luteal:          return "moon.fill"
        case .follicular:      return "sparkles"
        case .none:            return ""
        }
    }
}

/// 一个周期段：从某次经期开始到下次经期开始
struct CycleSegment {
    let start: Date
    let periodEnd: Date      // 经期最后一天（含）
    let nextStart: Date      // 下一周期开始（不含）
    let ovulationDay: Date
    let isPredictedPeriod: Bool
}

struct CycleAnalysis {
    let avgCycleLength: Int
    let avgPeriodLength: Int
    let cycleLengths: [Int]          // 历史各周期长度（按时间顺序）
    let confidence: Double           // 0-1 预测可信度
    let segments: [CycleSegment]
    let lastRecordedStart: Date?
    let nextPredictedStart: Date?

    func phase(on date: Date) -> DayPhase {
        let d = date.startOfDay
        for seg in segments {
            guard d >= seg.start && d < seg.nextStart else { continue }
            if d <= seg.periodEnd {
                return seg.isPredictedPeriod ? .predictedPeriod : .period
            }
            if d == seg.ovulationDay { return .ovulation }
            // 易孕窗口：排卵日前 5 天到后 1 天
            if d >= seg.ovulationDay.adding(days: -5) && d <= seg.ovulationDay.adding(days: 1) {
                return .fertile
            }
            if d > seg.ovulationDay { return .luteal }
            return .follicular
        }
        return .none
    }
}

enum CyclePredictor {
    static let defaultCycleLength = 28
    static let defaultPeriodLength = 5
    static let lutealLength = 14
    static let predictAheadCycles = 6

    /// 核心：越用越准。近期周期权重更高，异常值自动剔除。
    static func analyze(cycles rawCycles: [Cycle], today: Date = Date()) -> CycleAnalysis {
        let cycles = rawCycles.sorted { $0.startDate < $1.startDate }

        // 各周期长度（相邻两次开始日的间隔）
        var lengths: [Int] = []
        for i in 1..<max(cycles.count, 1) {
            let len = cycles[i].startDate.days(since: cycles[i - 1].startDate)
            lengths.append(len)
        }

        // 剔除异常：仅保留 15~60 天且与中位数偏差 ≤ 10 天的周期
        let plausible = lengths.filter { $0 >= 15 && $0 <= 60 }
        var valid = plausible
        if plausible.count >= 3 {
            let sorted = plausible.sorted()
            let median = sorted[sorted.count / 2]
            valid = plausible.filter { abs($0 - median) <= 10 }
        }

        // 加权平均：第 i 个（越新越大）权重为 i+1
        let avgCycle: Int
        if valid.isEmpty {
            avgCycle = defaultCycleLength
        } else {
            var weightedSum = 0.0, weightTotal = 0.0
            // 保持时间顺序对应权重（valid 来自 lengths 的过滤，顺序未变）
            for (i, len) in valid.enumerated() {
                let w = Double(i + 1)
                weightedSum += Double(len) * w
                weightTotal += w
            }
            avgCycle = Int((weightedSum / weightTotal).rounded())
        }

        // 经期长度：取有结束日期的记录的加权平均
        let durations: [Int] = cycles.compactMap { c in
            guard let end = c.endDate else { return nil }
            let d = end.days(since: c.startDate) + 1
            return (1...14).contains(d) ? d : nil
        }
        let avgPeriod: Int
        if durations.isEmpty {
            avgPeriod = defaultPeriodLength
        } else {
            var ws = 0.0, wt = 0.0
            for (i, d) in durations.enumerated() {
                let w = Double(i + 1)
                ws += Double(d) * w
                wt += w
            }
            avgPeriod = Int((ws / wt).rounded())
        }

        // 可信度：样本量 + 稳定性（标准差越小越可信）
        var confidence = 0.0
        if !valid.isEmpty {
            let sampleScore = min(Double(valid.count) / 6.0, 1.0)
            let mean = Double(valid.reduce(0, +)) / Double(valid.count)
            let variance = valid.reduce(0.0) { $0 + pow(Double($1) - mean, 2) } / Double(valid.count)
            let sd = sqrt(variance)
            let stabilityScore = max(0, 1.0 - sd / 7.0)
            confidence = sampleScore * 0.5 + stabilityScore * 0.5
        }

        // 构建周期段：历史段（相邻记录之间）+ 未来预测段
        var segments: [CycleSegment] = []
        for i in 0..<cycles.count {
            let c = cycles[i]
            let nextStart: Date = i + 1 < cycles.count
                ? cycles[i + 1].startDate
                : c.startDate.adding(days: avgCycle)
            let periodEnd = c.endDate ?? c.startDate.adding(days: avgPeriod - 1)
            let cycleLen = nextStart.days(since: c.startDate)
            // 排卵日 = 下次经期前 14 天；周期过短时至少放在经期结束后
            var ov = nextStart.adding(days: -lutealLength)
            if ov <= periodEnd { ov = periodEnd.adding(days: max(1, (cycleLen - avgPeriod) / 2)) }
            segments.append(CycleSegment(
                start: c.startDate, periodEnd: periodEnd,
                nextStart: nextStart, ovulationDay: ov, isPredictedPeriod: false))
        }

        // 未来预测段
        var nextPredicted: Date? = nil
        if let last = cycles.last {
            var start = last.startDate.adding(days: avgCycle)
            nextPredicted = start
            for _ in 0..<predictAheadCycles {
                let nextStart = start.adding(days: avgCycle)
                var ov = nextStart.adding(days: -lutealLength)
                let periodEnd = start.adding(days: avgPeriod - 1)
                if ov <= periodEnd { ov = periodEnd.adding(days: 1) }
                segments.append(CycleSegment(
                    start: start, periodEnd: periodEnd,
                    nextStart: nextStart, ovulationDay: ov, isPredictedPeriod: true))
                start = nextStart
            }
        }

        return CycleAnalysis(
            avgCycleLength: avgCycle,
            avgPeriodLength: avgPeriod,
            cycleLengths: lengths,
            confidence: confidence,
            segments: segments,
            lastRecordedStart: cycles.last?.startDate,
            nextPredictedStart: nextPredicted)
    }
}
