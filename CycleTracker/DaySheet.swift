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
    @State private var symptoms: Set<String> = []

    private let moods = ["😊", "😐", "😢", "😡", "😴", "🤕"]
    private let flowLabels = ["无", "少", "中", "多"]
    private let painLabels = ["无", "轻微", "中度", "严重"]
    private let symptomOptions = ["腹痛", "腰酸", "头痛", "乳房胀痛", "痤疮", "疲劳", "失眠", "恶心", "食欲增加", "情绪低落", "腹泻", "水肿"]

    private var isInRecordedPeriod: Bool {
        cycles.contains { c in
            guard let end = c.endDate else { return date == c.startDate }
            return date >= c.startDate && date <= end
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    periodSection
                    selectorCard(title: "流量", icon: "drop.fill", tint: .periodRed) {
                        levelPicker(selection: $flow, labels: flowLabels,
                                    symbol: "drop.fill", tint: .periodRed)
                    }
                    selectorCard(title: "疼痛", icon: "bolt.fill", tint: .lutealAmber) {
                        levelPicker(selection: $pain, labels: painLabels,
                                    symbol: "bolt.fill", tint: .lutealAmber)
                    }
                    selectorCard(title: "心情", icon: "face.smiling", tint: .fertileTeal) {
                        HStack(spacing: 8) {
                            ForEach(moods, id: \.self) { m in
                                Button {
                                    withAnimation(.snappy) { mood = (mood == m) ? "" : m }
                                } label: {
                                    Text(m)
                                        .font(.title3)
                                        .frame(width: 44, height: 44)
                                        .background(
                                            Circle().fill(mood == m
                                                ? Color.fertileTeal.opacity(0.18)
                                                : Color.gray.opacity(0.07)))
                                        .overlay {
                                            if mood == m {
                                                Circle().strokeBorder(Color.fertileTeal, lineWidth: 1.5)
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    selectorCard(title: "症状", icon: "stethoscope", tint: .ovulationViolet) {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                            ForEach(symptomOptions, id: \.self) { s in
                                let selected = symptoms.contains(s)
                                Button {
                                    withAnimation(.snappy) {
                                        if selected { symptoms.remove(s) } else { symptoms.insert(s) }
                                    }
                                } label: {
                                    Text(s)
                                        .font(.caption.weight(selected ? .semibold : .regular))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 9)
                                        .background(
                                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                                .fill(selected ? Color.ovulationViolet.opacity(0.14) : Color.gray.opacity(0.06)))
                                        .overlay {
                                            if selected {
                                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                                    .strokeBorder(Color.ovulationViolet.opacity(0.5), lineWidth: 1.2)
                                            }
                                        }
                                        .foregroundStyle(selected ? Color.ovulationViolet : .secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    selectorCard(title: "备注", icon: "square.and.pencil", tint: .follicularBlue) {
                        TextField("症状、备注…", text: $note, axis: .vertical)
                            .lineLimit(2...5)
                            .padding(10)
                            .background(.gray.opacity(0.07),
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding()
            }
            .background(AppBackground())
            .navigationTitle(date.formatted(.dateTime.month().day().weekday()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveLog()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .tint(.brandRose)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .onAppear(perform: loadLog)
        }
    }

    // MARK: - 经期标记区

    private var periodSection: some View {
        VStack(spacing: 10) {
            if isInRecordedPeriod {
                actionButton(title: "取消这天的经期标记", icon: "drop.slash",
                             style: .outline(.periodRed)) {
                    removePeriodDay()
                    dismiss()
                }
            } else {
                actionButton(title: "经期从这天开始", icon: "drop.fill",
                             style: .filled(.periodRed)) {
                    context.insert(Cycle(startDate: date))
                    try? context.save()
                    dismiss()
                }
                if let ongoing = cycles.last, ongoing.endDate == nil,
                   date > ongoing.startDate, date.days(since: ongoing.startDate) <= 14 {
                    actionButton(title: "经期到这天结束", icon: "drop.circle",
                                 style: .outline(.periodRed)) {
                        ongoing.endDate = date
                        try? context.save()
                        dismiss()
                    }
                }
            }
        }
    }

    private enum ButtonStyleKind {
        case filled(Color)
        case outline(Color)
    }

    private func actionButton(title: String, icon: String,
                              style: ButtonStyleKind,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.callout.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background {
                    switch style {
                    case .filled(let c):
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(LinearGradient(colors: [c, c.opacity(0.82)],
                                                 startPoint: .top, endPoint: .bottom))
                    case .outline(let c):
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(c.opacity(0.09))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(c.opacity(0.4), lineWidth: 1))
                    }
                }
                .foregroundStyle({
                    if case .filled = style { return Color.white }
                    if case .outline(let c) = style { return c }
                    return Color.primary
                }())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 通用卡片与等级选择器

    private func selectorCard<Content: View>(title: String, icon: String, tint: Color,
                                             @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(tint)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func levelPicker(selection: Binding<Int>, labels: [String],
                             symbol: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<labels.count, id: \.self) { level in
                let selected = selection.wrappedValue == level
                Button {
                    withAnimation(.snappy) { selection.wrappedValue = level }
                } label: {
                    VStack(spacing: 5) {
                        if level == 0 {
                            Image(systemName: "minus")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(selected ? tint : .secondary)
                                .frame(height: 16)
                        } else {
                            HStack(spacing: 1) {
                                ForEach(0..<level, id: \.self) { _ in
                                    Image(systemName: symbol)
                                        .font(.system(size: 9))
                                        .foregroundStyle(selected ? tint : Color.secondary.opacity(0.55))
                                }
                            }
                            .frame(height: 16)
                        }
                        Text(labels[level])
                            .font(.caption2.weight(selected ? .semibold : .regular))
                            .foregroundStyle(selected ? tint : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(selected ? tint.opacity(0.13) : Color.gray.opacity(0.06)))
                    .overlay {
                        if selected {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(tint.opacity(0.5), lineWidth: 1.2)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 数据

    private func loadLog() {
        if let log = logs.first(where: { $0.date == date.startOfDay }) {
            flow = log.flow; pain = log.pain; mood = log.mood; note = log.note
            symptoms = Set(log.symptoms.split(separator: ",").map(String.init))
        }
    }

    private func saveLog() {
        let joined = symptoms.sorted().joined(separator: ",")
        if let log = logs.first(where: { $0.date == date.startOfDay }) {
            log.flow = flow; log.pain = pain; log.mood = mood; log.note = note
            log.symptoms = joined
        } else if flow != 0 || pain != 0 || !mood.isEmpty || !note.isEmpty || !symptoms.isEmpty {
            context.insert(DailyLog(date: date, flow: flow, pain: pain, mood: mood, note: note, symptoms: joined))
        }
        try? context.save()
    }

    private func removePeriodDay() {
        guard let c = cycles.first(where: { cyc in
            guard let end = cyc.endDate else { return date == cyc.startDate }
            return date >= cyc.startDate && date <= end
        }) else { return }

        if date == c.startDate && (c.endDate == nil || c.endDate == c.startDate) {
            context.delete(c)                         // 单日周期 → 整条删除
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
            ScrollView {
                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("添加一次历史经期", systemImage: "plus.circle.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.brandRose)
                        DatePicker("开始日期", selection: $start, displayedComponents: .date)
                        DatePicker("结束日期", selection: $end, in: start..., displayedComponents: .date)
                        if end.days(since: start) > 14 {
                            Text("经期长度不能超过 15 天")
                                .font(.caption)
                                .foregroundStyle(Color.periodRed)
                        }
                        Button {
                            withAnimation(.snappy) {
                                context.insert(Cycle(startDate: start, endDate: end))
                                try? context.save()
                            }
                        } label: {
                            Label("添加这条记录", systemImage: "plus")
                                .font(.callout.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(LinearGradient(colors: [Color.brandRose, Color.periodRed],
                                                             startPoint: .leading, endPoint: .trailing)))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .disabled(end < start || end.days(since: start) > 14)
                        .opacity(end < start || end.days(since: start) > 14 ? 0.4 : 1)
                    }
                    .card()

                    VStack(alignment: .leading, spacing: 4) {
                        Label("已有记录（\(cycles.count) 条）", systemImage: "clock.arrow.circlepath")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 6)
                        if cycles.isEmpty {
                            Text("暂无记录，添加最近 3~6 次经期，预测会立刻可用")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                                .padding(.vertical, 10)
                        }
                        ForEach(Array(cycles.reversed().enumerated()), id: \.element.persistentModelID) { i, c in
                            HStack(spacing: 10) {
                                Image(systemName: "drop.fill")
                                    .font(.caption)
                                    .foregroundStyle(Color.periodRed)
                                    .frame(width: 28, height: 28)
                                    .background(Color.periodRed.opacity(0.1), in: Circle())
                                Text(rangeText(c))
                                    .font(.subheadline)
                                Spacer()
                                Button {
                                    withAnimation(.snappy) {
                                        context.delete(c)
                                        try? context.save()
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 7)
                            if i < cycles.count - 1 {
                                Divider()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
                }
                .padding()
            }
            .background(AppBackground())
            .navigationTitle("导入历史经期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .fontWeight(.semibold)
                        .tint(.brandRose)
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
