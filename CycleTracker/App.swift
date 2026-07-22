import SwiftUI
import SwiftData
import UserNotifications

@main
struct CycleTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [Cycle.self, DailyLog.self])
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            CalendarScreen()
                .tabItem { Label("日历", systemImage: "calendar") }
            StatsScreen()
                .tabItem { Label("统计", systemImage: "chart.line.uptrend.xyaxis") }
            SettingsScreen()
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
        .tint(.pink)
    }
}
