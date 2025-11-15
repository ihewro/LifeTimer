//
//  ContentView.swift
//  LifeTimer
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
    @EnvironmentObject var smartReminderManager: SmartReminderManager

    #if canImport(Cocoa)
    @EnvironmentObject var menuBarManager: MenuBarManager
    #endif

    @State private var selectedView: SidebarItem = .timer
    @State private var isSidebarVisible: NavigationSplitViewVisibility = .all
    @State private var selectedTask = "无标题"
    
    var body: some View {
        Group {
        #if canImport(Cocoa)
        // macOS 版本使用 NavigationSplitView
        NavigationSplitView(columnVisibility: $isSidebarVisible) {
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
                    TimerView(selectedTask: $selectedTask)
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
            .frame(minWidth: 600, minHeight: 550)
        }
        .navigationTitle("")
        .toolbar {
            // 隐藏默认的标题视图
            ToolbarItem(placement: .principal) {
                EmptyView()
            }
        }
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

                // 添加侧边栏切换快捷键 Cmd+S
                Button("Toggle Sidebar") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        switch isSidebarVisible {
                        case .all:
                            isSidebarVisible = .detailOnly
                        case .detailOnly:
                            isSidebarVisible = .all
                        default:
                            isSidebarVisible = .all
                        }
                    }
                }
                .keyboardShortcut("s", modifiers: .command)
                .hidden()
            }
        )
        // 权限请求弹窗 - 使用sheet模态表单方式显示
        .sheet(isPresented: $activityMonitor.showPermissionAlert) {
            PermissionRequestAlert(isPresented: $activityMonitor.showPermissionAlert)
                .environmentObject(activityMonitor)
                // .frame(minWidth: 500, minHeight: 300)
                // .interactiveDismissDisabled(true) // 禁止通过手势关闭，确保用户必须做出选择
        }
        // 强制控件使用激活态外观，避免在 accessory 模式下出现侧边栏与控件灰态
        .environment(\.controlActiveState, .key)
        // 智能提醒弹窗 - macOS 使用独立窗口，不需要 sheet
        #else
        // iOS 版本使用 TabView
        TabView(selection: $selectedView) {
            TimerView(selectedTask: $selectedTask)
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
        // 智能提醒弹窗 - iOS版本也需要全局显示
        .sheet(isPresented: $smartReminderManager.showingReminderDialog) {
            SmartReminderDialog(
                isPresented: $smartReminderManager.showingReminderDialog,
                timerModel: timerModel,
                reminderManager: smartReminderManager,
                selectedTask: selectedTask
            )
            .environmentObject(eventManager)
        }
        #endif
        }
        .onAppear {
            // 只有在计时器空闲状态且用户未设置自定义任务时，才从最近事件设置默认任务
            // 这样可以防止窗口重新激活时覆盖用户在计时过程中修改的任务
            if timerModel.timerState == .idle && !timerModel.hasUserSetCustomTask {
                setDefaultTaskFromRecentEvent()
            }

            // 设置智能提醒管理器的当前任务
            smartReminderManager.setCurrentTask(selectedTask)
        }
        .onChange(of: selectedTask) { newTask in
            // 当选中任务变化时，更新智能提醒管理器
            smartReminderManager.setCurrentTask(newTask)
        }
    }

    /// 从最近的事件中设置默认任务
    private func setDefaultTaskFromRecentEvent() {
        // 获取最近的已完成事件
        let recentEvents = eventManager.events
            .filter { $0.isCompleted }
            .sorted { $0.startTime > $1.startTime }

        // 如果有最近的事件，使用其标题作为默认任务
        if let mostRecentEvent = recentEvents.first {
            selectedTask = mostRecentEvent.title
        }
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