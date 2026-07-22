import SwiftUI
import SwiftData

/// 点击某天弹出：经期标记 + 每日记录
struct DaySheet: View {
    let date: Date
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Cycle.startDate) private var cycles: [Cycle]
    @Query private var logs: [DailyLog]

    @State private var flow = 0
    @State private var pain = 0
    @State private var mood = ""
    @State private var note = ""

    private let moods = ["😊", "😐", "😢", "😡", "😴", "🤕"]

    private var isInRecordedPeriod: Bool {
        cycles.contains { c in
            guard let end = c.endDate else { return date == c.startDate }
            return date >= c.startDate && date <= end
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("经期标记") {
                    if isInRecordedPeriod {
                        Button(role: .destructive) {
                            removePeriodDay()
                            dismiss()
                        } label: {
                            Label("取消这天的经期标记", systemImage: "drop.slash")
                        }
                    } else {
                        Button {
                            markPeriodStart()
                            dismiss()
                        } label: {
                            Label("经期从这天开始", systemImage: "drop.fill")
                        }
                        if let ongoing = cycles.last, ongoing.endDate == nil,
                           date > ongoing.startDate, date.days(since: ongoing.startDate) <= 14 {
                            Button {
                                ongoing.endDate = date
                                try? context.save()
                                dismiss()
                            } label: {
                                Label("经期到这天结束", systemImage: "drop.circle")
                            }
                        }
                    }
                }
                Section("流量") {
                    Picker("流量", selection: $flow) {
                        Text("无").tag(0); Text("少").tag(1); Text("中").tag(2); Text("多").tag(3)
                    }
                    .pickerStyle(.segmented)
                }
                Section("疼痛程度") {
                    Picker("疼痛", selection: $pain) {
                        Text("无").tag(0); Text("轻微").tag(1); Text("中度").tag(2); Text("严重").tag(3)
                    }
                    .pickerStyle(.segmented)
                }
                Section("心情") {
                    HStack {
                        ForEach(moods, id: \.self) { m in
                            Button {
                                mood = (mood == m) ? "" : m
                            } label: {
                                Text(m).font(.title2)
                                    .padding(6)
                                    .background(mood == m ? Color.pink.opacity(0.2) : .clear,
                                                in: Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Section("备注") {
                    TextField("症状、备注…", text: $note, axis: .vertical)
                }
            }
            .navigationTitle(date.formatted(.dateTime.month().day().weekday()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveLog()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .onAppear(perform: loadLog)
        }
    }

    private func loadLog() {
        if let log = logs.first(where: { $0.date == date.startOfDay }) {
            flow = log.flow; pain = log.pain; mood = log.mood; note = log.note
        }
    }

    private func saveLog() {
        if let log = logs.first(where: { $0.date == date.startOfDay }) {
            log.flow = flow; log.pain = pain; log.mood = mood; log.note = note
        } else if flow != 0 || pain != 0 || !mood.isEmpty || !note.isEmpty {
            context.insert(DailyLog(date: date, flow: flow, pain: pain, mood: mood, note: note))
        }
        try? context.save()
    }

    private func markPeriodStart() {
        // 若与已有周期距离 < 15 天，视为误操作仍允许，由预测器自动剔除异常
        context.insert(Cycle(startDate: date))
        try? context.save()
    }

    private func removePeriodDay() {
        guard let c = cycles.first(where: { cyc in
            guard let end = cyc.endDate else { return date == cyc.startDate }
            return date >= cyc.startDate && date <= end
        }) else { return }

        if date == c.startDate && (c.endDate == nil || c.endDate == c.startDate) {
            context.delete(c)                       // 单日周期 → 整条删除
        } else if date == c.startDate {
            c.startDate = c.startDate.adding(days: 1) // 去掉第一天
        } else if date == c.endDate {
            c.endDate = date.adding(days: -1)         // 去掉最后一天
        } else {
            c.endDate = date.adding(days: -1)         // 从中间截断
        }
        try? context.save()
    }
}

/// 批量导入历史经期：选择"几号到几号"逐条添加
struct ImportHistoryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Cycle.startDate) private var cycles: [Cycle]

    @State private var start = Date().adding(days: -5)
    @State private var end = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("添加一次历史经期") {
                    DatePicker("开始日期", selection: $start, displayedComponents: .date)
                    DatePicker("结束日期", selection: $end, in: start..., displayedComponents: .date)
                    Button {
                        context.insert(Cycle(startDate: start, endDate: end))
                        try? context.save()
                    } label: {
                        Label("添加这条记录", systemImage: "plus.circle.fill")
                    }
                    .disabled(end < start || end.days(since: start) > 14)
                    if end.days(since: start) > 14 {
                        Text("经期长度不能超过 15 天").font(.caption).foregroundStyle(.red)
                    }
                }
                Section("已有记录（\(cycles.count) 条）") {
                    if cycles.isEmpty {
                        Text("暂无记录").foregroundStyle(.secondary)
                    }
                    ForEach(cycles.reversed()) { c in
                        HStack {
                            Image(systemName: "drop.fill").foregroundStyle(.red)
                            Text(rangeText(c))
                            Spacer()
                            Button(role: .destructive) {
                                context.delete(c)
                                try? context.save()
                            } label: {
                                Image(systemName: "trash").font(.caption)
                            }
                        }
                    }
                }
            }
            .navigationTitle("导入历史经期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func rangeText(_ c: Cycle) -> String {
        let f = Date.FormatStyle.dateTime.year().month().day()
        if let end = c.endDate {
            return "\(c.startDate.formatted(f)) ~ \(end.formatted(.dateTime.month().day()))"
        }
        return "\(c.startDate.formatted(f)) ~ 进行中"
    }
}
