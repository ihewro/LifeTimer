//
//  PomodoroTimerApp.swift
//  PomodoroTimer
//
//  Created by Developer on 2024.
//

import SwiftUI
#if canImport(Cocoa)
import Cocoa
#endif

@main
struct PomodoroTimerApp: App {
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
        WindowGroup {
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

                    #if canImport(Cocoa)
                    // 延迟设置 MenuBarManager 的依赖，确保应用完全启动
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        menuBarManager.setTimerModel(timerModel)
                    }

                    // 设置应用代理以处理窗口关闭行为
                    DispatchQueue.main.async {
                        if NSApp.delegate == nil {
                            NSApp.delegate = AppDelegate.shared
                        }
                    }
                    #endif

                    // 处理应用启动时的自动监控逻辑
                    activityMonitor.handleAppLaunch()
                }
        }
        #if os(macOS)
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unified)
        #endif
    }
}

#if canImport(Cocoa)
// AppDelegate 用于处理应用程序生命周期
class AppDelegate: NSObject, NSApplicationDelegate {
    static let shared = AppDelegate()

    // 防止应用在最后一个窗口关闭时退出
    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool {
        return false
    }

    // 处理应用重新激活（比如点击Dock图标或菜单栏图标）
    func applicationShouldHandleReopen(_ app: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // 如果没有可见窗口，创建新窗口
            createNewWindow()
        }
        return true
    }

    // 创建新窗口的辅助方法
    private func createNewWindow() {
        DispatchQueue.main.async {
            // 方法1：尝试通过菜单项创建新窗口
            if let fileMenu = NSApp.mainMenu?.item(withTitle: "File"),
               let newMenuItem = fileMenu.submenu?.item(withTitle: "New") {
                NSApp.sendAction(newMenuItem.action!, to: newMenuItem.target, from: nil)
                return
            }

            // 方法2：尝试通过Window菜单创建新窗口
            if let windowMenu = NSApp.mainMenu?.item(withTitle: "Window") {
                // 查找可能的新窗口菜单项
                for item in windowMenu.submenu?.items ?? [] {
                    if item.title.contains("New") || item.keyEquivalent == "n" {
                        NSApp.sendAction(item.action!, to: item.target, from: nil)
                        return
                    }
                }
            }

            // 方法3：发送 Cmd+N 键盘事件
            let event = NSEvent.keyEvent(
                with: .keyDown,
                location: NSPoint.zero,
                modifierFlags: .command,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: "n",
                charactersIgnoringModifiers: "n",
                isARepeat: false,
                keyCode: 45 // 'n' key code
            )
            if let event = event {
                NSApp.sendEvent(event)
            }
        }
    }
}
#endif
