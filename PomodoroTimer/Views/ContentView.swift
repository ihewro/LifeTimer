//
//  ContentView.swift
//  PomodoroTimer
//
//  Created by Developer on 2024.
//

import SwiftUI

enum SidebarItem: String, CaseIterable {
    case timer = "timer"
    case calendar = "calendar"
    case activityStats = "activityStats"
    case sync = "sync"
    case settings = "settings"

    var title: String {
        switch self {
        case .timer:
            return "计时"
        case .calendar:
            return "日历"
        case .activityStats:
            return "活动"
        case .sync:
            return "同步"
        case .settings:
            return "设置"
        }
    }

    var iconName: String {
        switch self {
        case .timer:
            return "timer"
        case .calendar:
            return "calendar"
        case .activityStats:
            return "chart.bar"
        case .sync:
            return "arrow.triangle.2.circlepath"
        case .settings:
            return "gear"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var timerModel: TimerModel
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var eventManager: EventManager
    @EnvironmentObject var activityMonitor: ActivityMonitorManager
    @EnvironmentObject var syncManager: SyncManager

    @State private var selectedView: SidebarItem = .timer
    
    var body: some View {
        #if canImport(Cocoa)
        // macOS 版本使用 NavigationSplitView
        NavigationSplitView {
            // 左侧边栏
            List(SidebarItem.allCases, id: \.self, selection: $selectedView) { item in
                NavigationLink(value: item) {
                    Label(item.title, systemImage: item.iconName)
                }
            }
            .frame(minWidth: 200)
        } detail: {
            // 主内容区域
            Group {
                switch selectedView {
                case .timer:
                    TimerView()
                case .calendar:
                    CalendarView()
                case .activityStats:
                    ActivityStatsView()
                case .sync:
                    SyncView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(minWidth: 600, minHeight: 500)
        }
        .frame(minWidth: 800, minHeight: 600)
        .navigationTitle("")
        // 添加快捷键支持
        .background(
            // 隐藏的按钮用于处理快捷键
            VStack {
                Button("Settings") { selectedView = .settings }
                    .keyboardShortcut(",", modifiers: .command)
                    .hidden()

                Button("Timer") { selectedView = .timer }
                    .keyboardShortcut("1", modifiers: .command)
                    .hidden()

                Button("Calendar") { selectedView = .calendar }
                    .keyboardShortcut("2", modifiers: .command)
                    .hidden()

                Button("Activity") { selectedView = .activityStats }
                    .keyboardShortcut("3", modifiers: .command)
                    .hidden()

                Button("Sync") { selectedView = .sync }
                    .keyboardShortcut("4", modifiers: .command)
                    .hidden()

                Button("Settings2") { selectedView = .settings }
                    .keyboardShortcut("5", modifiers: .command)
                    .hidden()
            }
        )
        // 权限请求弹窗 - 使用sheet模态表单方式显示
        .sheet(isPresented: $activityMonitor.showPermissionAlert) {
            PermissionRequestAlert(isPresented: $activityMonitor.showPermissionAlert)
                .environmentObject(activityMonitor)
                .frame(minWidth: 500, minHeight: 400)
                .interactiveDismissDisabled(true) // 禁止通过手势关闭，确保用户必须做出选择
        }
        #else
        // iOS 版本使用 TabView
        TabView(selection: $selectedView) {
            TimerView()
                .tabItem {
                    Label("计时器", systemImage: "timer")
                }
                .tag(SidebarItem.timer)

            CalendarView()
                .tabItem {
                    Label("日历", systemImage: "calendar")
                }
                .tag(SidebarItem.calendar)

            ActivityStatsView()
                .tabItem {
                    Label("活动统计", systemImage: "chart.bar")
                }
                .tag(SidebarItem.activityStats)

            SyncView()
                .tabItem {
                    Label("同步", systemImage: "arrow.triangle.2.circlepath")
                }
                .tag(SidebarItem.sync)

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gear")
                }
                .tag(SidebarItem.settings)
        }
        #endif
    }
}

#Preview {
    ContentView()
        .environmentObject(TimerModel())
        .environmentObject(AudioManager())
        .environmentObject(EventManager())
        .environmentObject(ActivityMonitorManager())
        .environmentObject(SyncManager(serverURL: "http://localhost:8080"))
}