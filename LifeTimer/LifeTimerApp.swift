//
//  LifeTimerApp.swift
//  LifeTimer
//
//  Created by Developer on 2024.
//

import SwiftUI
#if canImport(Cocoa)
import Cocoa
#endif

@main
struct LifeTimerApp: App {
    @StateObject private var timerModel = TimerModel()
    @StateObject private var audioManager = AudioManager()
    @StateObject private var eventManager = EventManager()
    @StateObject private var activityMonitor = ActivityMonitorManager()
    @StateObject private var smartReminderManager = SmartReminderManager()

    // 用户认证系统
    @StateObject private var authManager: AuthManager
    @StateObject private var syncManager: SyncManager

    #if canImport(Cocoa)
    @StateObject private var menuBarManager = MenuBarManager()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow
    #endif

    init() {
        // 从UserDefaults读取服务器地址，默认为localhost
        let serverURL = UserDefaults.standard.string(forKey: "ServerURL") ?? ""

        // 创建共享的AuthManager实例
        let authManager = AuthManager(serverURL: serverURL)
        self._authManager = StateObject(wrappedValue: authManager)

        // 初始化同步管理器（支持认证）
        let syncManager = SyncManager(serverURL: serverURL, authManager: authManager)
        self._syncManager = StateObject(wrappedValue: syncManager)
    }

    var body: some Scene {
        WindowGroup("LifeTimer", id: "main") {
            ContentView()
                .environmentObject(timerModel)
                .environmentObject(audioManager)
                .environmentObject(eventManager)
                .environmentObject(activityMonitor)
                .environmentObject(smartReminderManager)
                .environmentObject(authManager)
                .environmentObject(syncManager)
                #if canImport(Cocoa)
                .environmentObject(menuBarManager)
                #endif
                .onAppear {
                    // 设置 SyncManager 的依赖
                    syncManager.setDependencies(
                        eventManager: eventManager,
                        activityMonitor: activityMonitor,
                        timerModel: timerModel
                    )

                    // 设置智能提醒管理器的依赖
                    smartReminderManager.setTimerModel(timerModel)
                    smartReminderManager.setEventManager(eventManager)

                    #if canImport(Cocoa)
                    // 延迟设置 MenuBarManager 的依赖，确保应用完全启动
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        menuBarManager.setTimerModel(timerModel)
                        menuBarManager.setEventManager(eventManager)
                        menuBarManager.setSmartReminderManager(smartReminderManager)
                    }

                    #endif

                    // 处理应用启动时的自动监控逻辑
                    activityMonitor.handleAppLaunch()

                    // 初始化应用图标管理器
                    #if canImport(Cocoa)
                    _ = AppIconManager.shared


                    // 监听创建新窗口的通知
                    setupNewWindowNotifications()
                    #endif
                }
        }
        #if os(macOS)
        .windowStyle(windowStyleForCurrentOS())
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unified)
        #endif
    }

    #if canImport(Cocoa)
    /// 设置新窗口创建通知监听
    private func setupNewWindowNotifications() {
        // 使用单例模式确保只注册一次
        WindowNotificationManager.shared.setupNotifications { windowId in
            openWindow(id: windowId)
        }
    }

    /// 根据系统版本返回合适的窗口样式
    private func windowStyleForCurrentOS() -> some WindowStyle {
        if #available(macOS 26.0, *) {
            // macOS 15.0+ (对应系统版本 >= 26)
            return .hiddenTitleBar
        } else {
            // 较旧的系统版本
            return .titleBar
        }
    }
    #endif
}

#if canImport(Cocoa)
// AppDelegate 用于处理应用程序生命周期
class AppDelegate: NSObject, NSApplicationDelegate {

    override init() {
        super.init()
        NSLog("AppDelegate: Initialized")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("AppDelegate: applicationDidFinishLaunching")
    }

    // 防止应用在最后一个窗口关闭时退出
    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool {
        return false
    }

    // 处理应用重新激活（比如点击Dock图标或菜单栏图标）
    func applicationShouldHandleReopen(_ app: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if (!flag) {
            // 一个窗口都没有的时候走系统逻辑，否则在新版本上会持续多个窗口的情况
            return true;
        }
        NSLog("AppDelegate: applicationShouldHandleReopen - hasVisibleWindows: \(flag)")

        // 使用 WindowManager 来处理窗口显示逻辑
        let windowManager = WindowManager.shared

        NSLog("AppDelegate: hasVisibleMainWindow: \(windowManager.hasVisibleMainWindow)")

        if !windowManager.hasVisibleMainWindow {
            // 如果没有主窗口可见，尝试显示或创建主窗口
            windowManager.showOrCreateMainWindow()
        }
        return true
    }


}
#endif
