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

                    #endif

                    // 处理应用启动时的自动监控逻辑
                    activityMonitor.handleAppLaunch()

                    // 初始化应用图标管理器
                    #if canImport(Cocoa)
                    _ = AppIconManager.shared

                    // 监听从菜单栏显示主窗口的通知
                    setupMainWindowNotifications()
                    #endif
                }
        }
        #if os(macOS)
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unified)
        #endif
    }

    /// 设置主窗口通知监听
    private func setupMainWindowNotifications() {
        #if canImport(Cocoa)
        NotificationCenter.default.addObserver(
            forName: .init("ShowMainWindowFromMenuBar"),
            object: nil,
            queue: .main
        ) { _ in
            // 强制显示主窗口
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)

                // 查找主窗口并显示
                if let mainWindow = NSApp.windows.first(where: { window in
                    window.canBecomeMain &&
                    !window.title.contains("智能提醒") &&
                    !window.className.contains("SmartReminder")
                }) {
                    mainWindow.setIsVisible(true)
                    mainWindow.makeKeyAndOrderFront(nil)
                    mainWindow.orderFrontRegardless()
                }
            }
        }
        #endif
    }
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
        // 检查是否有主窗口可见
        let hasMainWindow = NSApp.windows.contains { window in
            window.isVisible &&
            window.canBecomeMain &&
            !window.title.contains("智能提醒") &&
            window.className.contains("AppKitWindow")
        }

        NSLog("AppDelegate: applicationShouldHandleReopen - hasVisibleWindows: \(flag), hasMainWindow: \(hasMainWindow)")

        if !hasMainWindow {
            // 如果没有主窗口可见，尝试显示或创建主窗口
            showOrCreateMainWindow()
        }
        return true
    }

    // 显示或创建主窗口的辅助方法
    private func showOrCreateMainWindow() {
        // 首先尝试找到隐藏的主窗口并显示
        let hiddenMainWindows = NSApp.windows.filter { window in
            window.canBecomeMain &&
            !window.title.contains("智能提醒") &&
            window.className.contains("AppKitWindow")
        }

        if let hiddenWindow = hiddenMainWindows.first {
            NSLog("AppDelegate: Found hidden main window, showing it")
            DispatchQueue.main.async {
                hiddenWindow.setIsVisible(true)
                hiddenWindow.makeKeyAndOrderFront(nil)
                hiddenWindow.orderFrontRegardless()
                NSApp.activate(ignoringOtherApps: true)
            }
            return
        }

        // 如果没有找到隐藏的主窗口，创建新窗口
        NSLog("AppDelegate: No hidden main window found, creating new window")
        createNewWindow()
    }

    // 创建新窗口的辅助方法
    private func createNewWindow() {
        // 方法1：尝试通过菜单项创建新窗口
//        if let fileMenu = NSApp.mainMenu?.item(withTitle: "File"),
//           let newMenuItem = fileMenu.submenu?.item(withTitle: "New") {
//            NSApp.sendAction(newMenuItem.action!, to: newMenuItem.target, from: nil)
//            return
//        }
        
        // NSApp.sendAction(Selector(("newWindow:")), to: nil, from: nil)


        // 方法2：尝试通过Window菜单创建新窗口
//            if let windowMenu = NSApp.mainMenu?.item(withTitle: "Window") {
//                // 查找可能的新窗口菜单项
//                for item in windowMenu.submenu?.items ?? [] {
//                    if item.title.contains("New") || item.keyEquivalent == "n" {
//                        NSApp.sendAction(item.action!, to: item.target, from: nil)
//                        return
//                    }
//                }
//            }

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
#endif
