import SwiftUI
import SwiftData
import UserNotifications
import UniformTypeIdentifiers

struct SettingsScreen: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Cycle.startDate) private var cycles: [Cycle]
    @Query private var logs: [DailyLog]

    @AppStorage("reminderEnabled") private var reminderEnabled = false
    @AppStorage("reminderDaysBefore") private var reminderDaysBefore = 2

    @State private var showImporter = false
    @State private var exportDoc: BackupDocument? = nil
    @State private var message: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("经期提醒") {
                    Toggle(isOn: $reminderEnabled) {
                        settingLabel("开启提醒", icon: "bell.badge.fill", color: .brandRose)
                    }
                    .tint(.brandRose)
                    if reminderEnabled {
                        Stepper(value: $reminderDaysBefore, in: 0...7) {
                            settingLabel("提前 \(reminderDaysBefore) 天提醒", icon: "clock.fill", color: .lutealAmber)
                        }
                    }
                }
                Section("数据备份") {
                    Button {
                        exportDoc = BackupDocument(backup: makeBackup())
                    } label: {
                        settingLabel("导出数据（JSON）", icon: "square.and.arrow.up.fill", color: .follicularBlue)
                    }
                    Button {
                        showImporter = true
                    } label: {
                        settingLabel("从 JSON 恢复", icon: "square.and.arrow.down.fill", color: .fertileTeal)
                    }
                }
                Section("关于") {
                    LabeledContent {
                        Text("1.0.0")
                    } label: {
                        settingLabel("版本", icon: "app.badge.fill", color: .ovulationViolet)
                    }
                    HStack(spacing: 10) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(Color.fertileTeal)
                        Text("所有数据仅保存在本机，不上传任何服务器。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
                if let message {
                    Section { Text(message).font(.footnote).foregroundStyle(.secondary) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle("设置")
            .onChange(of: reminderEnabled) { _, on in
                if on { requestAndSchedule() } else { cancelReminders() }
            }
            .onChange(of: reminderDaysBefore) { _, _ in
                if reminderEnabled { requestAndSchedule() }
            }
            .fileExporter(isPresented: Binding(
                get: { exportDoc != nil },
                set: { if !$0 { exportDoc = nil } }),
                document: exportDoc,
                contentType: .json,
                defaultFilename: "CycleTracker-backup") { result in
                if case .success = result { message = "导出成功" }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                if case .success(let url) = result { restore(from: url) }
            }
        }
    }

    // MARK: - 行样式

    private func settingLabel(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.footnote)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(color, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(title)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - 备份

    private func makeBackup() -> Backup {
        Backup(
            cycles: cycles.map { .init(start: $0.startDate, end: $0.endDate) },
            logs: logs.map { .init(date: $0.date, flow: $0.flow, pain: $0.pain, mood: $0.mood, note: $0.note) })
    }

    private func restore(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let backup = try decoder.decode(Backup.self, from: data)
            let existingStarts = Set(cycles.map { $0.startDate })
            var added = 0
            for c in backup.cycles where !existingStarts.contains(c.start.startOfDay) {
                context.insert(Cycle(startDate: c.start, endDate: c.end))
                added += 1
            }
            let existingLogDates = Set(logs.map { $0.date })
            for l in backup.logs where !existingLogDates.contains(l.date.startOfDay) {
                context.insert(DailyLog(date: l.date, flow: l.flow, pain: l.pain, mood: l.mood, note: l.note))
            }
            try context.save()
            message = "恢复完成，新增 \(added) 条经期记录"
        } catch {
            message = "恢复失败：\(error.localizedDescription)"
        }
    }

    // MARK: - 通知

    private func requestAndSchedule() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            Task { @MainActor in scheduleReminders() }
        }
    }

    private func scheduleReminders() {
        cancelReminders()
        let analysis = CyclePredictor.analyze(cycles: cycles)
        guard let next = analysis.nextPredictedStart else { return }
        let fireDate = next.adding(days: -reminderDaysBefore)
        guard fireDate > Date() else { return }
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: fireDate)
        comps.hour = 9
        let content = UNMutableNotificationContent()
        content.title = "经期提醒"
        content.body = reminderDaysBefore == 0
            ? "预测今天可能是经期第一天，注意休息 💗"
            : "预计 \(reminderDaysBefore) 天后经期开始，提前做好准备 💗"
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: "period-reminder", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func cancelReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["period-reminder"])
    }
}

// MARK: - 备份文档

struct Backup: Codable {
    struct CycleDTO: Codable {
        let start: Date
        let end: Date?
    }
    struct LogDTO: Codable {
        let date: Date
        let flow: Int
        let pain: Int
        let mood: String
        let note: String
    }
    let cycles: [CycleDTO]
    let logs: [LogDTO]
}

struct BackupDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    var backup: Backup

    init(backup: Backup) { self.backup = backup }

    init(configuration: ReadConfiguration) throws {
        let data = configuration.file.regularFileContents ?? Data()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        backup = try decoder.decode(Backup.self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return FileWrapper(regularFileWithContents: try encoder.encode(backup))
    }
}
