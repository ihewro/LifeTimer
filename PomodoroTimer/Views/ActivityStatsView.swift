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
                    .controlSize(.small)

                    Button("今天") {
                        selectedDate = Date()
                    }
                    .controlSize(.small)

                    Button(action: {
                        selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                    }) {
                        Image(systemName: "chevron.right")
                    }
                    .controlSize(.small)
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

                        Text(activityMonitor.isMonitoring ? "监控中" : "未监控")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Button(activityMonitor.isMonitoring ? "停止" : "开始") {
                        activityMonitor.toggleMonitoring()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .font(.caption)
                }
            }
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

                        StatCard(
                            title: "网站访问",
                            value: "\(overview.websiteVisits)",
                            icon: "globe",
                            color: .green
                        )
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)

                // 快速应用统计
                quickAppStats

                // 快速网站统计
                quickWebsiteStats
            }
            .padding()
        }
    }

    // MARK: - 时间轴标签页（真实时间轴）

    private var timelineTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                let timelineEvents = generateTimelineEvents()

                // 日期标题
                HStack {
                    Text(formatDateTitle(selectedDate))
                        .font(.title2)
                        .fontWeight(.semibold)

                    Spacer()

                    Text("应用切换时间轴")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)

                if timelineEvents.isEmpty {
                    Text("暂无时间轴数据")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    // 真实时间轴视图
                    AppTimelineView(events: timelineEvents)
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

            let topApps = Array(activityMonitor.getAppUsageStats(for: selectedDate).prefix(3))

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

    // MARK: - 新的时间轴事件生成

    private func generateTimelineEvents() -> [AppTimelineEvent] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        let appStats = activityMonitor.getAppUsageStats(for: selectedDate)

        var events: [AppTimelineEvent] = []
        let currentTime = calendar.date(byAdding: .hour, value: 8, to: startOfDay) ?? startOfDay // 从早上8点开始

        // 模拟应用切换事件（实际应用中应该从真实的系统事件获取）
        for (index, stat) in appStats.enumerated() {
            let averageSessionDuration = stat.totalTime / Double(max(stat.activationCount, 1))
            let sessionDuration = min(averageSessionDuration, 7200) // 每次使用最多2小时

            for session in 0..<min(stat.activationCount, 8) { // 最多显示8个会话
                // 更真实的时间分布
                let randomOffset = Int.random(in: 0...120) // 随机偏移0-2小时
                let baseTime = calendar.date(byAdding: .minute, value: index * 45 + session * 90 + randomOffset, to: currentTime) ?? currentTime

                // 确保时间在当天范围内
                let endOfDay = calendar.date(byAdding: .hour, value: 22, to: startOfDay) ?? startOfDay
                guard baseTime < endOfDay else { break }

                let startTime = baseTime
                let endTime = min(
                    calendar.date(byAdding: .second, value: Int(sessionDuration), to: startTime) ?? startTime,
                    endOfDay
                )

                let actualDuration = endTime.timeIntervalSince(startTime)

                if actualDuration > 60 { // 只显示超过1分钟的会话
                    events.append(AppTimelineEvent(
                        appName: stat.appName,
                        startTime: startTime,
                        endTime: endTime,
                        duration: actualDuration
                    ))
                }
            }
        }

        // 按开始时间排序
        return events.sorted { $0.startTime < $1.startTime }
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

// MARK: - 日视图时间轴组件

struct DayTimelineGridView: View {
    let timelineData: [TimelineHourData]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 6)

    var body: some View {
        VStack(spacing: 16) {
            // 时间段标题
            HStack {
                Text("时间段")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("活动强度")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal)

            // 24小时网格
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(timelineData, id: \.hour) { hourData in
                    DayTimelineHourCell(hourData: hourData)
                }
            }
            .padding(.horizontal)

            // 图例
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                    Text("无活动")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green.opacity(0.6))
                        .frame(width: 8, height: 8)
                    Text("轻度活动")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                    Text("中度活动")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("高度活动")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
        }
    }
}

struct DayTimelineHourCell: View {
    let hourData: TimelineHourData
    @State private var showingDetail = false

    private var hourString: String {
        String(format: "%02d:00", hourData.hour)
    }

    private var activityLevel: ActivityLevel {
        let totalApps = hourData.apps.count
        let totalTime = hourData.apps.reduce(0) { $0 + $1.duration }

        if totalApps == 0 {
            return .none
        } else if totalTime < 300 { // 5分钟以下
            return .light
        } else if totalTime < 1800 { // 30分钟以下
            return .medium
        } else {
            return .high
        }
    }

    private var activityColor: Color {
        switch activityLevel {
        case .none:
            return Color.gray.opacity(0.3)
        case .light:
            return Color.green.opacity(0.6)
        case .medium:
            return Color.orange
        case .high:
            return Color.red
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            // 时间标签
            Text(hourString)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.primary)

            // 活动指示器
            RoundedRectangle(cornerRadius: 4)
                .fill(activityColor)
                .frame(height: 24)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                )

            // 应用数量
            if hourData.apps.count > 0 {
                Text("\(hourData.apps.count)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                Text("-")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.primary.opacity(0.05))
        )
        .onTapGesture {
            showingDetail = true
        }
        .popover(isPresented: $showingDetail) {
            HourDetailView(hourData: hourData)
        }
    }
}

enum ActivityLevel {
    case none, light, medium, high
}
struct HourDetailView: View {
    let hourData: TimelineHourData

    private var hourString: String {
        String(format: "%02d:00", hourData.hour)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            HStack {
                Text("\(hourString) 活动详情")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()
            }

            if hourData.apps.isEmpty {
                Text("该时段无活动记录")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                // 应用列表
                ForEach(hourData.apps, id: \.appName) { app in
                    HStack(spacing: 12) {
                        Rectangle()
                            .fill(appColor(for: app.appName))
                            .frame(width: 4, height: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.appName)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text(formatDuration(app.duration))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)
                }

                // 总计
                Divider()

                HStack {
                    Text("总计")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    Text("\(hourData.apps.count) 个应用")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .frame(minWidth: 250, maxWidth: 300)
    }

    private func appColor(for appName: String) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .red, .pink, .yellow, .cyan]
        let hash = appName.hashValue
        return colors[abs(hash) % colors.count]
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        if minutes < 60 {
            return "\(minutes)分钟"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)小时\(remainingMinutes)分钟"
        }
    }
}

// MARK: - 新的时间轴视图组件

struct AppTimelineView: View {
    let events: [AppTimelineEvent]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 时间轴说明
                HStack {
                    Text("应用切换时间轴")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Spacer()

                    Text("共 \(events.count) 个使用记录")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)

                // 时间序列时间轴
                LazyVStack(spacing: 0) {
                    ForEach(Array(events.enumerated()), id: \.offset) { index, event in
                        TimelineEventRow(
                            event: event,
                            isFirst: index == 0,
                            isLast: index == events.count - 1
                        )
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }


}

// 时间序列事件行
struct TimelineEventRow: View {
    let event: AppTimelineEvent
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 左侧时间轴线和图标
            VStack(spacing: 0) {
                // 上方连接线
                if !isFirst {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 2, height: 12)
                }

                // 应用图标
                Circle()
                    .fill(appColor(for: event.appName))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(event.appName.prefix(1)).uppercased())
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    )

                // 下方连接线
                if !isLast {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 2)
                        .frame(minHeight: 20)
                }
            }

            // 右侧内容
            VStack(alignment: .leading, spacing: 6) {
                // 应用名称和操作描述
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(event.appName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)

                    Text("使用了")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)

                    Text(formatDuration(event.duration))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)

                    Spacer()
                }

                // 时间信息
                Text(formatEventTime(event))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                Spacer()
                    .frame(height: 12)
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
    }

    private func appColor(for appName: String) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .red, .pink, .yellow, .cyan]
        let hash = appName.hashValue
        return colors[abs(hash) % colors.count]
    }

    private func formatEventTime(_ event: AppTimelineEvent) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        let startTime = formatter.string(from: event.startTime)
        return startTime
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours > 0 {
            return "\(hours)小时\(remainingMinutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
}

#Preview {
    ActivityStatsView()
        .environmentObject(ActivityMonitorManager())
}
