//
//  CalendarView.swift
//  LifeTimer
//
//  Created by Developer on 2024.
//

import SwiftUI
import Foundation

// MARK: - 跨平台屏幕尺寸获取
private func getScreenWidth() -> CGFloat {
    #if os(iOS)
    return UIScreen.main.bounds.width
    #elseif os(macOS)
    return NSScreen.main?.frame.width ?? 1200
    #else
    return 800 // 默认值
    #endif
}

// MARK: - 事件位置缓存管理器
class EventPositionCache: ObservableObject {
    private var cache: [String: (y: CGFloat, height: CGFloat)] = [:]
    private let calendar = Calendar.current

    func getPosition(for event: PomodoroEvent, hourHeight: CGFloat) -> (y: CGFloat, height: CGFloat) {
        // 缓存键包含时间信息，确保时间更新后缓存失效
        let startTimeKey = Int(event.startTime.timeIntervalSince1970)
        let endTimeKey = Int(event.endTime.timeIntervalSince1970)
        let key = "\(event.id.uuidString)-\(startTimeKey)-\(endTimeKey)-\(Int(hourHeight * 100))"

        if let cached = cache[key] {
            #if DEBUG
            // print("🕐 EventPositionCache: \(event.title) [缓存命中] y=\(cached.0), height=\(cached.1)")
            #endif
            return cached
        }

        // 缓存未命中，重新计算
        let startHour = calendar.component(.hour, from: event.startTime)
        let startMinute = calendar.component(.minute, from: event.startTime)
        let endHour = calendar.component(.hour, from: event.endTime)
        let endMinute = calendar.component(.minute, from: event.endTime)
        let startY = CGFloat(startHour) * hourHeight + CGFloat(startMinute) * hourHeight / 60
        let endY = CGFloat(endHour) * hourHeight + CGFloat(endMinute) * hourHeight / 60
        let height = endY - startY
        let finalHeight = max(20, height)

        let result = (startY, finalHeight)
        cache[key] = result

        #if DEBUG
        print("🕐 EventPositionCache: \(event.title) [缓存未命中]")
        print("  开始时间: \(event.startTime) -> \(startHour):\(startMinute)")
        print("  结束时间: \(event.endTime) -> \(endHour):\(endMinute)")
        print("  hourHeight: \(hourHeight)")
        print("  startY: \(startY), endY: \(endY), 计算高度: \(height)")
        print("  最终位置: y=\(startY), height=\(finalHeight)")
        print("  缓存键: \(key)")
        #endif

        return result
    }

    func clearCache() {
        cache.removeAll()
        #if DEBUG
        print("🕐 EventPositionCache: 清除所有缓存")
        #endif
    }

    func getCacheStats() -> (count: Int, keys: [String]) {
        return (cache.count, Array(cache.keys))
    }
}
import Combine
#if canImport(AppKit)
import AppKit
#endif

// 导入事件模型
// 注意：确保EventModel.swift在同一个target中

// 确保PomodoroEvent类型可用
typealias Event = PomodoroEvent

// MARK: - 当前时间指示器组件

/// 日视图当前时间指示器 - 红色水平线
struct CurrentTimeIndicator: View {
    let hourHeight: CGFloat
    let containerWidth: CGFloat
    @State private var currentTime = Date()
    @State private var timer: Timer?

    private let calendar = Calendar.current

    var body: some View {
        let position = calculateTimePosition()

        HStack(spacing: 0) {
            // 时间标签
            Text(timeFormatter.string(from: currentTime))
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.red)
                .frame(width: 50, alignment: .trailing)
                .padding(.trailing, 4)
            // 红色圆点
            Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
            // 红色水平线
            Rectangle()
                .fill(Color.red)
                .frame(height: 1)
                .frame(maxWidth: .infinity)
        }
        .position(x: containerWidth / 2, y: position)
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }

    private func calculateTimePosition() -> CGFloat {
        let hour = calendar.component(.hour, from: currentTime)
        let minute = calendar.component(.minute, from: currentTime)
        return CGFloat(hour) * hourHeight + CGFloat(minute) * hourHeight / 60
    }

    private func startTimer() {
        // 每分钟更新一次时间
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            currentTime = Date()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

/// 周视图当前时间指示器 - 红色圆点和横线
struct WeekCurrentTimeIndicator: View {
    let hourHeight: CGFloat
    let date: Date
    let weekDates: [Date]
    let containerWidth: CGFloat
    @State private var currentTime = Date()
    @State private var timer: Timer?

    private let calendar = Calendar.current

    // 检查是否为今天
    private var isToday: Bool {
        calendar.isDate(date, inSameDayAs: currentTime)
    }

    // 计算当天在周视图中的索引
    private var todayIndex: Int? {
        weekDates.firstIndex { calendar.isDate($0, inSameDayAs: currentTime) }
    }

    var body: some View {
        if isToday, let todayIndex = todayIndex {
            let position = calculateTimePosition()
            let dayWidth = containerWidth / CGFloat(weekDates.count)
            let dotX = CGFloat(todayIndex) * dayWidth

            HStack(spacing: 0) {
                // 时间标签
                Text(timeFormatter.string(from: currentTime))
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.red)
                    .frame(width: 50, alignment: .trailing)
                    .padding(.trailing, 4)

                // 红色水平线跨越整个周视图
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.red)
                        .frame(height: 1)
                        .frame(width: containerWidth)

                    // 红色圆点在当天位置
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .offset(x: dotX)
                }
            }
            .position(x: 50 + containerWidth / 2, y: position)
            .onAppear {
                startTimer()
            }
            .onDisappear {
                stopTimer()
            }
        }
    }

    private func calculateTimePosition() -> CGFloat {
        let hour = calendar.component(.hour, from: currentTime)
        let minute = calendar.component(.minute, from: currentTime)
        return CGFloat(hour) * hourHeight + CGFloat(minute) * hourHeight / 60
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }

    private func startTimer() {
        // 每分钟更新一次时间
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            currentTime = Date()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

/// 周视图时间指示器覆盖层 - 跨越整个周视图宽度
struct WeekTimeIndicatorOverlay: View {
    let hourHeight: CGFloat
    let weekDates: [Date]
    let containerWidth: CGFloat
    @State private var currentTime = Date()
    @State private var timer: Timer?

    private let calendar = Calendar.current

    // 计算当天在周视图中的索引
    private var todayIndex: Int? {
        weekDates.firstIndex { calendar.isDate($0, inSameDayAs: currentTime) }
    }

    // 检查今天是否在当前周视图中
    private var isTodayInWeek: Bool {
        todayIndex != nil
    }

    var body: some View {
        if isTodayInWeek, let todayIndex = todayIndex {
            let position = calculateTimePosition()
            let timeLabelsWidth: CGFloat = 60
            let weekGridWidth = containerWidth - timeLabelsWidth
            let dayWidth = weekGridWidth / CGFloat(weekDates.count)
            let dotX = timeLabelsWidth + CGFloat(todayIndex) * dayWidth

            HStack(spacing: 0) {
                // 时间标签
                Text(timeFormatter.string(from: currentTime))
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.red)
                    .frame(width: 50, alignment: .trailing)
                    .padding(.trailing, 4)

                // 红色水平线跨越整个周事件网格
                Rectangle()
                    .fill(Color.red)
                    .frame(height: 1)
                    .frame(width: weekGridWidth)
            }
            .position(x: containerWidth / 2, y: position)

            // 红色圆点在当天位置
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .position(x: dotX, y: position)
                .onAppear {
                    startTimer()
                }
                .onDisappear {
                    stopTimer()
                }
        }
    }

    private func calculateTimePosition() -> CGFloat {
        let hour = calendar.component(.hour, from: currentTime)
        let minute = calendar.component(.minute, from: currentTime)
        return CGFloat(hour) * hourHeight + CGFloat(minute) * hourHeight / 60
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            currentTime = Date()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

enum CalendarViewMode: String, CaseIterable {
    case day = "日"
    case week = "周"
    case month = "月"

    var icon: String {
        switch self {
        case .day: return "calendar.day.timeline.left"
        case .week: return "calendar"
        case .month: return "calendar.month"
        }
    }
}

// MARK: - 搜索结果侧边栏
struct SearchResultsSidebar: View {
    let searchResults: [PomodoroEvent]
    let onEventSelected: (PomodoroEvent) -> Void
    let onClose: () -> Void

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("搜索结果")
                    .font(.headline)
                    .fontWeight(.medium)

                Spacer()

                Text("\(searchResults.count) 个结果")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .help("关闭搜索")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.systemBackground)

            Divider()

            // 搜索结果列表
            if searchResults.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)

                    Text("未找到匹配的事件")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.systemBackground)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(searchResults) { event in
                            SearchResultRow(
                                event: event,
                                dateFormatter: dateFormatter,
                                timeFormatter: timeFormatter,
                                onTap: { onEventSelected(event) }
                            )
                        }
                    }
                }
                .background(Color.systemBackground)
            }
        }
        .frame(width: min(280, max(250, getScreenWidth() * 0.4)))
        .background(GlassEffectBackground())
    }
}

// MARK: - 搜索结果行
struct SearchResultRow: View {
    let event: PomodoroEvent
    let dateFormatter: DateFormatter
    let timeFormatter: DateFormatter
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                // 事件类型图标
                Image(systemName: event.type.icon)
                    .font(.system(size: 14))
                    .foregroundColor(event.type.color)
                    .frame(width: 16, height: 16)

                // 事件标题
                Text(event.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)

                Spacer()

                // 事件类型标签
                Text(event.type.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(event.type.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(event.type.color.opacity(0.1))
                    .cornerRadius(4)
            }

            // 时间信息
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Text(dateFormatter.string(from: event.startTime))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Text("•")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Text("\(timeFormatter.string(from: event.startTime)) - \(timeFormatter.string(from: event.endTime))")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Spacer()

                // 持续时间
                Text(event.formattedDuration)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - 可重用的日历导航工具栏组件
struct CalendarNavigationToolbar: View {
    let viewMode: CalendarViewMode
    @Binding var selectedDate: Date

    private let calendar = Calendar.current

    // 根据视图模式计算是否为今天
    private var isToday: Bool {
        switch viewMode {
        case .day:
            return calendar.isDateInToday(selectedDate)
        case .week:
            let today = Date()
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate),
                  let todayWeekInterval = calendar.dateInterval(of: .weekOfYear, for: today) else {
                return false
            }
            return weekInterval.start == todayWeekInterval.start
        case .month:
            let today = Date()
            return calendar.isDate(selectedDate, equalTo: today, toGranularity: .month)
        }
    }

    var body: some View {
        HStack {
            Spacer()
            // 上一个时间段按钮
            Button(action: previousPeriod) {
                Image(systemName: "chevron.left")
            }
            .controlSize(.small)

            // 今天按钮
            Button(action: goToToday) {
                Text("今天")
            }
            .controlSize(.small)
            .disabled(isToday)

            // 下一个时间段按钮
            Button(action: nextPeriod) {
                Image(systemName: "chevron.right")
            }
            .controlSize(.small)
        }
    }

    // MARK: - 导航方法

    /// 跳转到今天
    private func goToToday() {
        selectedDate = Date()
    }

    /// 上一个时间段
    private func previousPeriod() {
        switch viewMode {
        case .day:
            selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        case .week:
            selectedDate = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedDate) ?? selectedDate
        case .month:
            selectedDate = calendar.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
        }
    }

    /// 下一个时间段
    private func nextPeriod() {
        switch viewMode {
        case .day:
            selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        case .week:
            selectedDate = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate) ?? selectedDate
        case .month:
            selectedDate = calendar.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
        }
    }
}

struct CalendarView: View {
    @EnvironmentObject var eventManager: EventManager
    @EnvironmentObject var activityMonitor: ActivityMonitorManager
    @State private var selectedDate = Date()
    @State private var currentViewMode: CalendarViewMode = .day
    @State private var selectedEvent: PomodoroEvent?
    @State private var showingAddEvent = false
    @State private var draggedEvent: PomodoroEvent?
    @State private var dragOffset: CGSize = .zero
    @State private var searchText = ""

    // 搜索相关状态
    @State private var searchResults: [PomodoroEvent] = []
    @State private var showingSearchResults = false
    @State private var highlightedEventId: UUID?
    @State private var searchTask: Task<Void, Never>? // 搜索任务管理

    // MARK: - 性能优化：预加载和缓存管理
    @State private var preloadTask: Task<Void, Never>?

    private let calendar = Calendar.current
    
    var body: some View {
        GeometryReader { rootGeo in
            HStack(spacing: 0) {
                // 主要内容区域
                Group {
                    switch currentViewMode {
                        case .day:
                            DayView(
                                selectedDate: $selectedDate,
                                selectedEvent: $selectedEvent,
                                showingAddEvent: $showingAddEvent,
                                draggedEvent: $draggedEvent,
                                dragOffset: $dragOffset,
                                highlightedEventId: $highlightedEventId
                            )
                            .environmentObject(eventManager)
                            .environmentObject(activityMonitor)
                            .background(Color.systemBackground)

                        case .week:
                            WeekView(
                                selectedDate: $selectedDate,
                                highlightedEventId: $highlightedEventId
                            )
                            .environmentObject(eventManager)
                            .environmentObject(activityMonitor)
                            .background(Color.systemBackground)

                        case .month:
                            MonthView(
                                viewMode: currentViewMode,
                                selectedDate: $selectedDate,
                                highlightedEventId: $highlightedEventId
                            )
                            .environmentObject(eventManager)
                            .environmentObject(activityMonitor)
                            .background(Color.systemBackground)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // 搜索结果侧边栏
                if showingSearchResults {
                    SearchResultsSidebar(
                        searchResults: searchResults,
                        onEventSelected: handleEventSelection,
                        onClose: closeSearchResults
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: showingSearchResults)
                }
                                let isCompact = rootGeo.size.width < 800 || (rootGeo.size.width < 1000 && rootGeo.size.height > rootGeo.size.width)
                let sidebarWidth = isCompact ? min(280, max(200, rootGeo.size.width * 0.35)) : 240

                if (!isCompact || rootGeo.size.width > 580) && !showingSearchResults {
                    switch currentViewMode {
                    case .day:
                        VStack(spacing: 0) {
                            MiniCalendarView(viewMode: .day, selectedDate: $selectedDate)
                                .padding(isCompact ? 8 : 16)
                                .transition(.opacity.combined(with: .move(edge: .trailing)))

                            Divider()

                            DayStatsPanel(selectedDate: $selectedDate)
                                .environmentObject(eventManager)
                                .environmentObject(activityMonitor)
                                .frame(maxHeight: .infinity)
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        }
                        .padding(.top, 48)
                        .frame(width: sidebarWidth)
                        .background(GlassEffectBackground())
                        .ignoresSafeArea(.container, edges: .top)
                        .animation(.easeInOut(duration: 0.3), value: selectedDate)

                    case .week:
                        VStack(spacing: 0) {
                            MiniCalendarView(viewMode: .week, selectedDate: $selectedDate)
                                .padding(isCompact ? 8 : 16)
                                .transition(.opacity.combined(with: .move(edge: .trailing)))

                            Divider()

                            WeekSidebarStats(selectedDate: $selectedDate)
                                .environmentObject(eventManager)
                                .environmentObject(activityMonitor)
                                .frame(maxHeight: .infinity)
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        }
                        .padding(.top, 48)
                        .frame(width: sidebarWidth)
                        .background(GlassEffectBackground())
                        .ignoresSafeArea(.container, edges: .top)
                        .animation(.easeInOut(duration: 0.3), value: selectedDate)

                    case .month:
                        VStack(spacing: 0) {
                            MiniCalendarView(viewMode: .month, selectedDate: $selectedDate)
                                .padding(isCompact ? 8 : 16)
                                .transition(.opacity.combined(with: .move(edge: .trailing)))

                            Divider()

                            MonthSidebarStats(selectedDate: $selectedDate)
                                .environmentObject(eventManager)
                                .environmentObject(activityMonitor)
                                .frame(maxHeight: .infinity)
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        }
                        .padding(.top, 48)
                        .frame(width: sidebarWidth)
                        .background(GlassEffectBackground())
                        .ignoresSafeArea(.container, edges: .top)
                        .animation(.easeInOut(duration: 0.3), value: selectedDate)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddEvent) {
            EventEditView(event: PomodoroEvent(
                title: "新事件",
                startTime: selectedDate,
                endTime: Calendar.current.date(byAdding: .hour, value: 1, to: selectedDate) ?? selectedDate,
                type: .custom
            ), onSave: { _ in
                showingAddEvent = false
            }, onDelete: {
                showingAddEvent = false
            })
                .environmentObject(eventManager)
        }
        .toolbar {
            // 左侧：添加事件按钮
            ToolbarItemGroup(placement: .navigation) {
                Button(action: {
                    showingAddEvent = true
                }) {
                    Image(systemName: "plus")
                }
                .help("添加事件")
            }

            // 中间：完整的工具栏布局
            ToolbarItemGroup(placement: .principal) {
                HStack {
                    // 视图模式选择器
                    Picker("视图模式", selection: $currentViewMode) {
                        ForEach(CalendarViewMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: min(180, getScreenWidth() * 0.3))
                    .onChange(of: currentViewMode) { newMode in
                        // 视图模式切换时触发预加载
                        triggerPreloading(for: newMode)
                    }

                }
            }
        }
        // 使用SwiftUI原生的.searchable修饰符
        .searchable(text: $searchText, placement: .toolbar, prompt: "搜索事件")
        .onSubmit(of: .search) {
            Task {
                await performSearchAsync()
            }
        }
        .onChange(of: searchText) { newValue in
            // 取消之前的搜索任务
            searchTask?.cancel()

            if newValue.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                closeSearchResults()
            } else {
                // 异步实时搜索：防抖处理，避免频繁搜索
                searchTask = Task {
                    // 防抖延迟300ms
                    try? await Task.sleep(nanoseconds: 300_000_000)

                    // 检查任务是否被取消
                    guard !Task.isCancelled else { return }

                    await performSearchAsync()
                }
            }
        }
        .onAppear {
            // 初始化时触发预加载
            triggerPreloading(for: currentViewMode)
        }
        .onChange(of: selectedDate) { newDate in
            // 日期切换时触发预加载
            triggerPreloading(for: currentViewMode, selectedDate: newDate)
        }
        .onDisappear {
            // 清理预加载任务和搜索任务
            preloadTask?.cancel()
            preloadTask = nil
            searchTask?.cancel()
            searchTask = nil
        }
    }

    // MARK: - 性能优化：智能预加载机制

    /// 触发预加载
    private func triggerPreloading(for viewMode: CalendarViewMode, selectedDate: Date? = nil) {
        // 取消之前的预加载任务
        preloadTask?.cancel()

        let targetDate = selectedDate ?? self.selectedDate

        preloadTask = Task {
            await performSmartPreloading(for: viewMode, date: targetDate)
        }
    }

    /// 执行智能预加载
    @MainActor
    private func performSmartPreloading(for viewMode: CalendarViewMode, date: Date) async {
        let preloadDates = generatePreloadDates(for: viewMode, around: date)

        // 预热EventManager缓存
        eventManager.warmupCache(for: preloadDates)

        // 在后台线程预加载数据，避免阻塞UI
        await Task.detached { [eventManager, activityMonitor] in
            // 预加载事件数据
            let _ = eventManager.eventsForDates(preloadDates)

            // 预加载活动监控数据（仅在macOS上）
            #if canImport(Cocoa)
            let _ = activityMonitor.getAppUsageStatsForDates(preloadDates)
            let _ = activityMonitor.getOverviewForDates(preloadDates)
            #endif
        }.value
    }

    /// 生成预加载日期列表
    private func generatePreloadDates(for viewMode: CalendarViewMode, around date: Date) -> [Date] {
        var dates: [Date] = []

        switch viewMode {
        case .day:
            // 日视图：预加载前后3天
            for i in -3...3 {
                if let preloadDate = calendar.date(byAdding: .day, value: i, to: date) {
                    dates.append(preloadDate)
                }
            }

        case .week:
            // 周视图：预加载当前周和前后各一周
            for weekOffset in -1...1 {
                if let weekDate = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: date),
                   let weekInterval = calendar.dateInterval(of: .weekOfYear, for: weekDate) {

                    for dayOffset in 0..<7 {
                        if let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: weekInterval.start) {
                            dates.append(dayDate)
                        }
                    }
                }
            }

        case .month:
            // 月视图：预加载当前月和前后各一个月
            for monthOffset in -1...1 {
                if let monthDate = calendar.date(byAdding: .month, value: monthOffset, to: date),
                   let monthInterval = calendar.dateInterval(of: .month, for: monthDate) {

                    let numberOfDays = calendar.range(of: .day, in: .month, for: monthDate)?.count ?? 30
                    for dayOffset in 0..<numberOfDays {
                        if let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: monthInterval.start) {
                            dates.append(dayDate)
                        }
                    }
                }
            }
        }

        return dates
    }

    // MARK: - 搜索相关方法

    /// 执行搜索（同步版本，用于回车键触发）
    private func performSearch() {
        let trimmedText = searchText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            closeSearchResults()
            return
        }

        searchResults = eventManager.searchEvents(trimmedText)
        showingSearchResults = true
    }

    /// 执行搜索（异步版本，用于实时搜索）
    @MainActor
    private func performSearchAsync() async {
        let trimmedText = searchText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            closeSearchResults()
            return
        }

        #if DEBUG
        let startTime = CFAbsoluteTimeGetCurrent()
        #endif

        // 在后台线程执行搜索
        let results = await Task.detached { [eventManager] in
            return eventManager.searchEvents(trimmedText)
        }.value

        // 检查任务是否被取消
        guard !Task.isCancelled else { return }

        // 在主线程更新UI
        searchResults = results
        showingSearchResults = true

        #if DEBUG
        let endTime = CFAbsoluteTimeGetCurrent()
        print("🔍 CalendarView: 搜索完成 '\(trimmedText)'，耗时: \(String(format: "%.2f", (endTime - startTime) * 1000))ms，结果: \(results.count) 个")
        #endif
    }

    /// 关闭搜索结果
    private func closeSearchResults() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showingSearchResults = false
        }
        searchResults = []
        highlightedEventId = nil
    }

    /// 处理事件选择
    private func handleEventSelection(_ event: PomodoroEvent) {
        // 跳转到事件对应的日期
        selectedDate = event.startTime

        // 高亮显示选中的事件
        highlightedEventId = event.id

        // 500毫秒后取消高亮
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.1)) {
                highlightedEventId = nil
            }
        }

        // 保持搜索结果侧边栏显示状态，不自动关闭
        // 用户可以通过点击关闭按钮或清空搜索框来手动关闭
    }
}

// MARK: - 日视图
struct DayView: View {
    @Binding var selectedDate: Date
    @Binding var selectedEvent: PomodoroEvent?
    @Binding var showingAddEvent: Bool
    @Binding var draggedEvent: PomodoroEvent?
    @Binding var dragOffset: CGSize
    @Binding var highlightedEventId: UUID?
    @EnvironmentObject var eventManager: EventManager
    @EnvironmentObject var activityMonitor: ActivityMonitorManager
    private let calendar = Calendar.current
    private let hourHeight: CGFloat = 60

    // 共享的事件位置缓存管理器
    @StateObject private var sharedPositionCache = EventPositionCache()
    
    var body: some View {
        GeometryReader { geo in
            // 智能布局检测：考虑屏幕宽度和设备类型
            let isCompact = geo.size.width < 800 || (geo.size.width < 1000 && geo.size.height > geo.size.width)
            let sidebarWidth = isCompact ? min(280, max(200, geo.size.width * 0.35)) : 240

            HStack(spacing: 0) {
                // 左侧时间轴区域
                TimelineView(
                    selectedDate: $selectedDate,
                    selectedEvent: $selectedEvent,
                    showingAddEvent: $showingAddEvent,
                    draggedEvent: $draggedEvent,
                    dragOffset: $dragOffset,
                    hourHeight: hourHeight,
                    highlightedEventId: $highlightedEventId,
                    sharedPositionCache: sharedPositionCache
                )
                .environmentObject(eventManager)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.systemBackground)

                // 右侧面板移除，改为 CalendarView 顶层 overlay
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    // 清除共享位置缓存的辅助方法
    private func clearPositionCache() {
        sharedPositionCache.clearCache()
    }
}

// MARK: - 时间轴视图
struct TimelineView: View {
    @Binding var selectedDate: Date
    @Binding var selectedEvent: PomodoroEvent?
    @Binding var showingAddEvent: Bool
    @Binding var draggedEvent: PomodoroEvent?
    @Binding var dragOffset: CGSize
    let hourHeight: CGFloat
    @Binding var highlightedEventId: UUID?
    @ObservedObject var sharedPositionCache: EventPositionCache

    @EnvironmentObject var eventManager: EventManager
    @State private var selectionStart: CGPoint?
    @State private var selectionEnd: CGPoint?
    @State private var isSelecting = false
    
    private let calendar = Calendar.current
    private let hours = Array(0...23)
    
    // MARK: - 性能优化：缓存计算属性
    @State private var eventsForDay: [PomodoroEvent] = []

    // 加载指定日期的事件数据的纯函数
    private func loadEventsForDate(_ date: Date) -> [PomodoroEvent] {
        let events = eventManager.eventsForDate(date)

        // 调试信息
        #if DEBUG
        print("📅 DayView: 加载日期 \(date) 的事件，找到 \(events.count) 个事件")
        for event in events {
            print("  - \(event.title) (\(event.type.displayName)) - 时间: \(event.startTime) 到 \(event.endTime)")
        }
        #endif

        return events
    }

    // 性能优化：缓存事件布局信息，避免拖拽时重复计算
    @State private var cachedEventLayoutInfo: [(event: PomodoroEvent, column: Int, totalColumns: Int)] = []
    @State private var cachedLayoutEventsHash: Int = 0
    @State private var cachedLayoutDate: Date?

    // 修复：直接计算布局，暂时禁用有问题的缓存机制
    private var eventLayoutInfo: [(event: PomodoroEvent, column: Int, totalColumns: Int)] {
        // 直接从数据源获取事件并计算布局
        let events = eventManager.eventsForDate(selectedDate)
        let layoutInfo = computeEventColumns(events: events)

        // 调试信息
        #if DEBUG
        print("📊 DayView: 直接计算事件布局")
        print("📊 DayView: 日期: \(selectedDate)")
        print("📊 DayView: 输入事件数量: \(events.count)")
        print("📊 DayView: 输出布局信息数量: \(layoutInfo.count)")
        for (i, info) in layoutInfo.enumerated() {
            let (event, column, totalColumns) = info
            print("  事件\(i): \(event.title) - 列\(column)/\(totalColumns)")
        }
        #endif

        return layoutInfo
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 日期显示区域（只显示日期信息，不显示导航按钮）
            DateDisplayOnly(selectedDate: $selectedDate)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // 时间轴内容
            GeometryReader { geometry in
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        // 时间标签和网格线
                        VStack(spacing: 0) {
                            ForEach(hours, id: \.self) { (hour: Int) in
                                HStack(alignment: .top) {
                                    // 时间标签
                                    Text(String(format: "%02d:00", hour))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 50, alignment: .trailing)

                                    // 网格线 - 00:00 不显示横线，因为上面已经有 Divider
                                    if hour != 0 {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(height: 1)
                                    } else {
                                        // 00:00 位置不显示横线，但保持布局空间
                                        Rectangle()
                                            .fill(Color.clear)
                                            .frame(height: 1)
                                    }
                                }
                                .frame(height: hourHeight, alignment: .top)
                            }
                        }

                    // 事件块（并列排布）- 使用正确的缓存机制
                    // 调试信息
                    #if DEBUG
                    let _ = print("🎨 DayView: 准备渲染 \(eventLayoutInfo.count) 个事件块")
                    #endif

                    ForEach(eventLayoutInfo, id: \.0.id) { info in
                        let (event, column, totalColumns) = info
                        EventBlock(
                            event: event,
                            selectedEvent: $selectedEvent,
                            draggedEvent: $draggedEvent,
                            dragOffset: $dragOffset,
                            hourHeight: hourHeight,
                            selectedDate: selectedDate,
                            column: column,
                            totalColumns: totalColumns,
                            containerWidth: geometry.size.width-50, // 使用TimelineView本身的宽度
                            highlightedEventId: $highlightedEventId,
                            positionCache: sharedPositionCache
                        )
                        .id(event.id) // 确保正确的视图标识，提高更新性能
                        .drawingGroup() // 将事件块渲染为单个图层，提高性能
                    }
                
                // 当前时间指示器（只在今天显示）
                if calendar.isDateInToday(selectedDate) {
                    CurrentTimeIndicator(
                        hourHeight: hourHeight,
                        containerWidth: geometry.size.width
                    )
                }

                // 选择区域覆盖层
                if isSelecting, let start = selectionStart, let end = selectionEnd {
                    SelectionOverlay(start: start, end: end)
                }
            }
            .padding(.leading, 0)
            .contentShape(Rectangle())
            .onTapGesture { location in
                // 简化的点击处理：点击空白区域取消选中事件
                selectedEvent = nil
            }
            .gesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { value in
                        // 改进拖拽体验：只在事件区域内开始选择
                        let leftPadding: CGFloat = 60

                        if selectionStart == nil {
                            // 只有在事件区域内点击才开始选择
                            if value.startLocation.x > leftPadding {
                                selectionStart = value.startLocation
                                isSelecting = true
                            }
                        }

                        // 更新选择结束位置
                        if isSelecting {
                            selectionEnd = value.location
                        }
                    }
                    .onEnded { value in
                        if isSelecting {
                            createEventFromSelection()
                        }
                        resetSelection()
                    }
            )
            }
        }
        }
        .onAppear {
            // 视图出现时清除所有缓存，确保数据是最新的
            clearAllCaches()
            // 初始化时加载事件数据
            eventsForDay = loadEventsForDate(selectedDate)

            #if DEBUG
            print("📅 TimelineView: 视图出现，清除所有缓存并加载事件数据")
            #endif
        }
        .onChange(of: selectedDate) { newDate in
            // 日期变化时清除所有缓存
            clearAllCaches()
            // 当选中日期变化时重新加载事件数据
            eventsForDay = loadEventsForDate(newDate)

            #if DEBUG
            print("📅 TimelineView: 日期变化，清除所有缓存并重新加载事件数据")
            #endif
        }
        .onChange(of: eventManager.events.count) { _ in
            // 事件数量变化时清除所有缓存
            clearAllCaches()

            #if DEBUG
            print("📅 DayView: 事件数量变化，清除所有缓存")
            #endif
        }
    }



    // --- 新增：事件并列排布算法 ---
    private func computeEventColumns(events: [PomodoroEvent]) -> [(PomodoroEvent, Int, Int)] {
        #if DEBUG
        print("🔧 computeEventColumns: 开始计算 \(events.count) 个事件的布局")
        for (i, event) in events.enumerated() {
            print("  输入事件\(i): \(event.title) - \(event.startTime) 到 \(event.endTime)")
        }
        #endif

        // 按开始时间排序
        let sorted = events.sorted { $0.startTime < $1.startTime }
        var result: [(PomodoroEvent, Int, Int)] = []
        var active: [(PomodoroEvent, Int)] = [] // (event, column)

        for event in sorted {
            // 计算当前事件的视觉位置（考虑最小高度）
            let eventVisualBounds = getEventVisualBounds(event)

            // 移除已结束的事件（考虑视觉边界而不仅仅是时间边界）
            active.removeAll { activeEvent in
                let activeVisualBounds = getEventVisualBounds(activeEvent.0)
                return activeVisualBounds.maxY <= eventVisualBounds.minY
            }

            // 查找可用列
            let usedColumns = Set(active.map { $0.1 })
            var col = 0
            while usedColumns.contains(col) { col += 1 }
            active.append((event, col))
            // 计算当前重叠的总列数
            let overlapCount = active.count
            result.append((event, col, overlapCount))
        }

        // 由于每个事件的 totalColumns 需要是与其重叠区间的最大 overlapCount，需再遍历修正
        var eventToMaxCol: [UUID: Int] = [:]
        for (event, _, _) in result {
            let eventVisualBounds = getEventVisualBounds(event)
            let overlapping = result.filter { otherEvent in
                let otherVisualBounds = getEventVisualBounds(otherEvent.0)
                // 检查视觉边界是否重叠
                return eventVisualBounds.minY < otherVisualBounds.maxY &&
                       eventVisualBounds.maxY > otherVisualBounds.minY
            }
            let maxCol = overlapping.map { $0.2 }.max() ?? 1
            eventToMaxCol[event.id] = maxCol
        }

        let finalResult = result.map { (event, col, _) in
            (event, col, eventToMaxCol[event.id] ?? 1)
        }

        #if DEBUG
        print("🔧 computeEventColumns: 计算完成，输出 \(finalResult.count) 个布局信息")
        for (i, info) in finalResult.enumerated() {
            let (event, column, totalColumns) = info
            print("  输出事件\(i): \(event.title) - 列\(column)/\(totalColumns)")
        }
        #endif

        return finalResult
    }

    // 计算事件的视觉边界（考虑最小高度）
    private func getEventVisualBounds(_ event: PomodoroEvent) -> (minY: CGFloat, maxY: CGFloat) {
        let startHour = calendar.component(.hour, from: event.startTime)
        let startMinute = calendar.component(.minute, from: event.startTime)
        let endHour = calendar.component(.hour, from: event.endTime)
        let endMinute = calendar.component(.minute, from: event.endTime)
        let startY = CGFloat(startHour) * hourHeight + CGFloat(startMinute) * hourHeight / 60
        let endY = CGFloat(endHour) * hourHeight + CGFloat(endMinute) * hourHeight / 60
        let actualHeight = endY - startY
        let visualHeight = max(20, actualHeight) // 最小高度20
        return (startY, startY + visualHeight)
    }
    // --- END ---
    
    private func createEventFromSelection() {
        guard let start = selectionStart, let end = selectionEnd else { return }

        // 修复坐标系问题：考虑左侧时间标签的偏移
        // TimelineView 有 .padding(.leading, 60)，所以需要调整坐标
        let leftPadding: CGFloat = 60

        // 只有在事件区域内的点击才创建事件（x > leftPadding）
        guard start.x > leftPadding && end.x > leftPadding else { return }

        // 支持分钟级别的精确时间计算
        let startY = min(start.y, end.y)
        let endY = max(start.y, end.y)

        // 确保选择区域有最小高度（至少15分钟）
        let minSelectionHeight = hourHeight * 0.25 // 15分钟
        let adjustedEndY = max(endY, startY + minSelectionHeight)

        let totalMinutesStart = max(0, min(24*60-1, Int(startY / hourHeight * 60)))
        let totalMinutesEnd = max(totalMinutesStart+15, min(24*60, Int(adjustedEndY / hourHeight * 60)))

        let startHour = totalMinutesStart / 60
        let startMinute = totalMinutesStart % 60
        let endHour = totalMinutesEnd / 60
        let endMinute = totalMinutesEnd % 60

        guard let startTime = calendar.date(bySettingHour: startHour, minute: startMinute, second: 0, of: selectedDate),
              let endTime = calendar.date(bySettingHour: endHour, minute: endMinute, second: 0, of: selectedDate) else {
            return
        }

        let newEvent = PomodoroEvent(
            title: "新事件",
            startTime: startTime,
            endTime: endTime,
            type: PomodoroEvent.EventType.custom
        )
        eventManager.addEvent(newEvent)
        selectedEvent = newEvent
    }
    
    private func resetSelection() {
        selectionStart = nil
        selectionEnd = nil
        isSelecting = false
    }

    // 计算事件的位置信息
    private func eventPositionForEvent(_ event: PomodoroEvent) -> (y: CGFloat, height: CGFloat) {
        let startHour = calendar.component(.hour, from: event.startTime)
        let startMinute = calendar.component(.minute, from: event.startTime)
        let endHour = calendar.component(.hour, from: event.endTime)
        let endMinute = calendar.component(.minute, from: event.endTime)
        let startY = CGFloat(startHour) * hourHeight + CGFloat(startMinute) * hourHeight / 60
        let endY = CGFloat(endHour) * hourHeight + CGFloat(endMinute) * hourHeight / 60
        let height = endY - startY
        return (startY, max(20, height))
    }

    // 清除 TimelineView 缓存的辅助方法
    private func clearAllCaches() {
        // 清除布局缓存
        cachedLayoutEventsHash = 0
        cachedEventLayoutInfo = []
        cachedLayoutDate = nil
    }
}
                
// MARK: - 事件块（性能优化版本）
struct EventBlock: View, Equatable {

    // MARK: - Equatable 实现
    static func == (lhs: EventBlock, rhs: EventBlock) -> Bool {
        return lhs.event.id == rhs.event.id &&
               lhs.event.title == rhs.event.title &&
               lhs.event.startTime == rhs.event.startTime &&
               lhs.event.endTime == rhs.event.endTime &&
               lhs.event.type == rhs.event.type &&
               lhs.selectedEvent?.id == rhs.selectedEvent?.id &&
               lhs.draggedEvent?.id == rhs.draggedEvent?.id &&
               lhs.column == rhs.column &&
               lhs.totalColumns == rhs.totalColumns &&
               lhs.highlightedEventId == rhs.highlightedEventId
    }
    let event: PomodoroEvent
    @Binding var selectedEvent: PomodoroEvent?
    @Binding var draggedEvent: PomodoroEvent?
    @Binding var dragOffset: CGSize
    let hourHeight: CGFloat
    let selectedDate: Date
    var column: Int = 0
    var totalColumns: Int = 1
    let containerWidth: CGFloat // 新增：容器宽度参数
    @Binding var highlightedEventId: UUID?
    @EnvironmentObject var eventManager: EventManager
    @State private var showingPopover = false

    // 性能优化：使用共享的位置缓存管理器
    @ObservedObject var positionCache: EventPositionCache
    private let calendar = Calendar.current
    @State private var isDragging = false
    @State private var dragStartOffset: CGSize = .zero
    @State private var lastUpdateTime: Date = Date()

    // 拖拽阈值，避免意外触发 - 增加阈值以避免与双击冲突
    private let dragThreshold: CGFloat = 10.0
    // 更新频率限制（毫秒）- 提高更新频率以改善响应性
    private let updateThrottleMs: TimeInterval = 8.33 // ~120fps

    private var eventPosition: (y: CGFloat, height: CGFloat) {
        // 使用新的缓存管理器
        return positionCache.getPosition(for: event, hourHeight: hourHeight)
    }
    var body: some View {
        // 动态计算宽度：使用容器宽度而不是固定值
        let leftPadding: CGFloat = 60 // 时间标签区域宽度
        let rightPadding: CGFloat = 20 // 右侧留白
        let availableWidth = containerWidth - leftPadding - rightPadding
        let gap: CGFloat = 4 // 减小间隙以节省空间
        let totalGapWidth = gap * CGFloat(totalColumns - 1)
        let width = (availableWidth - totalGapWidth) / CGFloat(totalColumns)
        let x = leftPadding + CGFloat(column) * (width + gap)

        // 直接获取位置信息
        let position = eventPosition

        // 调试信息
        #if DEBUG
        let _ = print("🎯 EventBlock: \(event.title) - 位置: x=\(x), y=\(position.y), 宽度=\(width), 高度=\(position.height), 容器宽度=\(containerWidth)")
        #endif
        HStack(alignment: .top, spacing: 0) {
            // 左侧深色border - 与右侧内容区域高度保持一致
            Rectangle()
                .fill(event.type.color)
                .frame(width: 4)

            // 右侧内容区域
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(selectedEvent?.id == event.id ? .white : event.type.color)
                    .lineLimit(2)
                Text(event.formattedTimeRange)
                    .font(.caption2)
                    .foregroundColor(selectedEvent?.id == event.id ? .white.opacity(0.8) : event.type.color.opacity(0.7))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, minHeight: max(20, position.height), alignment: .topLeading)
            .background(
                selectedEvent?.id == event.id
                    ? event.type.color
                    : event.type.color.opacity(0.2)
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .frame(width: width, height: max(20, position.height))
        .position(x: x + width / 2, y: position.y + max(20, position.height) / 2)
        .offset(draggedEvent?.id == event.id ? dragOffset : .zero)
        .scaleEffect(highlightedEventId == event.id ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: selectedEvent?.id == event.id)
        .animation(.easeInOut(duration: 0.5), value: highlightedEventId == event.id)
            .onTapGesture(count: 2) {
                showingPopover = true
            }
            .simultaneousGesture(
                    TapGesture()
                        .onEnded { _ in
                            selectedEvent = event
                        }
                )
            .popover(isPresented: $showingPopover, arrowEdge: .trailing) {
                EventDetailPopover(event: event, onSave: { updatedEvent in
                    showingPopover = false
                    // 更新选中事件以同步右侧面板
                    if selectedEvent?.id == event.id {
                        selectedEvent = updatedEvent
                    }
                }, onDelete: {
                    showingPopover = false
                    selectedEvent = nil
                })
                .environmentObject(eventManager)
                .frame(minWidth: 300)
            }
            .contextMenu {
                Button(role: .destructive) {
                    eventManager.removeEvent(event)
                    if selectedEvent?.id == event.id { selectedEvent = nil }
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
            .gesture(
                DragGesture(minimumDistance: dragThreshold)
                    .onChanged { value in
                        handleDragChanged(value)
                    }
                    .onEnded { value in
                        handleDragEnded(value)
                    }
            )
            .onAppear {
                // 视图出现时，缓存会自动按需计算，无需特殊处理
                #if DEBUG
                let stats = positionCache.getCacheStats()
                print("🕐 EventBlock onAppear: \(event.title), 缓存统计: \(stats.count) 项")
                #endif
            }
            .onChange(of: hourHeight) { _ in
                // hourHeight 变化时，旧缓存会自动失效（因为缓存键包含 hourHeight）
                #if DEBUG
                print("🕐 EventBlock: \(event.title) hourHeight 变化，缓存将自动更新")
                #endif
            }
    }

    // MARK: - 性能优化的拖拽处理

    private func handleDragChanged(_ value: DragGesture.Value) {
        let currentTime = Date()

        // 初始拖拽检测：立即响应，不受节流限制
        if !isDragging {
            isDragging = true
            dragStartOffset = value.translation
            selectedEvent = event // 开始拖拽时选中
            draggedEvent = event
            dragOffset = value.translation

            // 触觉反馈
            #if os(iOS)
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            #endif

            lastUpdateTime = currentTime
            return
        }

        // 后续拖拽更新：应用节流以优化性能
        guard currentTime.timeIntervalSince(lastUpdateTime) >= updateThrottleMs / 1000 else {
            // 即使在节流期间，也要更新偏移量以保持流畅性
            dragOffset = value.translation
            return
        }

        // 使用相对偏移量，减少计算
        dragOffset = value.translation
        lastUpdateTime = currentTime
    }

    private func handleDragEnded(_ value: DragGesture.Value) {
        defer {
            // 清理状态
            isDragging = false
            draggedEvent = nil
            dragOffset = .zero
            dragStartOffset = .zero
        }

        // 只有实际移动了才更新时间
        let totalTranslation = value.translation
        if abs(totalTranslation.height) > dragThreshold {
            updateEventTime(with: totalTranslation)
        }
    }

    private func updateEventTime(with translation: CGSize) {
        // 性能优化：使用更精确的时间计算
        let timeChange = translation.height / hourHeight * 3600 // 秒数
        let roundedTimeChange = round(timeChange / 300) * 300 // 四舍五入到5分钟

        guard let newStartTime = calendar.date(byAdding: .second, value: Int(roundedTimeChange), to: event.startTime),
              let newEndTime = calendar.date(byAdding: .second, value: Int(roundedTimeChange), to: event.endTime) else {
            return
        }

        // 批量更新，减少重绘
        DispatchQueue.main.async {
            var updatedEvent = event
            updatedEvent.startTime = newStartTime
            updatedEvent.endTime = newEndTime
            eventManager.updateEvent(updatedEvent)

            // 更新选中事件以同步右侧面板
            if selectedEvent?.id == event.id {
                selectedEvent = updatedEvent
            }
        }
    }
}

// MARK: - 选择覆盖层
struct SelectionOverlay: View {
    let start: CGPoint
    let end: CGPoint

    var body: some View {
        // 修复选择区域显示：限制在事件区域内
        let leftPadding: CGFloat = 60
        let eventAreaWidth: CGFloat = 200 // 事件区域宽度

        let constrainedStart = CGPoint(
            x: max(leftPadding, start.x),
            y: start.y
        )
        let constrainedEnd = CGPoint(
            x: min(leftPadding + eventAreaWidth, max(leftPadding, end.x)),
            y: end.y
        )

        let rect = CGRect(
            x: min(constrainedStart.x, constrainedEnd.x),
            y: min(constrainedStart.y, constrainedEnd.y),
            width: max(10, abs(constrainedEnd.x - constrainedStart.x)), // 最小宽度
            height: max(10, abs(constrainedEnd.y - constrainedStart.y)) // 最小高度
        )

        Rectangle()
            .foregroundColor(Color.blue.opacity(0.2))
            .overlay(
                Rectangle()
                    .stroke(Color.blue.opacity(0.6), lineWidth: 1)
            )
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }
}

// MARK: - 小日历视图
struct MiniCalendarView: View {
    let viewMode: CalendarViewMode
    @Binding var selectedDate: Date
    @State private var currentMonth = Date()

    // 异步事件数据缓存
    @State private var monthEventsCache: [Date: [PomodoroEvent]] = [:]
    @State private var isLoadingEvents = false
    @State private var dataLoadingTask: Task<Void, Never>?

    @EnvironmentObject var eventManager: EventManager

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    private var monthDays: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth) else {
            return []
        }
        
        let firstOfMonth = monthInterval.start
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let daysToSubtract = (firstWeekday - 1) % 7
        
        guard let startDate = calendar.date(byAdding: .day, value: -daysToSubtract, to: firstOfMonth) else {
            return []
        }
        
        var days: [Date] = []
        for i in 0..<42 {
            if let day = calendar.date(byAdding: .day, value: i, to: startDate) {
                days.append(day)
            }
        }
        
        return days
    }
    
    var body: some View {
        VStack(spacing: 6) {
            // 导航按钮组
            CalendarNavigationToolbar(
                viewMode: viewMode,
                selectedDate: $selectedDate
            )

            // 星期标题
            HStack(spacing: 0) {
                ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { day in
                    Text(day)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // 日历网格
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(monthDays, id: \.self) { date in
                    MiniDayCell(
                        date: date,
                        selectedDate: $selectedDate,
                        currentMonth: currentMonth,
                        events: monthEventsCache[date] ?? [],
                        isLoadingEvents: isLoadingEvents
                    )
                }
            }
        }
        .onAppear {
            currentMonth = selectedDate
            loadMiniCalendarEvents()
        }
        .onChange(of: selectedDate) { newDate in
            if !calendar.isDate(newDate, equalTo: currentMonth, toGranularity: .month) {
                currentMonth = newDate
                loadMiniCalendarEvents()
            }
        }
        .onDisappear {
            dataLoadingTask?.cancel()
        }
    }
    
    private let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        return formatter
    }()

    // MARK: - 异步数据加载方法

    /// 异步加载迷你日历的事件数据
    private func loadMiniCalendarEvents() {
        // 取消之前的加载任务
        dataLoadingTask?.cancel()

        // 设置加载状态
        isLoadingEvents = true

        // 创建异步任务
        dataLoadingTask = Task {
            await performMiniCalendarDataLoading()
        }
    }

    /// 执行迷你日历数据加载（优化版本）
    @MainActor
    private func performMiniCalendarDataLoading() async {
        let monthDates = monthDays

        // 在后台线程执行数据查询，使用批量查询优化
        let eventsCache = await Task.detached { [eventManager] in
            // 使用EventManager的批量查询方法
            return eventManager.eventsForDates(monthDates)
        }.value

        // 检查任务是否被取消
        guard !Task.isCancelled else { return }

        // 更新缓存数据
        monthEventsCache = eventsCache
        isLoadingEvents = false
    }

}

// MARK: - 小日历日期单元格
struct MiniDayCell: View {
    let date: Date
    @Binding var selectedDate: Date
    let currentMonth: Date
    let events: [PomodoroEvent]
    let isLoadingEvents: Bool

    private let calendar = Calendar.current
    
    private var isSelected: Bool {
        calendar.isDate(date, inSameDayAs: selectedDate)
    }
    
    private var isCurrentMonth: Bool {
        calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)
    }
    
    private var isToday: Bool {
        calendar.isDateInToday(date)
    }

    private var hasEvents: Bool {
        !events.isEmpty
    }

    private var eventIndicatorColor: Color {
        if events.contains(where: { $0.type == .pomodoro }) {
            return .blue
        } else if events.contains(where: { $0.type == .countUp }) {
            return .green
        } else if !events.isEmpty {
            return .orange
        } else {
            return .clear
        }
    }
    
    var body: some View {
        Button(action: {
            selectedDate = date
        }) {
            ZStack {
                // 主要内容
                Text("\(calendar.component(.day, from: date))")
                    .font(.caption2)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor({
                        if isSelected {
                            return .white
                        } else if isToday {
                            return .accentColor // 使用系统强调色
                        } else if isCurrentMonth {
                            return .primary
                        } else {
                            return .secondary
                        }
                    }())
                    .frame(width: 20, height: 20)
                    .background(
                        Group {
                            if isSelected {
                                // 选中状态使用系统强调色背景
                                Color.accentColor
                            } else {
                                // 未选中状态无背景色
                                Color.clear
                            }
                        }
                    )
                    .clipShape(Circle())

                // 事件指示器
                if !isLoadingEvents && hasEvents {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Circle()
                                .fill(eventIndicatorColor)
                                .frame(width: 4, height: 4)
                                .offset(x: -2, y: -2)
                        }
                    }
                } else if isLoadingEvents {
                    // 加载状态指示器
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 3, height: 3)
                                .offset(x: -2, y: -2)
                        }
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 当日统计面板
struct DayStatsPanel: View {
    @Binding var selectedDate: Date
    @EnvironmentObject var eventManager: EventManager
    @EnvironmentObject var activityMonitor: ActivityMonitorManager

    // 异步数据状态
    @State private var dayStats: (totalActiveTime: TimeInterval, pomodoroSessions: Int, appSwitches: Int) = (0, 0, 0)
    @State private var topApps: [AppUsageStats] = []
    @State private var isLoadingStats = false
    @State private var dataLoadingTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if isLoadingStats {
                    // 加载状态
                    loadingView
                } else {
                    // 当日活动概览
                    dayActivityOverview

                    // 当日热门应用
                    dayTopApps

                    Spacer()
                }
            }
        }
        .onAppear {
            loadDayStatsAsync()
        }
        .onChange(of: selectedDate) { _ in
            loadDayStatsAsync()
        }
        .onDisappear {
            dataLoadingTask?.cancel()
        }
    }

    // 当日活动概览
    private var dayActivityOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("活动概览")
                .font(.subheadline)
                .fontWeight(.medium)

            // 使用缓存的统计数据

            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "timer")
                        .foregroundColor(.blue)
                    Text("日专注时间")
                    Spacer()
                    Text(formatTime(dayStats.totalActiveTime))
                        .fontWeight(.medium)
                }

                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(.green)
                    Text("番茄个数")
                    Spacer()
                    Text("\(dayStats.pomodoroSessions)")
                        .fontWeight(.medium)
                }
            }
            .font(.caption)
        }
        .padding()
    }

    // 当日热门应用
    private var dayTopApps: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("热门应用")
                .font(.subheadline)
                .fontWeight(.medium)

            // 使用缓存的热门应用数据

            if self.topApps.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "app.dashed")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                    Text("暂无应用使用记录")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(self.topApps.enumerated()), id: \.offset) { index, appStat in
                        HStack {
                            // 排名
                            Text("\(index + 1)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .frame(width: 16)

                            // 应用名称
                            Text(appStat.appName)
                                .font(.caption)
                                .lineLimit(1)

                            Spacer()

                            // 使用时长
                            Text(formatTime(appStat.totalTime))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
    }

    // 计算当日统计数据
    private func calculateDayStats() -> (totalActiveTime: TimeInterval, pomodoroSessions: Int, appSwitches: Int) {
        // 获取当日事件
        let dayEvents = eventManager.eventsForDate(selectedDate)

        // 计算活跃时间（番茄时间+正计时间，不包含休息和自定义事件）
        var totalActiveTime: TimeInterval = 0
        for event in dayEvents {
            if event.type == .pomodoro || event.type == .countUp {
                totalActiveTime += event.endTime.timeIntervalSince(event.startTime)
            }
        }

        // 计算番茄时钟个数
        let pomodoroSessions = dayEvents.filter { $0.type == .pomodoro }.count

        // 获取应用切换次数
        let overview = activityMonitor.getOverview(for: selectedDate)
        let appSwitches = overview.appSwitches

        return (totalActiveTime, pomodoroSessions, appSwitches)
    }

    // 获取当日热门应用Top5
    private func getTopApps() -> [AppUsageStats] {
        let appStats = activityMonitor.getAppUsageStats(for: selectedDate)
        return Array(appStats.prefix(5))
    }

    // 格式化时间显示
    private func formatTime(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60

        if hours > 0 {
            return "\(hours)h\(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    // MARK: - 异步数据加载方法

    /// 异步加载当日统计数据
    private func loadDayStatsAsync() {
        // 取消之前的加载任务
        dataLoadingTask?.cancel()

        // 设置加载状态
        isLoadingStats = true

        // 创建异步任务
        dataLoadingTask = Task {
            await performDayStatsLoading()
        }
    }

    /// 执行当日统计数据加载
    @MainActor
    private func performDayStatsLoading() async {
        // 在后台线程执行数据查询
        let (stats, apps) = await Task.detached { [eventManager, activityMonitor, selectedDate] in
            // 计算当日统计
            let dayEvents = eventManager.eventsForDate(selectedDate)

            var totalActiveTime: TimeInterval = 0
            for event in dayEvents {
                if event.type == .pomodoro || event.type == .countUp {
                    totalActiveTime += event.endTime.timeIntervalSince(event.startTime)
                }
            }

            let pomodoroSessions = dayEvents.filter { $0.type == .pomodoro }.count
            let overview = activityMonitor.getOverview(for: selectedDate)
            let appSwitches = overview.appSwitches

            // 获取热门应用
            let appStats = activityMonitor.getAppUsageStats(for: selectedDate)
            let topApps = Array(appStats.prefix(5))

            return ((totalActiveTime, pomodoroSessions, appSwitches), topApps)
        }.value

        // 检查任务是否被取消
        guard !Task.isCancelled else { return }

        // 更新缓存数据
        dayStats = stats
        topApps = apps
        isLoadingStats = false
    }

    /// 加载状态视图
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(0.8)
            Text("加载统计数据...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}



// MARK: - 周视图
struct WeekView: View {
    @Binding var selectedDate: Date
    @Binding var highlightedEventId: UUID?
    @EnvironmentObject var eventManager: EventManager
    @EnvironmentObject var activityMonitor: ActivityMonitorManager
    @State private var selectedEvent: PomodoroEvent?
    @State private var showingAddEvent = false

    // 拖拽选择状态
    @State private var isSelecting = false
    @State private var selectionStart: CGPoint?
    @State private var selectionEnd: CGPoint?
    @State private var selectionDate: Date?

    private let calendar = Calendar.current
    private let hourHeight: CGFloat = 50

    // 获取当前周的日期范围
    private var weekDates: [Date] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else {
            return []
        }

        var dates: [Date] = []
        let startDate = weekInterval.start

        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: i, to: startDate) {
                dates.append(date)
            }
        }

        return dates
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // 主要周视图区域
                VStack(alignment: .leading, spacing: 0) {
                    // 日期显示区域（只显示日期信息，不显示导航按钮）
                    DateDisplayOnly(selectedDate: $selectedDate)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()

                    // 星期标题行
                    let isCompact = geometry.size.width < 800
                    let timeAxisWidth: CGFloat = isCompact ? 50 : 60

                    weekHeaderView(timeAxisWidth: timeAxisWidth)
                        .frame(height: isCompact ? 50 : 60)

                    Divider()

                    // 时间轴和事件网格
                    ScrollView {
                        GeometryReader { scrollGeometry in
                            ZStack(alignment: .topLeading) {
                                let isCompact = geometry.size.width < 800
                                let timeAxisWidth: CGFloat = isCompact ? 50 : 60

                                HStack(alignment: .top, spacing: 0) {
                                    // 左侧时间标签
                                    timeLabelsView
                                        .frame(width: timeAxisWidth)

                                    // 周事件网格
                                    weekGridView
                                }

                                // 周视图时间指示器（跨越整个宽度）
                                WeekTimeIndicatorOverlay(
                                    hourHeight: hourHeight,
                                    weekDates: weekDates,
                                    containerWidth: scrollGeometry.size.width
                                )
                            }
                        }
                        .frame(height: CGFloat(24) * hourHeight) // 24小时的总高度
                    }
                }
                .frame(maxWidth: .infinity)

                // 右侧面板已提升为顶层 overlay
            }
        }
        .sheet(isPresented: $showingAddEvent) {
            EventEditView(event: PomodoroEvent(
                title: "新事件",
                startTime: selectedDate,
                endTime: Calendar.current.date(byAdding: .hour, value: 1, to: selectedDate) ?? selectedDate,
                type: .custom
            ), onSave: { _ in
                showingAddEvent = false
            }, onDelete: {
                showingAddEvent = false
            })
                .environmentObject(eventManager)
        }
    }

    // 星期标题视图
    private func weekHeaderView(timeAxisWidth: CGFloat = 60) -> some View {
        HStack(spacing: 0) {
            // 左侧空白区域（对应时间标签）
            Rectangle()
                .fill(Color.clear)
                .frame(width: timeAxisWidth)

            // 星期标题
            ForEach(Array(weekDates.enumerated()), id: \.element) { index, date in
                VStack(spacing: 4) {
                    Text(dayFormatter.string(from: date))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("\(calendar.component(.day, from: date))")
                        .font(.title2)
                        .fontWeight(calendar.isDate(date, inSameDayAs: selectedDate) ? .bold : .regular)
                        .foregroundColor(calendar.isDate(date, inSameDayAs: selectedDate) ? .blue : .primary)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedDate = date
                }
            }
        }
        .padding(.vertical, 8)
    }

    // 时间标签视图
    private var timeLabelsView: some View {
        VStack(spacing: 0) {
            ForEach(Array(0...23), id: \.self) { hour in
                HStack(alignment: .top) {
                    Text(String(format: "%02d:00", hour))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .trailing)

                    Spacer()
                }
                .frame(height: hourHeight, alignment: .top)
            }
        }
    }

    // 周事件网格视图
    private var weekGridView: some View {
        ZStack(alignment: .topLeading) {
            // 横线网格层 - 比竖线颜色更浅
            VStack(spacing: 0) {
                ForEach(Array(0...23), id: \.self) { hour in
                    HStack {
                        // 跨越整个周视图宽度的横线
                        Rectangle()
                            .fill(Color.secondary.opacity(0.05)) // 比竖线更浅的颜色
                            .frame(height: 1)
                    }
                    .frame(height: hourHeight, alignment: .top)
                }
            }

            // 主要内容层
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(weekDates.enumerated()), id: \.element) { index, date in
                    HStack(spacing: 0) {
                        VStack(spacing: 0) {
                            // 保留空间占位
                            ForEach(Array(0...23), id: \.self) { hour in
                                Rectangle()
                                    .fill(Color.clear)
                                    .frame(height: hourHeight)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .background(
                            // 当日事件 - 使用并列布局算法
                            GeometryReader { dayGeometry in
                                ZStack(alignment: .topLeading) {
                                    let dayEvents = eventManager.eventsForDate(date)
                                    let eventLayoutInfo = computeEventColumns(events: dayEvents)

                                    ForEach(eventLayoutInfo, id: \.0.id) { info in
                                        let (event, column, totalColumns) = info
                                        WeekEventBlock(
                                            event: event,
                                            selectedEvent: $selectedEvent,
                                            hourHeight: hourHeight,
                                            date: date,
                                            column: column,
                                            totalColumns: totalColumns,
                                            containerWidth: dayGeometry.size.width,
                                            highlightedEventId: $highlightedEventId
                                        )
                                    }

                                    // 选择区域覆盖层（只在当前选择的日期显示）
                                    if isSelecting, let start = selectionStart, let end = selectionEnd, selectionDate == date {
                                        WeekSelectionOverlay(start: start, end: end, containerWidth: dayGeometry.size.width)
                                    }
                                }
                            }
                        )
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // 点击取消选中事件
                            selectedEvent = nil
                        }
                        .gesture(
                            DragGesture(minimumDistance: 5)
                                .onChanged { value in
                                    // 开始拖拽选择
                                    if selectionStart == nil {
                                        selectionStart = value.startLocation
                                        selectionDate = date
                                        isSelecting = true
                                    }

                                    // 只有在同一天内才更新选择
                                    if selectionDate == date {
                                        selectionEnd = value.location
                                    }
                                }
                                .onEnded { value in
                                    if isSelecting && selectionDate == date {
                                        createEventFromWeekSelection(date: date)
                                    }
                                    resetSelection()
                                }
                        )

                        // 添加竖线分隔（除了最后一列）
                        if index < weekDates.count - 1 {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.3)) // 竖线保持原来的颜色
                                .frame(width: 1)
                        }
                    }
                }
            }
        }
    }

    // 周统计面板
    private var weekStatsPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Text("本周统计")
                //     .font(.headline)
                //     .padding(.horizontal)

                // 本周活动概览
                weekActivityOverview

                // 本周热门应用
                weekTopApps

                Spacer()
            }
        }
    }

    // 本周活动概览
    private var weekActivityOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("活动概览")
                .font(.subheadline)
                .fontWeight(.medium)

            // 计算本周统计
            let weekStats = calculateWeekStats()

            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "timer")
                        .foregroundColor(.blue)
                    Text("周专注时间")
                    Spacer()
                    Text(formatTime(weekStats.totalActiveTime))
                        .fontWeight(.medium)
                }

                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(.green)
                    Text("番茄个数")
                    Spacer()
                    Text("\(weekStats.pomodoroSessions)")
                        .fontWeight(.medium)
                }
            }
            .font(.caption)
        }
        .padding()
    }

    // 本周热门应用
    private var weekTopApps: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("热门应用")
                .font(.subheadline)
                .fontWeight(.medium)

            let topApps = getWeekTopApps()

            if topApps.isEmpty {
                Text("暂无数据")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(topApps.prefix(5)), id: \.appName) { app in
                    HStack {
                        Text(app.appName)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text(app.formattedTime)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
    }

    // 辅助方法
    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter
    }()

    private func createEventAt(date: Date, location: CGPoint) {
        let hour = Int(location.y / hourHeight)
        let startTime = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
        let endTime = calendar.date(byAdding: .hour, value: 1, to: startTime) ?? startTime

        let newEvent = PomodoroEvent(
            title: "新事件",
            startTime: startTime,
            endTime: endTime,
            type: .custom
        )

        eventManager.addEvent(newEvent)
        selectedEvent = newEvent
    }

    private func calculateWeekStats() -> (totalActiveTime: TimeInterval, totalAppSwitches: Int, pomodoroSessions: Int) {
        var totalActiveTime: TimeInterval = 0
        var totalAppSwitches = 0
        var pomodoroSessions = 0

        for date in weekDates {
            // 获取当日事件
            let dayEvents = eventManager.eventsForDate(date)

            // 计算活跃时间（番茄时间+正计时间，不包含休息和自定义事件）
            for event in dayEvents {
                if event.type == .pomodoro || event.type == .countUp {
                    totalActiveTime += event.endTime.timeIntervalSince(event.startTime)
                }
            }

            // 获取应用切换次数（仍使用系统监控数据）
            let overview = activityMonitor.getOverview(for: date)
            totalAppSwitches += overview.appSwitches

            // 计算当日番茄时钟会话
            pomodoroSessions += dayEvents.filter { $0.type == .pomodoro }.count
        }

        return (totalActiveTime, totalAppSwitches, pomodoroSessions)
    }

    private func getWeekTopApps() -> [AppUsageStats] {
        var allApps: [String: (totalTime: TimeInterval, activationCount: Int)] = [:]

        for date in weekDates {
            let dayApps = activityMonitor.getAppUsageStats(for: date)
            for app in dayApps {
                let current = allApps[app.appName] ?? (totalTime: 0, activationCount: 0)
                allApps[app.appName] = (
                    totalTime: current.totalTime + app.totalTime,
                    activationCount: current.activationCount + app.activationCount
                )
            }
        }

        return allApps.map { (appName, stats) in
            AppUsageStats(
                appName: appName,
                totalTime: stats.totalTime,
                activationCount: stats.activationCount,
                lastUsed: Date()
            )
        }.sorted { $0.totalTime > $1.totalTime }
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

    // WeekView 的事件并列排布算法
    private func computeEventColumns(events: [PomodoroEvent]) -> [(PomodoroEvent, Int, Int)] {
        // 按开始时间排序
        let sorted = events.sorted { $0.startTime < $1.startTime }
        var result: [(PomodoroEvent, Int, Int)] = []
        var active: [(PomodoroEvent, Int)] = [] // (event, column)

        for event in sorted {
            // 计算当前事件的视觉位置（考虑最小高度）
            let eventVisualBounds = getEventVisualBounds(event)

            // 移除已结束的事件（考虑视觉边界而不仅仅是时间边界）
            active.removeAll { activeEvent in
                let activeVisualBounds = getEventVisualBounds(activeEvent.0)
                return activeVisualBounds.maxY <= eventVisualBounds.minY
            }

            // 查找可用列
            let usedColumns = Set(active.map { $0.1 })
            var col = 0
            while usedColumns.contains(col) { col += 1 }
            active.append((event, col))
            // 计算当前重叠的总列数
            let overlapCount = active.count
            result.append((event, col, overlapCount))
        }

        // 由于每个事件的 totalColumns 需要是与其重叠区间的最大 overlapCount，需再遍历修正
        var eventToMaxCol: [UUID: Int] = [:]
        for (event, _, _) in result {
            let eventVisualBounds = getEventVisualBounds(event)
            let overlapping = result.filter { otherEvent in
                let otherVisualBounds = getEventVisualBounds(otherEvent.0)
                // 检查视觉边界是否重叠
                return eventVisualBounds.minY < otherVisualBounds.maxY &&
                       eventVisualBounds.maxY > otherVisualBounds.minY
            }
            let maxCol = overlapping.map { $0.2 }.max() ?? 1
            eventToMaxCol[event.id] = maxCol
        }
        return result.map { (event, col, _) in
            (event, col, eventToMaxCol[event.id] ?? 1)
        }
    }

    // 计算事件的视觉边界（考虑最小高度）- WeekView 版本
    private func getEventVisualBounds(_ event: PomodoroEvent) -> (minY: CGFloat, maxY: CGFloat) {
        let startHour = calendar.component(.hour, from: event.startTime)
        let startMinute = calendar.component(.minute, from: event.startTime)
        let endHour = calendar.component(.hour, from: event.endTime)
        let endMinute = calendar.component(.minute, from: event.endTime)
        let startY = CGFloat(startHour) * hourHeight + CGFloat(startMinute) * hourHeight / 60
        let endY = CGFloat(endHour) * hourHeight + CGFloat(endMinute) * hourHeight / 60
        let actualHeight = endY - startY
        let visualHeight = max(20, actualHeight) // 最小高度20
        return (startY, startY + visualHeight)
    }

    // 从周视图选择创建事件
    private func createEventFromWeekSelection(date: Date) {
        guard let start = selectionStart, let end = selectionEnd else { return }

        // 支持分钟级别的精确时间计算
        let startY = min(start.y, end.y)
        let endY = max(start.y, end.y)

        // 确保选择区域有最小高度（至少15分钟）
        let minSelectionHeight = hourHeight * 0.25 // 15分钟
        let adjustedEndY = max(endY, startY + minSelectionHeight)

        let totalMinutesStart = max(0, min(24*60-1, Int(startY / hourHeight * 60)))
        let totalMinutesEnd = max(totalMinutesStart+15, min(24*60, Int(adjustedEndY / hourHeight * 60)))

        let startHour = totalMinutesStart / 60
        let startMinute = totalMinutesStart % 60
        let endHour = totalMinutesEnd / 60
        let endMinute = totalMinutesEnd % 60

        guard let startTime = calendar.date(bySettingHour: startHour, minute: startMinute, second: 0, of: date),
              let endTime = calendar.date(bySettingHour: endHour, minute: endMinute, second: 0, of: date) else {
            return
        }

        let newEvent = PomodoroEvent(
            title: "新事件",
            startTime: startTime,
            endTime: endTime,
            type: PomodoroEvent.EventType.custom
        )
        eventManager.addEvent(newEvent)
        selectedEvent = newEvent
    }

    private func resetSelection() {
        selectionStart = nil
        selectionEnd = nil
        selectionDate = nil
        isSelecting = false
    }
}

// MARK: - 周视图事件块
struct WeekEventBlock: View {
    let event: PomodoroEvent
    @Binding var selectedEvent: PomodoroEvent?
    let hourHeight: CGFloat
    let date: Date
    var column: Int = 0
    var totalColumns: Int = 1
    let containerWidth: CGFloat
    @Binding var highlightedEventId: UUID?

    @State private var showingPopover = false
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @EnvironmentObject var eventManager: EventManager

    private let calendar = Calendar.current

    // 性能优化：缓存位置计算
    private var eventPosition: (y: CGFloat, height: CGFloat) {
        let startHour = calendar.component(.hour, from: event.startTime)
        let startMinute = calendar.component(.minute, from: event.startTime)
        let endHour = calendar.component(.hour, from: event.endTime)
        let endMinute = calendar.component(.minute, from: event.endTime)

        let startY = CGFloat(startHour) * hourHeight + CGFloat(startMinute) * hourHeight / 60
        let endY = CGFloat(endHour) * hourHeight + CGFloat(endMinute) * hourHeight / 60
        let height = max(20, endY - startY)

        return (startY, height)
    }

    var body: some View {
        let position = eventPosition

        // 动态计算宽度和位置（类似日视图的EventBlock）
        let gap: CGFloat = 2 // 周视图中使用更小的间隙
        let totalGapWidth = gap * CGFloat(totalColumns - 1)
        let width = (containerWidth - totalGapWidth) / CGFloat(totalColumns)
        let x = CGFloat(column) * (width + gap)

        HStack(spacing: 0) {
            // 左侧深色border - 确保高度与容器一致
            Rectangle()
                .fill(event.type.color)
                .frame(width: 3, height: position.height)

            // 右侧内容区域
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(selectedEvent?.id == event.id ? .white : event.type.color)
                    .lineLimit(1)

                if position.height > 30 {
                    Text(event.formattedTimeRange)
                        .font(.caption2)
                        .foregroundColor(selectedEvent?.id == event.id ? .white.opacity(0.8) : event.type.color.opacity(0.7))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                selectedEvent?.id == event.id
                    ? event.type.color
                    : event.type.color.opacity(0.2)
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .frame(width: width, height: position.height)
        .position(x: x + width / 2, y: position.y + position.height / 2)
        .offset(dragOffset)
        .scaleEffect(highlightedEventId == event.id ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: selectedEvent?.id == event.id)
        .animation(.easeInOut(duration: 0.5), value: highlightedEventId == event.id)
        .onTapGesture(count: 2) {
            showingPopover = true
        }
        .simultaneousGesture(
            TapGesture()
                .onEnded { _ in
                    selectedEvent = event
                }
        )
        .popover(isPresented: $showingPopover, arrowEdge: .trailing) {
            EventDetailPopover(
                event: event,
                onSave: { updatedEvent in
                    showingPopover = false
                    // 更新选中事件以同步右侧面板
                    if selectedEvent?.id == event.id {
                        selectedEvent = updatedEvent
                    }
                },
                onDelete: {
                    selectedEvent = nil
                    showingPopover = false
                }
            )
            .environmentObject(eventManager)
            .frame(minWidth: 350)
        }
        .contextMenu {
            Button(role: .destructive) {
                eventManager.removeEvent(event)
                if selectedEvent?.id == event.id {
                    selectedEvent = nil
                }
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
        .gesture(
            DragGesture(minimumDistance: 10.0)
                .onChanged { value in
                    isDragging = true
                    dragOffset = value.translation
                    selectedEvent = event
                }
                .onEnded { value in
                    // 计算新的时间
                    let timeChange = value.translation.height / hourHeight * 3600 // 转换为秒
                    let roundedTimeChange = round(timeChange / 300) * 300 // 四舍五入到5分钟

                    if abs(roundedTimeChange) > 0 {
                        let newStartTime = event.startTime.addingTimeInterval(roundedTimeChange)
                        let duration = event.endTime.timeIntervalSince(event.startTime)
                        let newEndTime = newStartTime.addingTimeInterval(duration)

                        // 更新事件
                        var updatedEvent = event
                        updatedEvent.startTime = newStartTime
                        updatedEvent.endTime = newEndTime
                        eventManager.updateEvent(updatedEvent)

                        // 更新选中事件以同步右侧面板
                        if selectedEvent?.id == event.id {
                            selectedEvent = updatedEvent
                        }
                    }

                    // 重置拖拽状态
                    isDragging = false
                    dragOffset = .zero
                }
        )
    }
}

// MARK: - 月视图
struct MonthView: View {
    let viewMode: CalendarViewMode
    @Binding var selectedDate: Date
    @Binding var highlightedEventId: UUID?
    @EnvironmentObject var eventManager: EventManager
    @EnvironmentObject var activityMonitor: ActivityMonitorManager
    @State private var selectedEvent: PomodoroEvent?
    @State private var showingAddEvent = false
    @State private var currentMonth = Date()

    // Popover 状态管理
    @State private var showingDayEventsPopover = false
    @State private var showingEventDetailPopover = false
    @State private var popoverDate: Date = Date()
    @State private var popoverEvent: PomodoroEvent?

    // 异步数据预加载状态
    @State private var monthEventsCache: [Date: [PomodoroEvent]] = [:]
    @State private var monthActivityCache: [Date: [AppUsageStats]] = [:]
    @State private var isLoadingData = false
    @State private var dataLoadingTask: Task<Void, Never>?

    // UI状态管理 - 与数据加载解耦
    @State private var displayMonth = Date() // 当前显示的月份，立即更新
    @State private var dataMonth = Date() // 数据对应的月份，延迟更新
    @State private var showLoadingIndicator = false // 控制加载指示器显示
    @State private var preloadedMonths: Set<String> = [] // 已预加载的月份缓存

    // 月度统计数据缓存
    @State private var monthStats: (activeDays: Int, totalActiveTime: TimeInterval, pomodoroSessions: Int, avgProductivity: Double) = (0, 0, 0, 0)
    @State private var isLoadingMonthStats = false
    @State private var monthStatsLoadingTask: Task<Void, Never>?

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 7)

    // 检查数据是否与显示月份不匹配
    private var isDataMismatch: Bool {
        !calendar.isDate(displayMonth, equalTo: dataMonth, toGranularity: .month) || isLoadingData
    }

    // 获取当前月的所有日期（包括前后月份的日期以填满6周）- 安全版本
    private var monthDays: [Date] {
        // 安全检查显示月份
        guard displayMonth.timeIntervalSince1970 > 0,
              let monthInterval = calendar.dateInterval(of: .month, for: displayMonth) else {
            print("⚠️ MonthView: 无效的显示月份，返回空日期数组")
            return []
        }

        let firstOfMonth = monthInterval.start
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let daysToSubtract = max(0, (firstWeekday - 1) % 7) // 确保非负数

        guard let startDate = calendar.date(byAdding: .day, value: -daysToSubtract, to: firstOfMonth) else {
            print("⚠️ MonthView: 无法计算月份开始日期")
            return []
        }

        var days: [Date] = []
        for i in 0..<42 { // 6周 × 7天
            if let day = calendar.date(byAdding: .day, value: i, to: startDate) {
                // 额外验证生成的日期是否有效
                if day.timeIntervalSince1970 > 0 {
                    days.append(day)
                } else {
                    print("⚠️ MonthView: 生成了无效日期，跳过")
                }
            } else {
                print("⚠️ MonthView: 无法生成第 \(i) 天的日期")
            }
        }

        print("📅 MonthView: 成功生成 \(days.count) 个日期")
        return days
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // 主要月视图区域
                VStack(spacing: 0) {
                    // 月份导航
                    monthNavigationView

                    Divider()

                    // 星期标题
                    weekdayHeaderView
                        .frame(height: 30)

                    Divider()

                    // 月历网格
                    ZStack {
                        monthGridView
                            .frame(maxHeight: .infinity)
                            .opacity(isLoadingData ? 0.6 : 1.0)

                        // 智能加载指示器 - 只在数据不匹配时显示
                        if showLoadingIndicator {
                            VStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("加载中...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.systemBackground)
                                    .shadow(radius: 4)
                            )
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        }
                    }
                    .frame(maxHeight: .infinity)
                    .animation(.easeInOut(duration: 0.3), value: isLoadingData)
                }
                .frame(maxWidth: .infinity)

                // 右侧面板已提升为顶层 overlay（见 CalendarView.overlay）
                // 此处移除内部侧栏以避免重复显示
                // 原内部侧栏代码已删除
            }
        }
        .onAppear {
            // 初始化显示状态
            currentMonth = selectedDate
            displayMonth = selectedDate
            dataMonth = selectedDate
            loadMonthDataAsync()
        }
        .onChange(of: selectedDate) { newDate in
            // 立即更新UI显示
            if !calendar.isDate(newDate, equalTo: displayMonth, toGranularity: .month) {
                // 立即更新显示月份，确保UI响应
                displayMonth = newDate
                currentMonth = newDate

                // 延迟触发数据加载，避免阻塞UI
                scheduleDataLoading(for: newDate)
            }
        }
        .onDisappear {
            // 取消正在进行的数据加载任务
            dataLoadingTask?.cancel()
        }
        .sheet(isPresented: $showingAddEvent) {
            EventEditView(event: PomodoroEvent(
                title: "新事件",
                startTime: selectedDate,
                endTime: Calendar.current.date(byAdding: .hour, value: 1, to: selectedDate) ?? selectedDate,
                type: .custom
            ), onSave: { _ in
                showingAddEvent = false
            }, onDelete: {
                showingAddEvent = false
            })
                .environmentObject(eventManager)
        }
    }

    // 月份导航视图
    private var monthNavigationView: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(monthFormatter.string(from: displayMonth))
                .font(.title)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // 星期标题视图
    private var weekdayHeaderView: some View {
        HStack(spacing: 0) {
            ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { day in
                Text(day)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
    }

    // 月历网格视图
    private var monthGridView: some View {
        GeometryReader { geometry in
            let availableHeight = geometry.size.height
            let cellHeight = availableHeight / 6 // 6 rows for calendar weeks

            LazyVGrid(columns: columns, spacing: 1) {
                ForEach(monthDays, id: \.self) { date in
                    MonthDayCell(
                        date: date,
                        selectedDate: $selectedDate,
                        currentMonth: displayMonth,
                        events: monthEventsCache[date] ?? [],
                        activityStats: monthActivityCache[date] ?? [],
                        cellHeight: cellHeight,
                        isLoading: isDataMismatch,
                        highlightedEventId: $highlightedEventId
                    )
                    .id("\(date.timeIntervalSince1970)-\(isLoadingData)") // 确保正确的视图标识
                    .drawingGroup() // 将单元格渲染为单个图层，提高性能
                .onTapGesture {
                    selectedDate = date
                    popoverDate = date
                    showingDayEventsPopover = true
                }
                .onLongPressGesture {
                    selectedDate = date
                    showingAddEvent = true
                }
                .popover(isPresented: Binding<Bool>(
                    get: { showingDayEventsPopover && Calendar.current.isDate(popoverDate, inSameDayAs: date) },
                    set: { newValue in
                        if !newValue {
                            showingDayEventsPopover = false
                        }
                    }
                )) {
                    DayEventsPopover(
                        date: popoverDate,
                        selectedEvent: $popoverEvent,
                        showingEventDetail: $showingEventDetailPopover
                    )
                    .environmentObject(eventManager)
                }
            }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 0)
    }



    // 月度统计面板
    private var monthStatsPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if isLoadingMonthStats {
                    // 加载状态
                    monthStatsLoadingView
                } else {
                    // 月度活动概览
                    monthActivityOverview

                    // 月度生产力趋势
                    monthProductivityTrend

                    Spacer()
                }
            }
        }
        .onAppear {
            loadMonthStatsAsync()
        }
        .onChange(of: displayMonth) { _ in
            loadMonthStatsAsync()
        }
        .onDisappear {
            monthStatsLoadingTask?.cancel()
        }
    }

    // 月度活动概览
    private var monthActivityOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("活动概览")
                .font(.subheadline)
                .fontWeight(.medium)

            // 使用缓存的月度统计数据

            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                    Text("专注天数")
                    Spacer()
                    Text("\(monthStats.activeDays)")
                        .fontWeight(.medium)
                }

                HStack {
                    Image(systemName: "timer")
                        .foregroundColor(.orange)
                    Text("月专注时间")
                    Spacer()
                    Text(formatTime(monthStats.totalActiveTime))
                        .fontWeight(.medium)
                }

                HStack {
                    Image(systemName: "target")
                        .foregroundColor(.green)
                    Text("番茄个数")
                    Spacer()
                    Text("\(monthStats.pomodoroSessions)")
                        .fontWeight(.medium)
                }

                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.purple)
                    Text("平均生产力")
                    Spacer()
                    Text(String(format: "%.1f%%", monthStats.avgProductivity))
                        .fontWeight(.medium)
                }
            }
            .font(.caption)
        }
        .padding()
    }

    // 月度生产力趋势
    private var monthProductivityTrend: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("生产力趋势")
                .font(.subheadline)
                .fontWeight(.medium)

            // 简单的生产力趋势图（使用条形图）
            // 使用缓存的生产力数据计算周趋势
            let weeklyProductivity = calculateWeeklyProductivityFromCache()

            VStack(spacing: 8) {
                ForEach(Array(weeklyProductivity.enumerated()), id: \.offset) { index, productivity in
                    HStack {
                        Text("第\(index + 1)周")
                            .font(.caption)
                            .frame(width: 40, alignment: .leading)

                        GeometryReader { geometry in
                            HStack(spacing: 0) {
                                Rectangle()
                                    .fill(Color.green.opacity(0.7))
                                    .frame(width: geometry.size.width * CGFloat(productivity / 100))

                                Spacer(minLength: 0)
                            }
                        }
                        .frame(height: 8)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)

                        Text(String(format: "%.0f%%", productivity))
                            .font(.caption)
                            .frame(width: 35, alignment: .trailing)
                    }
                }
            }
        }
        .padding()
    }

    // 辅助方法
    private let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        return formatter
    }()

    private let selectedDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 EEEE"
        return formatter
    }()



    private func calculateMonthStats() -> (activeDays: Int, totalActiveTime: TimeInterval, pomodoroSessions: Int, avgProductivity: Double) {
        let monthDates = getMonthDates()
        var activeDays = 0
        var totalActiveTime: TimeInterval = 0
        var pomodoroSessions = 0
        var totalProductivity: Double = 0

        for date in monthDates {
            let dayEvents = eventManager.eventsForDate(date)
            let appStats = activityMonitor.getAppUsageStats(for: date)

            if !dayEvents.isEmpty || !appStats.isEmpty {
                activeDays += 1
            }

            // 计算活跃时间（番茄时间+正计时间，不包含休息和自定义事件）
            for event in dayEvents {
                if event.type == .pomodoro || event.type == .countUp {
                    totalActiveTime += event.endTime.timeIntervalSince(event.startTime)
                }
            }

            pomodoroSessions += dayEvents.filter { $0.type == .pomodoro }.count

            let productivity = activityMonitor.getProductivityAnalysis(for: date)
            totalProductivity += productivity.productivityScore
        }

        let avgProductivity = activeDays > 0 ? totalProductivity / Double(activeDays) : 0

        return (activeDays, totalActiveTime, pomodoroSessions, avgProductivity)
    }

    private func calculateWeeklyProductivity() -> [Double] {
        let monthDates = getMonthDates()
        var weeklyProductivity: [Double] = []

        // 将月份分成4周
        let weeksInMonth = 4
        let daysPerWeek = monthDates.count / weeksInMonth

        for week in 0..<weeksInMonth {
            let startIndex = week * daysPerWeek
            let endIndex = min(startIndex + daysPerWeek, monthDates.count)
            let weekDates = Array(monthDates[startIndex..<endIndex])

            var weekProductivity: Double = 0
            var validDays = 0

            for date in weekDates {
                let productivity = activityMonitor.getProductivityAnalysis(for: date)
                weekProductivity += productivity.productivityScore
                validDays += 1
            }

            let avgWeekProductivity = validDays > 0 ? weekProductivity / Double(validDays) : 0
            weeklyProductivity.append(avgWeekProductivity)
        }

        return weeklyProductivity
    }

    private func getMonthDates(for month: Date? = nil) -> [Date] {
        let targetMonth = month ?? currentMonth
        guard let monthInterval = calendar.dateInterval(of: .month, for: targetMonth) else {
            return []
        }

        var dates: [Date] = []
        let startDate = monthInterval.start
        let numberOfDays = calendar.range(of: .day, in: .month, for: targetMonth)?.count ?? 30

        for i in 0..<numberOfDays {
            if let date = calendar.date(byAdding: .day, value: i, to: startDate) {
                dates.append(date)
            }
        }

        return dates
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

    // MARK: - 异步数据加载方法

    /// 调度数据加载 - 延迟执行以避免阻塞UI
    private func scheduleDataLoading(for month: Date) {
        // 取消之前的加载任务
        dataLoadingTask?.cancel()

        // 延迟执行数据加载，确保UI先更新
        dataLoadingTask = Task {
            // 短暂延迟，让UI先完成更新
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

            // 检查任务是否被取消
            guard !Task.isCancelled else { return }

            // 更新数据月份并显示加载指示器
            await MainActor.run {
                dataMonth = month
                isLoadingData = true

                // 延迟显示加载指示器，避免闪烁
                Task {
                    try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
                    if isLoadingData && !Task.isCancelled {
                        showLoadingIndicator = true
                    }
                }
            }

            await performDataLoading()

            // 数据加载完成后，预加载相邻月份
            await preloadAdjacentMonths()
        }
    }

    /// 异步预加载整个月的数据
    private func loadMonthDataAsync() {
        // 取消之前的加载任务
        dataLoadingTask?.cancel()

        // 立即设置加载状态
        isLoadingData = true

        // 创建新的异步任务
        dataLoadingTask = Task {
            await performDataLoading()
        }
    }

    /// 执行实际的数据加载操作
    @MainActor
    private func performDataLoading() async {
        let monthDates = getMonthDates(for: dataMonth)

        // 并发加载数据
        async let eventsCache = loadEventsData(for: monthDates)
        async let activityCache = loadActivityData(for: monthDates)

        // 等待两个任务完成
        let (loadedEvents, loadedActivity) = await (eventsCache, activityCache)

        // 检查任务是否被取消
        guard !Task.isCancelled else { return }

        // 更新缓存数据（在主线程）
        monthEventsCache = loadedEvents
        monthActivityCache = loadedActivity

        // 平滑地隐藏加载状态
        withAnimation(.easeOut(duration: 0.3)) {
            isLoadingData = false
            showLoadingIndicator = false
        }
    }

    /// 批量加载事件数据 - 优化版本（使用EventManager的批量查询）
    private func loadEventsData(for dates: [Date]) async -> [Date: [PomodoroEvent]] {
        // 在后台线程执行数据查询，使用EventManager的优化批量查询
        return await Task.detached { [eventManager] in
            // 使用EventManager的批量查询方法，利用其内置缓存
            return eventManager.eventsForDates(dates)
        }.value
    }

    /// 批量加载活动数据 - 优化版本（使用批量查询）
    private func loadActivityData(for dates: [Date]) async -> [Date: [AppUsageStats]] {
        // 在后台线程执行数据查询，使用ActivityMonitorManager的批量查询
        return await Task.detached { [activityMonitor] in
            // 使用ActivityMonitorManager的批量查询方法
            return activityMonitor.getAppUsageStatsForDates(dates)
        }.value
    }

    /// 预加载相邻月份数据
    private func preloadAdjacentMonths() async {
        let currentMonthKey = monthFormatter.string(from: dataMonth)

        // 如果当前月份已经预加载过，跳过
        guard !preloadedMonths.contains(currentMonthKey) else { return }

        // 标记当前月份为已预加载
        _ = await MainActor.run {
            preloadedMonths.insert(currentMonthKey)
        }

        // 获取前一个月和后一个月
        guard let previousMonth = calendar.date(byAdding: .month, value: -1, to: dataMonth),
              let nextMonth = calendar.date(byAdding: .month, value: 1, to: dataMonth) else {
            return
        }

        // 并发预加载相邻月份
        async let previousResult: Void = preloadMonthData(for: previousMonth)
        async let nextResult: Void = preloadMonthData(for: nextMonth)

        // 等待预加载完成
        await previousResult
        await nextResult
    }

    /// 预加载指定月份的数据
    private func preloadMonthData(for month: Date) async {
        let monthKey = monthFormatter.string(from: month)

        // 检查是否已经预加载
        let alreadyPreloaded = await MainActor.run {
            preloadedMonths.contains(monthKey)
        }

        guard !alreadyPreloaded else { return }

        // 执行预加载
        let monthDates = getMonthDates(for: month)

        async let eventsCache = loadEventsData(for: monthDates)
        async let activityCache = loadActivityData(for: monthDates)

        let (loadedEvents, loadedActivity) = await (eventsCache, activityCache)

        // 将预加载的数据合并到缓存中
        await MainActor.run {
            for (date, events) in loadedEvents {
                monthEventsCache[date] = events
            }
            for (date, stats) in loadedActivity {
                monthActivityCache[date] = stats
            }
            preloadedMonths.insert(monthKey)
        }
    }

    // MARK: - 月度统计异步加载方法

    /// 异步加载月度统计数据
    private func loadMonthStatsAsync() {
        // 取消之前的加载任务
        monthStatsLoadingTask?.cancel()

        // 设置加载状态
        isLoadingMonthStats = true

        // 创建异步任务
        monthStatsLoadingTask = Task {
            await performMonthStatsLoading()
        }
    }

    /// 执行月度统计数据加载（优化版本）
    @MainActor
    private func performMonthStatsLoading() async {
        // 先在主线程获取月份日期
        let monthDates = getMonthDates(for: displayMonth)

        // 在后台线程执行数据查询
        let stats = await Task.detached { [eventManager, activityMonitor] in
            // 使用批量查询优化事件数据获取
            let monthEventsData = eventManager.eventsForDates(monthDates)

            var activeDays = 0
            var totalActiveTime: TimeInterval = 0
            var pomodoroSessions = 0
            var totalProductivity: Double = 0

            for date in monthDates {
                let dayEvents = monthEventsData[date] ?? []
                let appStats = activityMonitor.getAppUsageStats(for: date)

                if !dayEvents.isEmpty || !appStats.isEmpty {
                    activeDays += 1
                }

                // 计算活跃时间（番茄时间+正计时间，不包含休息和自定义事件）
                for event in dayEvents {
                    if event.type == .pomodoro || event.type == .countUp {
                        totalActiveTime += event.endTime.timeIntervalSince(event.startTime)
                    }
                }

                pomodoroSessions += dayEvents.filter { $0.type == .pomodoro }.count

                let productivity = activityMonitor.getProductivityAnalysis(for: date)
                totalProductivity += productivity.productivityScore
            }

            let avgProductivity = activeDays > 0 ? totalProductivity / Double(activeDays) : 0

            return (activeDays, totalActiveTime, pomodoroSessions, avgProductivity)
        }.value

        // 检查任务是否被取消
        guard !Task.isCancelled else { return }

        // 更新缓存数据
        monthStats = stats
        isLoadingMonthStats = false
    }

    /// 从缓存数据计算周生产力趋势
    private func calculateWeeklyProductivityFromCache() -> [Double] {
        // 简化版本，基于平均生产力计算
        let avgProductivity = monthStats.avgProductivity
        return [avgProductivity * 0.8, avgProductivity * 0.9, avgProductivity, avgProductivity * 1.1]
    }

    /// 月度统计加载状态视图
    private var monthStatsLoadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(0.8)
            Text("加载月度统计...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - 月视图日期单元格（性能优化版本）
struct MonthDayCell: View {
    let date: Date
    @Binding var selectedDate: Date
    let currentMonth: Date
    let events: [PomodoroEvent]
    let activityStats: [AppUsageStats]
    let cellHeight: CGFloat
    let isLoading: Bool
    @Binding var highlightedEventId: UUID?

    private let calendar = Calendar.current

    // 性能优化：缓存计算属性（移除日期数字缓存，避免视图复用问题）
    @State private var maxVisibleEvents: Int = 1

    private var isSelected: Bool {
        // 安全检查，避免日期比较时的潜在问题
        guard date.timeIntervalSince1970 > 0 else { return false }
        return calendar.isDate(date, inSameDayAs: selectedDate)
    }

    private var isCurrentMonth: Bool {
        // 安全检查，避免日期比较时的潜在问题
        guard date.timeIntervalSince1970 > 0 else { return false }
        return calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)
    }

    private var isToday: Bool {
        // 安全检查，避免日期比较时的潜在问题
        guard date.timeIntervalSince1970 > 0 else { return false }
        return calendar.isDateInToday(date)
    }

    private var hasEvents: Bool {
        !events.isEmpty
    }

    private var hasActivity: Bool {
        !activityStats.isEmpty
    }

    private var dayNumber: String {
        // 直接计算日期数字，避免缓存导致的视图复用问题
        let dayComponent = calendar.component(.day, from: date)

        // 调试信息
        #if DEBUG
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        print("🗓️ MonthDayCell: 日期 \(formatter.string(from: date)) -> 日期数字: \(dayComponent)")
        #endif

        return "\(dayComponent)"
    }

    // 计算可显示的事件数量的纯函数
    private func calculateMaxVisibleEvents(for cellHeight: CGFloat, eventCount: Int) -> Int {
        // 安全检查单元格高度
        guard cellHeight > 0 else { return 1 }

        // 预留空间：日期数字区域(~20pt) + 顶部padding(2pt) + 底部padding(2pt) + Spacer
        // 每个事件行大约需要 14pt (字体10pt + padding 4pt)
        // "还有X项"指示器大约需要 12pt
        let reservedSpace: CGFloat = 26 // 日期数字和padding
        let eventRowHeight: CGFloat = 16 // 增加事件行高度以适应更大字体
        let moreIndicatorHeight: CGFloat = 14

        let availableForEvents = max(0, cellHeight - reservedSpace)

        if eventCount <= 1 {
            return max(1, Int(availableForEvents / eventRowHeight))
        } else {
            // 如果有多个事件，需要为"还有X项"指示器预留空间
            let spaceForEventsAndIndicator = max(0, availableForEvents - moreIndicatorHeight)
            return max(1, Int(spaceForEventsAndIndicator / eventRowHeight))
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            // 顶部：日期数字（右上角）
            HStack {
                Spacer()
                Text(dayNumber)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor({
                        if isToday {
                            return .accentColor
                        } else if isCurrentMonth {
                            return .primary
                        } else {
                            return .secondary
                        }
                    }())
            }
            .padding(.top, 2)
            .padding(.trailing, 4)

            // 事件列表区域
            VStack(alignment: .leading, spacing: 2) {
                if isLoading {
                    // 加载状态 - 显示骨架屏
                    loadingSkeletonView
                } else if hasEvents {
                    // 动态显示事件数量
                    ForEach(Array(events.prefix(maxVisibleEvents)), id: \.id) { event in
                        eventRow(for: event)
                    }

                    if events.count > maxVisibleEvents {
                        Text("还有\(events.count - maxVisibleEvents)项")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.secondary.opacity(0.1))
                            )
                    }
                } else if hasActivity {
                    Circle()
                        .fill(Color.gray.opacity(0.6))
                        .frame(width: 4, height: 4)
                        .padding(.leading, 2)
                }
            }
            .padding(.horizontal, 3)

            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: cellHeight, maxHeight: cellHeight)
        .background(
            Rectangle()
                .fill(Color.clear)
                .overlay(
                    Rectangle()
                        .stroke(Color.gray.opacity(0.15), lineWidth: 0.5)
                )
        )
        .contentShape(Rectangle())
        .onAppear {
            // 初始化时计算maxVisibleEvents
            maxVisibleEvents = calculateMaxVisibleEvents(for: cellHeight, eventCount: events.count)
        }
        .onChange(of: cellHeight) { newHeight in
            // 当单元格高度变化时重新计算
            maxVisibleEvents = calculateMaxVisibleEvents(for: newHeight, eventCount: events.count)
        }
        .onChange(of: events.count) { newCount in
            // 当事件数量变化时重新计算
            maxVisibleEvents = calculateMaxVisibleEvents(for: cellHeight, eventCount: newCount)
        }
    }

    // 事件行视图
    private func eventRow(for event: PomodoroEvent) -> some View {
        HStack(alignment: .center, spacing: 3) {
            Circle()
                .fill(event.type.color)
                .frame(width: 4, height: 4)

            Text(event.title)
                .font(.caption)  // 从 .system(size: 9) 升级到 .caption (约11pt)
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)  // 确保左对齐

            Spacer(minLength: 0)  // 确保文本左对齐
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 3)
                .fill(event.type.color.opacity(0.1))
        )
        .scaleEffect(highlightedEventId == event.id ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.5), value: highlightedEventId == event.id)
    }

    // 加载骨架屏视图
    private var loadingSkeletonView: some View {
        VStack(alignment: .leading, spacing: 2) {
            // 显示1-2个骨架条目
            ForEach(0..<min(2, maxVisibleEvents), id: \.self) { _ in
                HStack(alignment: .center, spacing: 3) {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 4, height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 3)
                .padding(.vertical, 2)
            }
        }
        .redacted(reason: .placeholder)
        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isLoading)
    }
}

// MARK: - 事件详情弹窗
struct EventDetailPopover: View {
    let event: PomodoroEvent
    let onSave: (PomodoroEvent) -> Void
    let onDelete: () -> Void

    @EnvironmentObject var eventManager: EventManager
    @State private var title: String
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var eventType: PomodoroEvent.EventType
    @State private var isEditing = false

    init(event: PomodoroEvent, onSave: @escaping (PomodoroEvent) -> Void, onDelete: @escaping () -> Void) {
        self.event = event
        self.onSave = onSave
        self.onDelete = onDelete
        self._title = State(initialValue: event.title)
        self._startTime = State(initialValue: event.startTime)
        self._endTime = State(initialValue: event.endTime)
        self._eventType = State(initialValue: event.type)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题栏
            HStack {
                Text("事件详情")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button(isEditing ? "完成" : "编辑") {
                    if isEditing {
                        saveEvent()
                    }
                    isEditing.toggle()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            Divider()

            if isEditing {
                // 编辑模式
                VStack(alignment: .leading, spacing: 12) {
                    // 事件标题
                    VStack(alignment: .leading, spacing: 4) {
                        Text("标题")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("事件标题", text: $title)
                            .textFieldStyle(.roundedBorder)
                    }

                    // 事件类型
                    VStack(alignment: .leading, spacing: 4) {
                        Text("类型")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("事件类型", selection: $eventType) {
                            ForEach(PomodoroEvent.EventType.allCases, id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // 时间设置
                    VStack(alignment: .leading, spacing: 8) {
                        Text("时间")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("开始")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                DatePicker("", selection: $startTime, displayedComponents: [.hourAndMinute])
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("结束")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                DatePicker("", selection: $endTime, displayedComponents: [.hourAndMinute])
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                            }
                        }
                    }
                }
            } else {
                // 显示模式
                VStack(alignment: .leading, spacing: 12) {
                    // 事件标题
                    VStack(alignment: .leading, spacing: 4) {
                        Text("标题")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(event.title)
                            .font(.body)
                            .fontWeight(.medium)
                    }

                    // 事件类型
                    VStack(alignment: .leading, spacing: 4) {
                        Text("类型")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            Circle()
                                .fill(event.type.color)
                                .frame(width: 12, height: 12)
                            Text(event.type.displayName)
                                .font(.body)
                        }
                    }

                    // 时间信息
                    VStack(alignment: .leading, spacing: 4) {
                        Text("时间")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("开始：\(formatTime(event.startTime))")
                                .font(.body)
                            Text("结束：\(formatTime(event.endTime))")
                                .font(.body)
                            Text("时长：\(formatDuration(event.endTime.timeIntervalSince(event.startTime)))")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Spacer()

            // 底部按钮
            HStack {
                Button("删除", role: .destructive) {
                    eventManager.removeEvent(event)
                    onDelete()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func saveEvent() {
        // 确保结束时间在开始时间之后
        if endTime <= startTime {
            endTime = startTime.addingTimeInterval(1800) // 默认30分钟
        }

        var updatedEvent = event
        updatedEvent.title = title.isEmpty ? eventType.displayName : title
        updatedEvent.startTime = startTime
        updatedEvent.endTime = endTime
        updatedEvent.type = eventType

        eventManager.updateEvent(updatedEvent)
        onSave(updatedEvent)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60

        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
}

// MARK: - 仅日期显示组件
struct DateDisplayOnly: View {
    @Binding var selectedDate: Date
    private let calendar = Calendar.current

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        return formatter
    }()

    private let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()

    private let lunarFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .chinese)
        formatter.dateFormat = "MMMMd"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()

    var body: some View {
        // 只显示日期信息，不显示导航按钮
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(dateFormatter.string(from: selectedDate))
                    .font(.title)
                    .fontWeight(.semibold)

                Text(weekdayFormatter.string(from: selectedDate))
                    .font(.title2)
                    .foregroundColor(.secondary)
            }

            Text(lunarFormatter.string(from: selectedDate))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}


// MARK: - Modern Glass Effect for cross-platform
struct GlassEffectBackground: View {
    var body: some View {
        #if os(macOS)
        // macOS 使用材质效果，为未来的 glassEffect 做准备
//        if #available(macOS 26.0, *) {
//            // 未来版本可以使用 glassEffect (当 API 可用时)
//            // Color.clear.background(.clear).glassEffect(.regular, in:Rectangle())
//            Color.clear.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 0))
//        } else {
            // 当前版本使用增强的材质效果，模拟玻璃效果
            Color.clear
            .background(VisualEffectView(material: "sidebar", blendingMode: "behindWindow"))
//        }
        #else
        // iOS 使用半透明材质效果
        Color.systemBackground
            .opacity(0.95)
            .background(.ultraThinMaterial)
        #endif
    }
}

// MARK: - Legacy VisualEffectView (保持向后兼容)
#if os(macOS)
struct VisualEffectView: NSViewRepresentable {
    let material: String
    let blendingMode: String

    private var nsMaterial: NSVisualEffectView.Material {
        switch material {
        case "sidebar": return .sidebar
        default: return .sidebar
        }
    }

    private var nsBlendingMode: NSVisualEffectView.BlendingMode {
        switch blendingMode {
        case "behindWindow": return .behindWindow
        default: return .behindWindow
        }
    }

    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = nsMaterial
        visualEffectView.blendingMode = nsBlendingMode
        visualEffectView.state = .active
        return visualEffectView
    }

    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = nsMaterial
        visualEffectView.blendingMode = nsBlendingMode
    }
}
#else
// iOS 版本的 VisualEffectView 替代实现
struct VisualEffectView: View {
    let material: String // 在 iOS 上忽略 material 参数
    let blendingMode: String // 在 iOS 上忽略 blendingMode 参数

    var body: some View {
        // 在 iOS 上使用半透明背景替代毛玻璃效果
        Color.systemBackground
            .opacity(0.95)
            .background(.ultraThinMaterial)
    }
}
#endif

// MARK: - 周视图选择覆盖层
struct WeekSelectionOverlay: View {
    let start: CGPoint
    let end: CGPoint
    let containerWidth: CGFloat

    var body: some View {
        let rect = CGRect(
            x: 0,
            y: min(start.y, end.y),
            width: containerWidth,
            height: max(10, abs(end.y - start.y)) // 最小高度
        )

        Rectangle()
            .foregroundColor(Color.blue.opacity(0.2))
            .overlay(
                Rectangle()
                    .stroke(Color.blue.opacity(0.6), lineWidth: 1)
            )
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }
}

// MARK: - 日期事件列表 Popover
struct DayEventsPopover: View {
    let date: Date
    @Binding var selectedEvent: PomodoroEvent?
    @Binding var showingEventDetail: Bool
    @EnvironmentObject var eventManager: EventManager

    // 预计算的数据，避免重复计算
    private var dayEvents: [PomodoroEvent] {
        eventManager.eventsForDate(date)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 EEEE"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 日期标题
            Text(formattedDate)
                .font(.headline)
                .fontWeight(.semibold)

            if dayEvents.isEmpty {
                // 空状态 - 简化版本
                emptyStateView
            } else {
                // 事件列表 - 优化版本
                eventListView
            }
        }
        .padding()
        .frame(width: min(280, getScreenWidth() * 0.4))
    }

    // 空状态视图 - 预构建避免重复创建
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.system(size: 24))
                .foregroundColor(.secondary)
            Text("当日无事件")
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    // 事件列表视图 - 优化性能
    private var eventListView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(dayEvents, id: \.id) { event in
                    OptimizedEventRowView(
                        event: event,
                        selectedEvent: $selectedEvent,
                        showingEventDetail: $showingEventDetail
                    )
                    .environmentObject(eventManager)
                }
            }
        }
        .frame(maxHeight: 300)
    }
}

// MARK: - 优化的事件行视图
struct OptimizedEventRowView: View {
    let event: PomodoroEvent
    @Binding var selectedEvent: PomodoroEvent?
    @Binding var showingEventDetail: Bool
    @EnvironmentObject var eventManager: EventManager

    // 预计算的属性，避免重复计算
    private var formattedDuration: String {
        let duration = event.endTime.timeIntervalSince(event.startTime)
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60

        if hours > 0 {
            return "\(hours)h\(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // 事件类型指示器
            Circle()
                .fill(event.type.color)
                .frame(width: 12, height: 12)

            // 事件信息
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.callout)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(event.formattedTimeRange)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 时长 - 使用预计算的值
            Text(formattedDuration)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
        )
        .contentShape(Rectangle()) // 确保整个区域都可以点击
        .onTapGesture {
            // 立即响应，无延迟
            selectedEvent = event
            showingEventDetail = true
        }
        .buttonStyle(PlainButtonStyle()) // 避免按钮样式干扰
        .popover(
            isPresented: Binding<Bool>(
                get: { showingEventDetail && selectedEvent?.id == event.id },
                set: { newValue in
                    if !newValue {
                        showingEventDetail = false
                        selectedEvent = nil
                    }
                }
            ),
            attachmentAnchor: .point(.trailing),
            arrowEdge: .trailing
        ) {
            // 事件详情popover
            if let selectedEvent = selectedEvent, selectedEvent.id == event.id {
                EventDetailPopover(
                    event: selectedEvent,
                    onSave: { updatedEvent in
                        // 更新事件
                        eventManager.updateEvent(updatedEvent)
                        showingEventDetail = false
                        self.selectedEvent = nil
                    },
                    onDelete: {
                        // 删除事件
                        eventManager.removeEvent(selectedEvent)
                        showingEventDetail = false
                        self.selectedEvent = nil
                    }
                )
                .frame(minWidth: 300)
                .environmentObject(eventManager)
            }
        }
    }
}


