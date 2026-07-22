import SwiftUI
import SwiftData
import LocalAuthentication

@main
struct CycleTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            LockGate {
                RootView()
            }
            .environment(\.locale, Locale(identifier: "zh_CN"))
        }
        .modelContainer(for: [Cycle.self, DailyLog.self])
    }
}

struct RootView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded = false

    var body: some View {
        TabView {
            CalendarScreen()
                .tabItem { Label("日历", systemImage: "calendar") }
            StatsScreen()
                .tabItem { Label("统计", systemImage: "chart.line.uptrend.xyaxis") }
            SettingsScreen()
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(.brandRose)
        .sheet(isPresented: Binding(get: { !hasOnboarded }, set: { hasOnboarded = !$0 })) {
            OnboardingView()
                .presentationCornerRadius(28)
                .interactiveDismissDisabled()
        }
    }
}

// MARK: - 应用锁（Face ID / 密码）

struct LockGate<Content: View>: View {
    @ViewBuilder let content: Content
    @AppStorage("appLockEnabled") private var lockEnabled = false
    @State private var unlocked = false
    @State private var failed = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        if !lockEnabled || unlocked {
            content
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background { unlocked = false }
                }
        } else {
            ZStack {
                AppBackground()
                VStack(spacing: 20) {
                    Image(systemName: "lock.heart.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(Color.brandRose)
                    Text("思雨の经期助手已锁定")
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                    if failed {
                        Text("验证未通过，请重试")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        authenticate()
                    } label: {
                        Label("解锁", systemImage: "faceid")
                            .font(.callout.weight(.semibold))
                            .padding(.horizontal, 32)
                            .padding(.vertical, 13)
                            .background(Color.brandRose, in: Capsule())
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
            .onAppear(perform: authenticate)
        }
    }

    private func authenticate() {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            unlocked = true  // 设备没有任何锁屏方式时不阻塞
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthentication,
                               localizedReason: "解锁查看经期数据") { success, _ in
            Task { @MainActor in
                if success { unlocked = true; failed = false } else { failed = true }
            }
        }
    }
}

// MARK: - 首次启动引导

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0

    private let pages: [(icon: String, color: Color, title: String, text: String)] = [
        ("circle.dotted.circle", .brandRose, "记录你的周期",
         "在日历上点任意一天，标记经期开始与结束。\n流量、疼痛、心情、症状都可以随手记下。"),
        ("wand.and.stars", .ovulationViolet, "越用越准的预测",
         "根据你的历史周期加权推算，自动剔除异常数据。\n月经期、排卵日、易孕期、黄体期一目了然。"),
        ("lock.shield.fill", .fertileTeal, "数据只属于你",
         "所有记录仅保存在手机本地，不上传任何服务器。\n还可以开启 Face ID 应用锁保护隐私。"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(0..<pages.count, id: \.self) { i in
                    let p = pages[i]
                    VStack(spacing: 22) {
                        Image(systemName: p.icon)
                            .font(.system(size: 64))
                            .foregroundStyle(p.color)
                            .frame(width: 140, height: 140)
                            .background(p.color.opacity(0.1), in: Circle())
                        Text(p.title)
                            .font(.system(.title2, design: .rounded).weight(.bold))
                        Text(p.text)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    .padding(.horizontal, 32)
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if page < pages.count - 1 {
                    withAnimation(.snappy) { page += 1 }
                } else {
                    dismiss()
                }
            } label: {
                Text(page < pages.count - 1 ? "下一页" : "开始使用")
                    .font(.callout.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        LinearGradient(colors: [Color.brandRose, Color.periodRed],
                                       startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
        .background(AppBackground())
    }
}
