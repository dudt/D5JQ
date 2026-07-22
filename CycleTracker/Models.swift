import Foundation
import SwiftData

/// 一次经期记录：开始日期 + 结束日期（可空表示进行中）
@Model
final class Cycle {
    var startDate: Date
    var endDate: Date?

    init(startDate: Date, endDate: Date? = nil) {
        self.startDate = startDate.startOfDay
        self.endDate = endDate?.startOfDay
    }
}

/// 每日记录：流量、疼痛、心情、备注
@Model
final class DailyLog {
    var date: Date
    var flow: Int      // 0 无 1 少 2 中 3 多
    var pain: Int      // 0-3
    var mood: String
    var note: String
    var symptoms: String = ""   // 逗号分隔的症状标签

    init(date: Date, flow: Int = 0, pain: Int = 0, mood: String = "", note: String = "", symptoms: String = "") {
        self.date = date.startOfDay
        self.flow = flow
        self.pain = pain
        self.mood = mood
        self.note = note
        self.symptoms = symptoms
    }
}

extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }

    func adding(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }

    func days(since other: Date) -> Int {
        Calendar.current.dateComponents([.day], from: other.startOfDay, to: self.startOfDay).day ?? 0
    }
}
