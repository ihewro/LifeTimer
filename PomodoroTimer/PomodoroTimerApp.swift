//
//  PomodoroTimerApp.swift
//  PomodoroTimer
//
//  Created by Developer on 2024.
//

import SwiftUI

@main
struct PomodoroTimerApp: App {
    @StateObject private var timerModel = TimerModel()
    @StateObject private var audioManager = AudioManager()
    @StateObject private var eventManager = EventManager()
    @StateObject private var activityMonitor = ActivityMonitorManager()

    // 用户认证系统
    @StateObject private var authManager: AuthManager
    @StateObject private var syncManager: SyncManager

    #if canImport(Cocoa)
    @StateObject private var menuBarManager = MenuBarManager()
    #endif

    init() {
        // 从UserDefaults读取服务器地址，默认为localhost
        let serverURL = UserDefaults.standard.string(forKey: "ServerURL") ?? "http://localhost:8080"

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

                    #if canImport(Cocoa)
                    // 延迟设置 MenuBarManager 的依赖，确保应用完全启动
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        menuBarManager.setTimerModel(timerModel)
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