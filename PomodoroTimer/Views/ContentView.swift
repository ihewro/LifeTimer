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
    case settings = "settings"

    var title: String {
        switch self {
        case .timer:
            return "计时"
        case .calendar:
            return "日历"
        case .activityStats:
            return "活动"
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
            .navigationTitle("番茄钟")
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
                case .settings:
                    SettingsView()
                }
            }
            .frame(minWidth: 600, minHeight: 500)
        }
        .frame(minWidth: 800, minHeight: 600)
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
}