import Foundation

/// 主 App 与小组件共享的周期摘要（通过 App Group UserDefaults 传递）
struct SharedCycleData: Codable {
    let nextStart: Date     // 下次经期预测开始日
    let cycleLen: Int
    let periodLen: Int
    let updated: Date

    static let sample = SharedCycleData(
        nextStart: Calendar.current.date(byAdding: .day, value: 9, to: Date()) ?? Date(),
        cycleLen: 28, periodLen: 5, updated: Date())

    /// 距下次经期天数（数据过期时自动滚动到未来的周期）
    func daysUntilNextPeriod(from date: Date) -> (days: Int, start: Date) {
        let cal = Calendar.current
        var start = cal.startOfDay(for: nextStart)
        let today = cal.startOfDay(for: date)
        while start < today {
            start = cal.date(byAdding: .day, value: cycleLen, to: start) ?? start
        }
        let days = cal.dateComponents([.day], from: today, to: start).day ?? 0
        return (days, start)
    }

    /// 0 经期 1 易孕 2 排卵日 3 黄体 4 卵泡
    func phaseIndex(on date: Date) -> Int {
        let cal = Calendar.current
        let d = cal.startOfDay(for: date)
        let anchor = cal.startOfDay(for: nextStart)
        var offset = (cal.dateComponents([.day], from: anchor, to: d).day ?? 0) % cycleLen
        if offset < 0 { offset += cycleLen }
        let ovu = max(cycleLen - 14, periodLen + 1)
        if offset < periodLen { return 0 }
        if offset == ovu { return 2 }
        if offset >= ovu - 5 && offset <= ovu + 1 { return 1 }
        if offset > ovu { return 3 }
        return 4
    }
}

enum SharedCycleStore {
    static let suiteName = "group.com.dq.cycletracker"
    static let key = "cycleData"

    /// App Group 是否真的可用（签名工具剥离 entitlements 时为 false）
    static var groupAvailable: Bool {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: suiteName) != nil
    }

    static func save(_ data: SharedCycleData) {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let encoded = try? JSONEncoder().encode(data) else { return }
        defaults.set(encoded, forKey: key)
    }

    static func load() -> SharedCycleData? {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let raw = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(SharedCycleData.self, from: raw)
    }
}
