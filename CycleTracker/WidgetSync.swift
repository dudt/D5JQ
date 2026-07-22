import Foundation
import WidgetKit

/// 把最新预测写入 App Group 并刷新小组件
enum WidgetSync {
    static func push(analysis: CycleAnalysis) {
        guard let next = analysis.nextPredictedStart else { return }
        SharedCycleStore.save(SharedCycleData(
            nextStart: next,
            cycleLen: analysis.avgCycleLength,
            periodLen: analysis.avgPeriodLength,
            updated: Date()))
        WidgetCenter.shared.reloadAllTimelines()
    }
}
