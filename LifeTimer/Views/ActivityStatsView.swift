//
//  ActivityStatsView.swift
//  LifeTimer
//
//  Created by Assistant on 2024
//

import SwiftUI
// 为 macOS 提供应用图标支持
#if os(macOS)
import AppKit
#endif

/// 活动统计视图
struct ActivityStatsView: View {
    @EnvironmentObject var activityMonitor: ActivityMonitorManager
    @State private var selectedDate = Date()
    // 数据加载状态与缓存
    @State private var isLoading = false
    @State private var overviewActiveTime: TimeInterval = 0
    @State private var overviewAppSwitches: Int = 0
    @State private var topApps: [AppUsageStats] = []
    @State private var recentSessions: [AppTimelineEvent] = []
    @State private var dataLoadingTask: Task<Void, Never>? = nil
    // 日期选择弹窗状态
    @State private var showDatePickerPopover = false

    var body: some View {
        // 简化后的单页内容
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if isLoading {
                    loadingView
                } else {
                    activityOverviewSection
                    recentActivitySection
                    topAppsSection
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            loadActivityDataAsync()
        }
        .onChange(of: selectedDate) { _ in
            loadActivityDataAsync()
        }
        .onReceive(activityMonitor.$isMonitoring) { _ in
            // 当监控状态改变时刷新数据
            loadActivityDataAsync()
        }
#if os(macOS)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // 当应用重新激活时刷新数据
            loadActivityDataAsync()
        }
#endif
        .toolbar {

            ToolbarItem(placement: .navigation) {
                // 日期显示组件（点击弹出日期选择器）
                Button {
                    showDatePickerPopover = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)

                        Text(formatSelectedDate(selectedDate))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showDatePickerPopover) {
                    VStack(alignment: .leading, spacing: 12) {
                        #if os(iOS)
                        DatePicker("选择日期", selection: $selectedDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                        #else
                        DatePicker("选择日期", selection: $selectedDate, displayedComponents: .date)
                        #endif

                        HStack(spacing: 8) {
                            Button {
                                selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                            } label: {
                                Label("前一天", systemImage: "chevron.left")
                            }
                            Button {
                                selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                            } label: {
                                Label("后一天", systemImage: "chevron.right")
                            }
                            Spacer()
                            Button("今天") {
                                selectedDate = Date()
                            }
                            .disabled(isToday(selectedDate))
                        }
                    }
                    .padding(12)
                    .frame(minWidth: 280)
                }
            }

            // // 中间：日期导航
            // ToolbarItem(placement: .primaryAction) {
            //     HStack(spacing: 8) {
            //         Button(action: {
            //             selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
            //         }) {
            //             Image(systemName: "chevron.left")
            //         }
            //         Button(action: {
            //             selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
            //         }) {
            //             Image(systemName: "chevron.right")
            //         }

            //         Button("今天") {
            //             selectedDate = Date()
            //         }
            //         .disabled(isToday(selectedDate))

            //     }
            // }
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
                    // .buttonStyle(.borderedProminent)
                    // .controlSize(.small)
                    // .font(.caption)
                }.padding(.horizontal,10)
            }
        }
        .onDisappear {
            // 取消未完成的加载任务
            dataLoadingTask?.cancel()
        }
    }

    // MARK: - 加载中视图
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
            Text("正在加载…")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - 数据加载（一次性并缓存到 State）

    private func loadActivityDataAsync() {
        isLoading = true
        dataLoadingTask?.cancel()
        dataLoadingTask = Task { @MainActor in
            // 在主线程串行调用，确保 ActivityMonitorManager 线程安全
            let overview = activityMonitor.getOverview(for: selectedDate)
            let apps = activityMonitor.getAppUsageStats(for: selectedDate)
            let systemEvents = activityMonitor.getSystemEvents(for: selectedDate)

            // 更新概览数据
            overviewActiveTime = overview.activeTime
            overviewAppSwitches = overview.appSwitches

            // 更新热门应用（Top 8）
            topApps = Array(apps.prefix(8))

            // 基于真实系统事件生成最近会话，最多显示最近 8 条
            recentSessions = buildSessions(from: systemEvents)
                .sorted { $0.startTime > $1.startTime }
            recentSessions = Array(recentSessions.prefix(8))

            isLoading = false
        }
    }



    // MARK: - 简化后的三个主板块

    private var activityOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isToday(selectedDate) ? "今日概览" : "\(formatSelectedDate(selectedDate)) 概览")
                .font(.headline)

            HStack(spacing: 12) {
                StatTile(title: "活跃时长", value: formatTime(overviewActiveTime), systemImage: "clock")
                StatTile(title: "应用切换", value: "\(overviewAppSwitches)", systemImage: "arrow.triangle.2.circlepath")
                StatTile(title: "热门应用", value: "\(topApps.count)", systemImage: "sparkles")
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.systemBackground))
    }

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近应用活动")
                .font(.headline)

            if recentSessions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text(activityMonitor.isMonitoring ? "暂无记录" : "未监控，无法记录活动")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(recentSessions.prefix(8).enumerated()), id: \.offset) { _, event in
                        RecentEventRow(event: event)
                            .environmentObject(activityMonitor.appCategoryManager)
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.systemBackground))
    }

    private var topAppsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("热门应用")
                .font(.headline)

            if topApps.isEmpty {
                Text("暂无数据")
                    .foregroundColor(.secondary)
            } else {
                ForEach(topApps, id: \.appName) { stat in
                    TopAppRow(app: stat, totalActive: overviewActiveTime)
                        .environmentObject(activityMonitor.appCategoryManager)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.systemBackground))
    }

    // 生产力模块已从主界面移除，如需可在后续版本以独立视图重新加入

    // MARK: - 辅助视图

    // 已移除快速应用统计（整合到主板块）

    // 已移除网站统计区块（后续如果需要，可新增“网站使用”独立视图）

    // 已移除生产力时间分布（不在此页展示）

    // 已移除建议区块（不在此页展示）

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

    // 已移除生产力颜色映射（不在此页展示）

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

    // MARK: - 从系统事件生成会话（无回退假数据）
    private func buildSessions(from systemEvents: [SystemEvent]) -> [AppTimelineEvent] {
        guard !systemEvents.isEmpty else { return [] }

        var sessions: [AppTimelineEvent] = []
        var currentApp: String?
        var currentBundleId: String?
        var appStartTime: Date?

        let sorted = systemEvents.sorted { $0.timestamp < $1.timestamp }
        for ev in sorted {
            switch ev.type {
            case .appActivated:
                guard let name = ev.appName else { break }
                if currentApp == name { break }
                if let last = currentApp, let start = appStartTime {
                    let duration = ev.timestamp.timeIntervalSince(start)
                    if duration > 10 {
                        sessions.append(AppTimelineEvent(appName: last, bundleId: currentBundleId, startTime: start, endTime: ev.timestamp, duration: duration))
                    }
                }
                currentApp = name
                currentBundleId = ev.bundleId
                appStartTime = ev.timestamp
            case .appTerminated, .systemSleep:
                if let last = currentApp, let start = appStartTime {
                    let duration = ev.timestamp.timeIntervalSince(start)
                    if duration > 10 {
                        sessions.append(AppTimelineEvent(appName: last, bundleId: currentBundleId, startTime: start, endTime: ev.timestamp, duration: duration))
                    }
                }
                currentApp = nil
                currentBundleId = nil
                appStartTime = nil
            default:
                break
            }
        }

        // 如果是今天，补齐正在使用的应用
        if Calendar.current.isDateInToday(selectedDate), let last = currentApp, let start = appStartTime {
            let now = Date()
            let duration = now.timeIntervalSince(start)
            if duration > 10 {
                sessions.append(AppTimelineEvent(appName: last, bundleId: currentBundleId, startTime: start, endTime: now, duration: duration))
            }
        }

        // 去重并按开始时间倒序返回
        let sortedSessions = sessions.sorted { $0.startTime > $1.startTime }
        return removeDuplicateEvents(sortedSessions)
    }

    // MARK: - 简化行与卡片组件

    private func formatHHmm(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    struct StatTile: View {
        let title: String
        let value: String
        let systemImage: String

        var body: some View {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(value)
                        .font(.system(size: 16, weight: .semibold))
                }
                Spacer()
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.06)))
        }
    }

    struct RecentEventRow: View {
        let event: AppTimelineEvent
        @EnvironmentObject var appCategoryManager: AppCategoryManager
        @State private var showCategoryPicker = false

        var body: some View {
            HStack(spacing: 12) {
                AppBadge(appName: event.appName, bundleId: event.bundleId, size: 22)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(event.appName)
                            .font(.subheadline)
                            .lineLimit(1)

                        let category = currentCategory(for: event.appName)
                        CategoryTag(text: category, color: ActivityStatsView.categoryColor(for: category))
                            .onTapGesture { showCategoryPicker = true }
                            .popover(isPresented: $showCategoryPicker) {
                                CategoryPickerPopover(current: category) { selection in
                                    updateCategory(for: event.appName, to: selection)
                                    showCategoryPicker = false
                                }
                            }
                    }

                    Text("\(formatRange(event.startTime, event.endTime)) · \(formatDuration(event.duration))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.05)))
        }

        private func formatRange(_ start: Date, _ end: Date) -> String {
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            return "\(f.string(from: start)) - \(f.string(from: end))"
        }

        private func formatDuration(_ duration: TimeInterval) -> String {
            let m = Int(duration) / 60
            let h = m / 60
            let mm = m % 60
            return h > 0 ? "\(h)h \(mm)m" : "\(mm)m"
        }

        private func currentCategory(for appName: String) -> String {
            if appCategoryManager.isIgnoredApp(appName) { return "忽略" }
            if appCategoryManager.isProductiveApp(appName) { return "生产力" }
            if appCategoryManager.isEntertainmentApp(appName) { return "娱乐" }
            return "其他"
        }

        private func updateCategory(for appName: String, to category: String) {
            switch category {
            case "忽略":
                appCategoryManager.addIgnoredApp(appName)
            case "生产力":
                appCategoryManager.addProductiveApp(appName)
            case "娱乐":
                appCategoryManager.addEntertainmentApp(appName)
            default:
                if let i = appCategoryManager.ignoredApps.firstIndex(of: appName) {
                    appCategoryManager.removeIgnoredApp(at: i)
                }
                if let j = appCategoryManager.productiveApps.firstIndex(of: appName) {
                    appCategoryManager.removeProductiveApp(at: j)
                }
                if let k = appCategoryManager.entertainmentApps.firstIndex(of: appName) {
                    appCategoryManager.removeEntertainmentApp(at: k)
                }
            }
        }
    }

    struct TopAppRow: View {
        let app: AppUsageStats
        let totalActive: TimeInterval
        @EnvironmentObject var appCategoryManager: AppCategoryManager
        @State private var showCategoryPicker = false

        private var ratio: Double {
            guard totalActive > 0 else { return 0 }
            return min(max(app.totalTime / totalActive, 0), 1)
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    AppBadge(appName: app.appName, bundleId: nil, size: 22)

                    Text(app.appName)
                        .font(.subheadline)
                        .lineLimit(1)

                    let category = currentCategory(for: app.appName)
                    CategoryTag(text: category, color: ActivityStatsView.categoryColor(for: category))
                        .onTapGesture { showCategoryPicker = true }
                        .popover(isPresented: $showCategoryPicker) {
                            CategoryPickerPopover(current: category) { selection in
                                updateCategory(for: app.appName, to: selection)
                                showCategoryPicker = false
                            }
                        }

                    Spacer()

                    Text(app.formattedTime)
                        .foregroundColor(.secondary)
                        .font(.caption)
                }

                HStack(spacing: 8) {
                    ZStack(alignment: .leading) {
                        // 背景条：占据可用的全部宽度
                        Capsule()
                            .fill(Color.secondary.opacity(0.15))
                            .frame(height: 6)

                        // 前景进度条：使用实际可用宽度计算比例
                        GeometryReader { geometry in
                            Capsule()
                                .fill(ActivityStatsView.appColor(for: app.appName))
                                .frame(width: max(4, geometry.size.width * ratio), height: 6)
                        }
                        .frame(height: 6)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text(ActivityStatsView.formatPercent(ratio))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.05)))
        }

        private func currentCategory(for appName: String) -> String {
            if appCategoryManager.isProductiveApp(appName) { return "生产力" }
            if appCategoryManager.isEntertainmentApp(appName) { return "娱乐" }
            return "其他"
        }

        private func updateCategory(for appName: String, to category: String) {
            switch category {
            case "生产力":
                appCategoryManager.addProductiveApp(appName)
            case "娱乐":
                appCategoryManager.addEntertainmentApp(appName)
            default:
                if let i = appCategoryManager.productiveApps.firstIndex(of: appName) {
                    appCategoryManager.removeProductiveApp(at: i)
                }
                if let j = appCategoryManager.entertainmentApps.firstIndex(of: appName) {
                    appCategoryManager.removeEntertainmentApp(at: j)
                }
            }
        }
    }

    /// 轻量级弹出式分类选择菜单（保持标签外观不变，点击标签时弹出）
    struct CategoryPickerPopover: View {
        let current: String
        let onSelect: (String) -> Void

        private let options = ["忽略", "生产力", "娱乐", "其他"]

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("调整分类")
                    .font(.caption)
                    .foregroundColor(.secondary)
                ForEach(options, id: \.self) { option in
                    Button {
                        onSelect(option)
                    } label: {
                        HStack {
                            Text(option)
                                .font(.system(size: 13))
                            Spacer()
                            if option == current {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .frame(minWidth: 180)
        }
    }

    // MARK: - 共享辅助：分类、颜色与百分比
    // 分类逻辑：仅三类（生产力、娱乐、其他）。此静态方法保留但不再使用旧的关键词推断。
    static func inferredCategory(for appName: String) -> String {
        // 由于无法在静态方法中访问 EnvironmentObject，这里保守返回“其他”。
        // 实际分类在各行组件中通过 activityMonitor.appCategoryManager 动态计算。
        return "其他"
    }

    static func categoryColor(for category: String) -> Color {
        switch category {
        case "忽略": return Color.red
        case "生产力": return Color.blue
        case "娱乐": return Color.orange
        default: return Color.gray
        }
    }

    static func appColor(for appName: String) -> Color {
        let palette: [Color] = [.blue, .purple, .green, .orange, .pink, .indigo, .teal, .cyan]
        let idx = abs(appName.hashValue) % palette.count
        return palette[idx]
    }

    static func formatPercent(_ value: Double) -> String {
        let pct = Int(round(value * 100))
        return "\(pct)%"
    }

    // MARK: - 图标提供者与徽章
    #if os(macOS)
    final class AppIconProvider {
        static let shared = AppIconProvider()
        private var cache: [String: NSImage] = [:]

        func icon(for appName: String) -> NSImage? {
            // 命中缓存
            if let img = cache[appName] { return img }

            // 1) 优先尝试从正在运行的应用中匹配（避免使用已弃用 API）
            if let runningApp = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == appName }),
               let bundleURL = runningApp.bundleURL {
                let image = NSWorkspace.shared.icon(forFile: bundleURL.path)
                cache[appName] = image
                return image
            }

            // 2) 常见安装路径回退：/Applications、/System/Applications、/Applications/Utilities、~/Applications
            let candidates: [String] = [
                "/Applications/\(appName).app",
                "/System/Applications/\(appName).app",
                "/Applications/Utilities/\(appName).app",
                "\(NSHomeDirectory())/Applications/\(appName).app"
            ]
            for path in candidates {
                if FileManager.default.fileExists(atPath: path) {
                    let image = NSWorkspace.shared.icon(forFile: path)
                    cache[appName] = image
                    return image
                }
            }

            // 未找到图标时返回 nil，让上层使用文字徽章回退
            return nil
        }

        // 可选：根据 bundle id 获取图标（如果后续支持在事件中记录 bundle id，可使用该方法）
        func iconForBundleId(_ bundleId: String) -> NSImage? {
            let key = "bundle:\(bundleId)"
            if let img = cache[key] { return img }
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                let image = NSWorkspace.shared.icon(forFile: url.path)
                cache[key] = image
                return image
            }
            return nil
        }
    }
    #endif

    struct AppBadge: View {
        let appName: String
        let bundleId: String?
        let size: CGFloat

        var body: some View {
            #if os(macOS)
            // 优先使用 bundleId 获取图标，其次使用应用名
            if let bid = bundleId, let nsImage = AppIconProvider.shared.iconForBundleId(bid) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(ActivityStatsView.appColor(for: appName).opacity(0.6), lineWidth: 1)
                    )
            } else if let nsImage = AppIconProvider.shared.icon(for: appName) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(ActivityStatsView.appColor(for: appName).opacity(0.6), lineWidth: 1)
                    )
            } else {
                fallbackBadge
            }
            #else
            fallbackBadge
            #endif
        }

        private var fallbackBadge: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(ActivityStatsView.appColor(for: appName))
                Text(String(appName.prefix(1)).uppercased())
                    .font(.caption2)
                    .foregroundColor(.white)
            }
            .frame(width: size, height: size)
        }
    }

    struct CategoryTag: View {
        let text: String
        let color: Color

        var body: some View {
            Text(text)
                .font(.caption2)
                .foregroundColor(color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(color.opacity(0.15))
                )
        }
    }

    // 保留去重逻辑，但去除调试与回退逻辑

    // 已移除时间轴回退生成逻辑（避免使用虚拟均分数据误导）

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

struct TimelineHourGroup {
    let hour: Int
    let hourStart: Date
    let events: [AppTimelineEvent]
}

// MARK: - 时间轴小时分组视图

    struct TimelineHourGroupView: View {
        let hourGroup: TimelineHourGroup
        let isCollapsed: Bool
        let onToggleCollapse: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 小时标题栏
            HStack {
                Button(action: onToggleCollapse) {
                    HStack(spacing: 8) {
                        Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)

                        Text(formatHourTitle(hourGroup.hourStart))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)

                        Text("(\(hourGroup.events.count)个事件)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)

                        Spacer()

                        Text(formatTotalDuration(hourGroup.events))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.08))
            .cornerRadius(8)

            // 事件列表（可折叠）
            if !isCollapsed {
                LazyVStack(spacing: 2) {
                    ForEach(Array(hourGroup.events.enumerated()), id: \.offset) { index, event in
                        TimelineEventRow(
                            event: event,
                            isFirst: index == 0,
                            isLast: index == hourGroup.events.count - 1,
                            previousEvent: index > 0 ? hourGroup.events[index - 1] : nil
                        )
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.03))
                )
                .padding(.top, 4)
            }
        }
    }

    private func formatHourTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:00"
        return formatter.string(from: date)
    }

    private func formatTotalDuration(_ events: [AppTimelineEvent]) -> String {
        let totalDuration = events.reduce(0) { $0 + $1.duration }
        let hours = Int(totalDuration) / 3600
        let minutes = Int(totalDuration) % 3600 / 60

        if hours > 0 {
            return "\(hours)h\(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - 新的时间轴事件数据结构

struct AppTimelineEvent {
    let appName: String
    let bundleId: String?
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
        .background(Color.systemBackground)
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

    @State private var collapsedHours: Set<Int> = Set()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 时间轴标题和统计信息
                timelineHeader

                if !events.isEmpty {
                    // 时间范围显示
                    timeRangeInfo

                    // 分组时间轴
                    LazyVStack(spacing: 8) {
                        ForEach(groupedEvents, id: \.hour) { hourGroup in
                            TimelineHourGroupView(
                                hourGroup: hourGroup,
                                isCollapsed: collapsedHours.contains(hourGroup.hour),
                                onToggleCollapse: {
                                    if collapsedHours.contains(hourGroup.hour) {
                                        collapsedHours.remove(hourGroup.hour)
                                    } else {
                                        collapsedHours.insert(hourGroup.hour)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .id(refreshTrigger ?? UUID()) // 使用refreshTrigger强制刷新
        .onAppear {
            initializeCollapsedState()
        }
    }

    // 按小时分组事件
    private var groupedEvents: [TimelineHourGroup] {
        let calendar = Calendar.current
        let now = Date()

        // 按小时分组
        let grouped = Dictionary(grouping: events) { event in
            calendar.component(.hour, from: event.startTime)
        }

        // 转换为TimelineHourGroup并排序
        return grouped.map { hour, hourEvents in
            let hourStart = calendar.dateInterval(of: .hour, for: hourEvents.first?.startTime ?? now)?.start ?? now
            return TimelineHourGroup(
                hour: hour,
                hourStart: hourStart,
                events: hourEvents.sorted { $0.startTime > $1.startTime }
            )
        }.sorted { $0.hour > $1.hour } // 按小时倒序排列
    }

    // 初始化折叠状态
    private func initializeCollapsedState() {
        let calendar = Calendar.current
        let now = Date()
        let oneHourAgo = calendar.date(byAdding: .hour, value: -1, to: now) ?? now

        // 默认折叠1小时之前的数据
        collapsedHours = Set(groupedEvents.compactMap { group in
            if group.hourStart < oneHourAgo {
                return group.hour
            }
            return nil
        })
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
