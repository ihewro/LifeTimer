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
    @StateObject private var syncManager = SyncManager(serverURL: "http://localhost:8080")

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(timerModel)
                .environmentObject(audioManager)
                .environmentObject(eventManager)
                .environmentObject(activityMonitor)
                .environmentObject(syncManager)
                .onAppear {
                    // 设置 SyncManager 的依赖
                    syncManager.setDependencies(
                        eventManager: eventManager,
                        activityMonitor: activityMonitor,
                        timerModel: timerModel
                    )
                }
        }
        #if os(macOS)
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unified)
        #endif
    }
}