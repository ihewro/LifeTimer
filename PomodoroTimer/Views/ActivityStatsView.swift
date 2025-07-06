//
//  ActivityStatsView.swift
//  PomodoroTimer
//
//  Created by Assistant on 2024
//

import SwiftUI

/// 活动统计视图
struct ActivityStatsView: View {
    @EnvironmentObject var activityMonitor: ActivityMonitorManager
    @State private var selectedDate = Date()
    @State private var selectedTab = 0
    @State private var refreshTrigger = UUID() // 用于强制刷新数据

    var body: some View {
        // 内容区域
        Group {
            switch selectedTab {
            case 0:
                overviewTab
            case 1:
                timelineTab
            case 2:
                appStatsTab
            case 3:
                productivityTab
            default:
                overviewTab
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            refreshData()
        }
        .onChange(of: selectedDate) { _ in
            refreshData()
        }
        .onReceive(activityMonitor.$isMonitoring) { _ in
            // 当监控状态改变时刷新数据
            refreshData()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // 当应用重新激活时刷新数据
            refreshData()
        }
        .toolbar {
            // 左侧：Tab选项卡 Picker
            ToolbarItem(placement: .principal) {
                Picker("", selection: $selectedTab) {
                    Text("概览").tag(0)
                    Text("时间轴").tag(1)
                    Text("应用").tag(2)
                    Text("生产力").tag(3)
                }
                .pickerStyle(.segmented)
                .frame(width: 280)
            }

            // 中间：日期导航
            ToolbarItem(placement: .navigation) {
                HStack(spacing: 8) {
                    Button(action: {
                        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                    }) {
                        Image(systemName: "chevron.left")
                    }
                    Button(action: {
                        selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                    }) {
                        Image(systemName: "chevron.right")
                    }
                    // 日期显示组件
                    Text(formatSelectedDate(selectedDate))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 8)

                    Button("今天") {
                        selectedDate = Date()
                    }
                    .disabled(isToday(selectedDate))

                }
            }
            // 中间：占位符确保 toolbar 铺满宽度
            ToolbarItem(placement: .principal) {
                Spacer()
            }
            // 右侧：监控状态和控制
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(activityMonitor.isMonitoring ? Color.green : Color.red)
                            .frame(width: 6, height: 6)

                        Text(activityMonitor.isMonitoring ? "" : "未监控")
                            // .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Button(activityMonitor.isMonitoring ? "停止" : "开始") {
                        activityMonitor.toggleMonitoring()
                    }
                    .buttonStyle(.borderedProminent)
                    // .controlSize(.small)
                    // .font(.caption)
                }
            }
        }
    }

    // MARK: - 数据刷新方法

    private func refreshData() {
        // 触发数据刷新
        refreshTrigger = UUID()

        // 强制重新计算时间轴事件
        DispatchQueue.main.async {
            // 这里可以添加其他需要刷新的数据逻辑
            print("Activity data refreshed for date: \(selectedDate)")
        }
    }



    // MARK: - 概览标签页

    private var overviewTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                let overview = activityMonitor.getTodayOverview()

                // 今日概览卡片
                VStack(alignment: .leading, spacing: 12) {
                    Text("今日概览")
                        .font(.headline)

                    HStack(spacing: 20) {
                        StatCard(
                            title: "活跃时间",
                            value: formatTime(overview.activeTime),
                            icon: "clock",
                            color: .blue
                        )

                        StatCard(
                            title: "应用切换",
                            value: "\(overview.appSwitches)",
                            icon: "arrow.triangle.2.circlepath",
                            color: .orange
                        )

                        // StatCard(
                        //     title: "网站访问",
                        //     value: "\(overview.websiteVisits)",
                        //     icon: "globe",
                        //     color: .green
                        // )
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)

                // 快速应用统计
                quickAppStats

                // // 快速网站统计
                // quickWebsiteStats
            }
            .padding()
        }
    }

    // MARK: - 时间轴标签页（真实时间轴）

    private var timelineTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                let timelineEvents = generateTimelineEvents()
                if timelineEvents.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)

                        Text("暂无时间轴数据")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text("请确保活动监控已开启，并且有应用使用记录")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    // 真实时间轴视图
                    AppTimelineView(events: timelineEvents, refreshTrigger: refreshTrigger)
                }
            }
            .padding(.vertical)
        }
    }

    // MARK: - 应用统计标签页

    private var appStatsTab: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                let appStats = activityMonitor.getAppUsageStats(for: selectedDate)

                if appStats.isEmpty {
                    Text("暂无应用使用数据")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(appStats, id: \.appName) { stat in
                        AppStatRow(stat: stat)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - 生产力标签页

    private var productivityTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                let analysis = activityMonitor.getProductivityAnalysis(for: selectedDate)

                // 生产力得分
                VStack(alignment: .leading, spacing: 12) {
                    Text("生产力分析")
                        .font(.headline)

                    HStack {
                        VStack(alignment: .leading) {
                            Text("生产力得分")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Text(analysis.formattedProductivityScore)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(productivityColor(analysis.productivityScore))

                            Text(analysis.productivityLevel)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        // 生产力环形图
                        if analysis.totalTime > 0 {
                            ProductivityChart(analysis: analysis)
                                .frame(width: 120, height: 120)
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)

                // 时间分布
                timeDistributionView(analysis: analysis)

                // 建议
                productivitySuggestions(analysis: analysis)
            }
            .padding()
        }
    }

    // MARK: - 辅助视图

    private var quickAppStats: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("热门应用")
                .font(.headline)

            let topApps = Array(activityMonitor.getAppUsageStats(for: selectedDate).prefix(10))

            if topApps.isEmpty {
                Text("暂无数据")
                    .foregroundColor(.secondary)
            } else {
                ForEach(topApps, id: \.appName) { stat in
                    HStack {
                        Text(stat.appName)
                            .lineLimit(1)
                        Spacer()
                        Text(stat.formattedTime)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private var quickWebsiteStats: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("热门网站")
                .font(.headline)

            let topSites = Array(activityMonitor.getWebsiteStats(for: selectedDate).prefix(3))

            if topSites.isEmpty {
                Text("暂无数据")
                    .foregroundColor(.secondary)
            } else {
                ForEach(topSites, id: \.domain) { stat in
                    HStack {
                        Text(stat.domain)
                            .lineLimit(1)
                        Spacer()
                        Text("\(stat.visits)次 · \(stat.formattedTime)")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private func timeDistributionView(analysis: ProductivityAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("时间分布")
                .font(.headline)

            VStack(spacing: 8) {
                TimeDistributionBar(
                    title: "生产性工作",
                    time: analysis.productiveTime,
                    total: analysis.totalTime,
                    color: .green
                )

                TimeDistributionBar(
                    title: "娱乐休闲",
                    time: analysis.entertainmentTime,
                    total: analysis.totalTime,
                    color: .orange
                )

                TimeDistributionBar(
                    title: "其他",
                    time: analysis.otherTime,
                    total: analysis.totalTime,
                    color: .gray
                )
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private func productivitySuggestions(analysis: ProductivityAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("建议")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                if analysis.productivityScore < 50 {
                    SuggestionRow(
                        icon: "lightbulb",
                        text: "尝试减少娱乐应用的使用时间",
                        color: .yellow
                    )
                }

                if analysis.totalWebsiteVisits > 50 {
                    SuggestionRow(
                        icon: "safari",
                        text: "考虑使用网站屏蔽工具提高专注度",
                        color: .blue
                    )
                }

                SuggestionRow(
                    icon: "target",
                    text: "设定每日生产力目标，保持良好习惯",
                    color: .green
                )
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    // MARK: - 辅助方法

    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func productivityColor(_ score: Double) -> Color {
        switch score {
        case 80...100:
            return .green
        case 60..<80:
            return .blue
        case 40..<60:
            return .orange
        default:
            return .red
        }
    }

    private func previousDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
    }

    private func nextDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日"
        return formatter.string(from: date)
    }

    private func formatDateTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        return formatter.string(from: date)
    }

    private func formatSelectedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日"
        return formatter.string(from: date)
    }

    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: Date())
    }

    // MARK: - 时间轴数据生成

    private func generateTimelineData() -> [TimelineHourData] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        var timelineData: [TimelineHourData] = []

        for hour in 0..<24 {
            let hourStart = calendar.date(byAdding: .hour, value: hour, to: startOfDay) ?? startOfDay
            let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart) ?? hourStart

            // 获取这个小时内的应用使用数据
            let appStats = activityMonitor.getAppUsageStats(for: selectedDate)
            let hourApps = appStats.compactMap { stat -> TimelineAppUsage? in
                // 简化处理：假设应用使用时间均匀分布在一天中
                let hourUsage = stat.totalTime / 24
                if hourUsage > 60 { // 只显示使用超过1分钟的应用
                    return TimelineAppUsage(
                        appName: stat.appName,
                        duration: TimeInterval(hourUsage),
                        startTime: hourStart,
                        endTime: hourEnd
                    )
                }
                return nil
            }

            timelineData.append(TimelineHourData(
                hour: hour,
                hourStart: hourStart,
                apps: hourApps
            ))
        }

        return timelineData
    }

    // MARK: - 时间轴事件生成（基于真实系统事件）

    private func generateTimelineEvents() -> [AppTimelineEvent] {
        // 直接从 ActivityMonitorManager 获取指定日期的真实系统事件
        let systemEvents = activityMonitor.getSystemEvents(for: selectedDate)

        print("Debug: Found \(systemEvents.count) system events for \(selectedDate)")

        // 如果没有系统事件，尝试从应用统计数据生成简化的时间轴
        if systemEvents.isEmpty {
            return generateFallbackTimelineEvents()
        }

        var events: [AppTimelineEvent] = []
        var currentApp: String?
        var appStartTime: Date?

        // 按时间顺序处理系统事件
        let sortedEvents = systemEvents.sorted { $0.timestamp < $1.timestamp }

        for event in sortedEvents {
            switch event.type {
            case .appActivated:
                // 获取当前事件的应用名称
                guard let eventAppName = event.appName else { break }

                // 如果是同一个应用的重复激活事件，跳过处理
                if currentApp == eventAppName {
                    break
                }

                // 结束上一个应用的使用记录
                if let lastApp = currentApp,
                   let startTime = appStartTime {

                    let duration = event.timestamp.timeIntervalSince(startTime)

                    // 只记录使用时间超过10秒的应用会话
                    if duration > 10 {
                        events.append(AppTimelineEvent(
                            appName: lastApp,
                            startTime: startTime,
                            endTime: event.timestamp,
                            duration: duration
                        ))
                    }
                }

                // 开始新应用的使用记录（只有当应用真正切换时）
                currentApp = eventAppName
                appStartTime = event.timestamp

            case .appTerminated:
                // 如果终止的是当前应用，结束其使用记录
                if let appName = event.appName,
                   appName == currentApp,
                   let startTime = appStartTime {

                    let duration = event.timestamp.timeIntervalSince(startTime)

                    if duration > 10 {
                        events.append(AppTimelineEvent(
                            appName: appName,
                            startTime: startTime,
                            endTime: event.timestamp,
                            duration: duration
                        ))
                    }

                    currentApp = nil
                    appStartTime = nil
                }

            case .systemSleep:
                // 系统休眠时结束当前应用记录
                if let lastApp = currentApp,
                   let startTime = appStartTime {

                    let duration = event.timestamp.timeIntervalSince(startTime)

                    if duration > 10 {
                        events.append(AppTimelineEvent(
                            appName: lastApp,
                            startTime: startTime,
                            endTime: event.timestamp,
                            duration: duration
                        ))
                    }

                    currentApp = nil
                    appStartTime = nil
                }

            default:
                break
            }
        }

        // 处理仍在运行的应用（如果是今天的数据）
        let calendar = Calendar.current
        if calendar.isDateInToday(selectedDate),
           let lastApp = currentApp,
           let startTime = appStartTime {

            let now = Date()
            let duration = now.timeIntervalSince(startTime)

            if duration > 10 {
                events.append(AppTimelineEvent(
                    appName: lastApp,
                    startTime: startTime,
                    endTime: now,
                    duration: duration
                ))
            }
        }

        print("Debug: Generated \(events.count) timeline events from system events")

        // 按开始时间倒序排序并去重（最新的事件在前面）
        let finalSortedEvents = events.sorted { $0.startTime > $1.startTime }
        return removeDuplicateEvents(finalSortedEvents)
    }

    // 备用时间轴生成方法（当没有系统事件时使用）
    private func generateFallbackTimelineEvents() -> [AppTimelineEvent] {
        let appStats = activityMonitor.getAppUsageStats(for: selectedDate)

        print("Debug: Using fallback method with \(appStats.count) app stats")

        guard !appStats.isEmpty else { return [] }

        var events: [AppTimelineEvent] = []
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)

        // 为每个应用创建一个简化的使用记录
        var currentTime = calendar.date(byAdding: .hour, value: 9, to: startOfDay) ?? startOfDay

        for stat in appStats.sorted(by: { $0.totalTime > $1.totalTime }) {
            let duration = min(stat.totalTime, 3600) // 最多1小时
            let endTime = calendar.date(byAdding: .second, value: Int(duration), to: currentTime) ?? currentTime

            events.append(AppTimelineEvent(
                appName: stat.appName,
                startTime: currentTime,
                endTime: endTime,
                duration: duration
            ))

            // 下一个应用开始时间（添加5分钟间隔）
            currentTime = calendar.date(byAdding: .minute, value: 5, to: endTime) ?? endTime
        }

        return events
    }

    // 去除重复或重叠的事件
    private func removeDuplicateEvents(_ events: [AppTimelineEvent]) -> [AppTimelineEvent] {
        var filteredEvents: [AppTimelineEvent] = []

        for event in events {
            // 检查是否与已有事件重叠
            let hasOverlap = filteredEvents.contains { existingEvent in
                // 检查时间重叠
                let overlap = max(0, min(event.endTime, existingEvent.endTime).timeIntervalSince(max(event.startTime, existingEvent.startTime)))
                return overlap > 5 && event.appName == existingEvent.appName
            }

            if !hasOverlap {
                filteredEvents.append(event)
            }
        }

        return filteredEvents
    }
}

// MARK: - 时间轴数据结构

struct TimelineHourData {
    let hour: Int
    let hourStart: Date
    let apps: [TimelineAppUsage]
}

struct TimelineAppUsage {
    let appName: String
    let duration: TimeInterval
    let startTime: Date
    let endTime: Date
}

// MARK: - 新的时间轴事件数据结构

struct AppTimelineEvent {
    let appName: String
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
}

// MARK: - 辅助视图组件

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title2)

            Text(value)
                .font(.headline)
                .fontWeight(.semibold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct AppStatRow: View {
    let stat: AppUsageStats

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(stat.appName)
                    .font(.headline)

                Text("启动 \(stat.activationCount) 次")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(stat.formattedTime)
                    .font(.headline)
                    .fontWeight(.semibold)

                if let lastUsed = stat.lastUsed {
                    Text("最后使用: \(formatRelativeTime(lastUsed))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct TimeDistributionBar: View {
    let title: String
    let time: TimeInterval
    let total: TimeInterval
    let color: Color

    private var percentage: Double {
        total > 0 ? (time / total) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)

                Spacer()

                Text(formatTime(time))
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("(\(String(format: "%.1f", percentage * 100))%)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)

                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * percentage, height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
struct SuggestionRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)

            Text(text)
                .font(.subheadline)

            Spacer()
        }
    }
}

struct ProductivityChart: View {
    let analysis: ProductivityAnalysis

    var body: some View {
        ZStack {
            // 背景圆环
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 12)

            // 生产力圆环
            Circle()
                .trim(from: 0, to: analysis.productivityScore / 100)
                .stroke(
                    LinearGradient(
                        colors: [.green, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1), value: analysis.productivityScore)

            // 中心文字
            VStack(spacing: 2) {
                Text("\(Int(analysis.productivityScore))")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

enum ActivityLevel {
    case none, light, medium, high
}

// MARK: - 新的时间轴视图组件

struct AppTimelineView: View {
    let events: [AppTimelineEvent]
    let refreshTrigger: UUID?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 时间轴标题和统计信息
                timelineHeader

                if !events.isEmpty {
                    // 时间范围显示
                    timeRangeInfo

                    // 时间序列时间轴
                    LazyVStack(spacing: 2) {
                        ForEach(Array(events.enumerated()), id: \.offset) { index, event in
                            TimelineEventRow(
                                event: event,
                                isFirst: index == 0,
                                isLast: index == events.count - 1,
                                previousEvent: index > 0 ? events[index - 1] : nil
                            )
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.primary.opacity(0.05))
                    )
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .id(refreshTrigger ?? UUID()) // 使用refreshTrigger强制刷新
    }

    private var timelineHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("应用使用时间轴")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("按时间顺序显示应用切换记录")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(events.count) 个记录")
                    .font(.headline)
                    .foregroundColor(.primary)

                if !events.isEmpty {
                    let totalDuration = events.reduce(0) { $0 + $1.duration }
                    Text("总计 \(formatDuration(totalDuration))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal)
    }

    private var timeRangeInfo: some View {
        Group {
            if let firstEvent = events.first, let lastEvent = events.last {
                HStack {
                    Label {
                        Text(formatEventTime(firstEvent))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } icon: {
                        Image(systemName: "clock")
                            .foregroundColor(.green)
                    }

                    Spacer()

                    Image(systemName: "arrow.right")
                        .foregroundColor(.secondary)
                        .font(.caption)

                    Spacer()

                    Label {
                        Text(formatEventTime(lastEvent, showEndTime: true))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } icon: {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.1))
                )
                .padding(.horizontal)
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalMinutes = Int(duration) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours)h\(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func formatEventTime(_ event: AppTimelineEvent, showEndTime: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        if showEndTime {
            return formatter.string(from: event.endTime)
        } else {
            return formatter.string(from: event.startTime)
        }
    }


}

// 时间序列事件行
struct TimelineEventRow: View {
    let event: AppTimelineEvent
    let isFirst: Bool
    let isLast: Bool
    let previousEvent: AppTimelineEvent?

    var body: some View {
        VStack(spacing: 0) {
            // 显示时间间隔（如果有前一个事件）
            if let prevEvent = previousEvent {
                timeGapIndicator(from: prevEvent.endTime, to: event.startTime)
            }

            // 主要事件行
            HStack(alignment: .center, spacing: 16) {
                // 左侧时间信息
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatTime(event.startTime))
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)

                    Text(formatTime(event.endTime))
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .frame(width: 60)

                // 中间时间轴指示器
                VStack(spacing: 0) {
                    // 上方连接线
                    if !isFirst {
                        Rectangle()
                            .fill(appColor(for: event.appName).opacity(0.3))
                            .frame(width: 3, height: 8)
                    }

                    // 应用图标
                    Circle()
                        .fill(appColor(for: event.appName))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Text(String(event.appName.prefix(1)).uppercased())
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .shadow(color: appColor(for: event.appName).opacity(0.3), radius: 2, x: 0, y: 1)

                    // 下方连接线
                    if !isLast {
                        Rectangle()
                            .fill(appColor(for: event.appName).opacity(0.3))
                            .frame(width: 3, height: 8)
                    }
                }

                // 右侧应用信息和持续时间
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(event.appName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        Spacer()

                        // 持续时间标签
                        Text(formatDuration(event.duration))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(appColor(for: event.appName))
                            )
                    }

                    // 时间范围
                    Text("\(formatTime(event.startTime)) - \(formatTime(event.endTime))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(appColor(for: event.appName).opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(appColor(for: event.appName).opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 12)
        }
    }

    // 时间间隔指示器
    private func timeGapIndicator(from endTime: Date, to startTime: Date) -> some View {
        let gap = startTime.timeIntervalSince(endTime)

        return Group {
            if gap > 60 { // 只显示超过1分钟的间隔
                HStack {
                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)

                        Text("间隔 \(formatDuration(gap))")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(0.1))
                    )

                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func appColor(for appName: String) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .red, .pink, .yellow, .cyan]
        let hash = appName.hashValue
        return colors[abs(hash) % colors.count]
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func formatEventTime(_ event: AppTimelineEvent, showEndTime: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"

        if showEndTime {
            return formatter.string(from: event.endTime)
        } else {
            return formatter.string(from: event.startTime)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalMinutes = Int(duration) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return "\(hours)h\(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m\(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

#Preview {
    ActivityStatsView()
        .environmentObject(ActivityMonitorManager())
}
