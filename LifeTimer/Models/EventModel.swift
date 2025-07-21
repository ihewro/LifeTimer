//
//  EventModel.swift
//  PomodoroTimer
//
//  Created by Developer on 2024.
//

import Foundation
import SwiftUI

struct PomodoroEvent: Identifiable, Codable {
    let id: UUID
    let createdAt: Date
    var updatedAt: Date

    init(title: String, startTime: Date, endTime: Date, type: EventType, isCompleted: Bool = false) {
        self.id = UUID()
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.type = type
        self.isCompleted = isCompleted
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }

    // 从服务端数据创建事件的初始化方法
    init(id: String, title: String, startTime: Date, endTime: Date, type: EventType, isCompleted: Bool, createdAt: Date, updatedAt: Date) {
        self.id = UUID(uuidString: id) ?? UUID()
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.type = type
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    var title: String {
        didSet {
            updatedAt = Date()
        }
    }
    var startTime: Date {
        didSet {
            updatedAt = Date()
        }
    }
    var endTime: Date {
        didSet {
            updatedAt = Date()
        }
    }
    var type: EventType {
        didSet {
            updatedAt = Date()
        }
    }
    var isCompleted: Bool = false {
        didSet {
            updatedAt = Date()
        }
    }
    
    enum EventType: String, CaseIterable, Codable {
        case pomodoro = "番茄时间"
        case rest = "休息"
        case countUp = "正计时"
        case custom = "自定义"

        var displayName: String {
            return self.rawValue
        }

        var color: Color {
            switch self {
            case .pomodoro:
                return .blue
            case .rest:
                return .green
            case .countUp:
                return .purple
            case .custom:
                return .orange
            }
        }

        var icon: String {
            switch self {
            case .pomodoro:
                return "timer"
            case .rest:
                return "cup.and.saucer"
            case .countUp:
                return "stopwatch"
            case .custom:
                return "star"
            }
        }
    }
    
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var formattedTimeRange: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
    }
}

class EventManager: ObservableObject {
    @Published var events: [PomodoroEvent] = [] {
        didSet {
            // 当事件数据变化时，清除缓存
            invalidateCache()
        }
    }

    private let userDefaults = UserDefaults.standard
    private let eventsKey = "PomodoroEvents"

    // MARK: - 性能优化：缓存机制
    private var dateEventsCache: [String: [PomodoroEvent]] = [:]
    private var sortedEventsCache: [PomodoroEvent]?
    private let cacheQueue = DispatchQueue(label: "com.pomodorotimer.eventcache", qos: .userInitiated)
    private let calendar = Calendar.current

    // 缓存键生成器
    private func cacheKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    var dataFilePath: String {
        let libraryPath = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first!
        return "\(libraryPath)/Preferences/\(Bundle.main.bundleIdentifier ?? "PomodoroTimer").plist"
    }

    init() {
        loadEvents()
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name("timerCompleted"),
            object: nil,
            queue: .main
        ) { notification in
            self.addCompletedSession(from: notification)
        }
    }
    
    // MARK: - 缓存管理方法

    /// 清除所有缓存
    private func invalidateCache() {
        cacheQueue.async { [weak self] in
            self?.dateEventsCache.removeAll()
            self?.sortedEventsCache = nil
        }
    }

    /// 清除特定日期的缓存
    private func invalidateCache(for date: Date) {
        let key = cacheKey(for: date)
        cacheQueue.async { [weak self] in
            self?.dateEventsCache.removeValue(forKey: key)
        }
    }

    /// 预热缓存（为常用日期预加载数据）
    func warmupCache(for dates: [Date]) {
        cacheQueue.async { [weak self] in
            guard let self = self else { return }

            for date in dates {
                let key = self.cacheKey(for: date)
                if self.dateEventsCache[key] == nil {
                    let dayEvents = self.events.filter { event in
                        self.calendar.isDate(event.startTime, inSameDayAs: date)
                    }.sorted { $0.startTime < $1.startTime }

                    self.dateEventsCache[key] = dayEvents
                }
            }
        }
    }

    func addEvent(_ event: PomodoroEvent) {
        events.append(event)
        saveEvents()
        notifyEventDataChanged()

        // 清除相关日期的缓存
        invalidateCache(for: event.startTime)
    }

    func removeEvent(_ event: PomodoroEvent) {
        events.removeAll { $0.id == event.id }
        saveEvents()

        // 清除相关日期的缓存
        invalidateCache(for: event.startTime)

        // 创建删除事件的详细信息
        let deletedEventInfo = DeletedEventInfo(from: event, reason: "用户手动删除")

        // 发送删除通知给同步管理器
        NotificationCenter.default.post(
            name: Notification.Name("EventDeleted"),
            object: nil,
            userInfo: [
                "eventUUID": event.id.uuidString,
                "eventInfo": deletedEventInfo
            ]
        )
    }

    func updateEvent(_ event: PomodoroEvent) {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            let oldEvent = events[index]
            events[index] = event
            saveEvents()
            notifyEventDataChanged()

            // 清除相关日期的缓存（可能涉及多个日期）
            invalidateCache(for: oldEvent.startTime)
            invalidateCache(for: event.startTime)
        }
    }
    
    // MARK: - 性能优化：高效的事件查询方法

    /// 获取指定日期的事件（带缓存优化）- 线程安全版本
    func eventsForDate(_ date: Date) -> [PomodoroEvent] {
        let key = cacheKey(for: date)

        // 线程安全的缓存检查
        var cachedEvents: [PomodoroEvent]?
        cacheQueue.sync { [weak self] in
            cachedEvents = self?.dateEventsCache[key]
        }

        // 如果缓存命中，直接返回
        if let cached = cachedEvents {
            return cached
        }

        // 缓存未命中，计算结果
        let dayEvents = events.filter { event in
            calendar.isDate(event.startTime, inSameDayAs: date)
        }.sorted { $0.startTime < $1.startTime }

        // 异步缓存结果，避免阻塞主线程
        cacheQueue.async { [weak self] in
            self?.dateEventsCache[key] = dayEvents
        }

        return dayEvents
    }

    /// 批量获取多个日期的事件（优化版本）- 线程安全
    func eventsForDates(_ dates: [Date]) -> [Date: [PomodoroEvent]] {
        var result: [Date: [PomodoroEvent]] = [:]
        var uncachedDates: [Date] = []

        // 线程安全的缓存检查
        cacheQueue.sync { [weak self] in
            guard let self = self else { return }

            for date in dates {
                let key = self.cacheKey(for: date)
                if let cachedEvents = self.dateEventsCache[key] {
                    result[date] = cachedEvents
                } else {
                    uncachedDates.append(date)
                }
            }
        }

        // 对未缓存的日期进行批量处理
        if !uncachedDates.isEmpty {
            let batchResult = batchProcessEvents(for: uncachedDates)
            // 安全合并结果
            for (date, events) in batchResult {
                result[date] = events
            }
        }

        return result
    }

    /// 批量处理事件查询（减少重复遍历）- 线程安全版本
    private func batchProcessEvents(for dates: [Date]) -> [Date: [PomodoroEvent]] {
        // 确保输入参数有效
        guard !dates.isEmpty else {
            return [:]
        }

        var result: [Date: [PomodoroEvent]] = [:]

        // 初始化结果字典 - 确保每个日期都有一个空数组
        for date in dates {
            result[date] = []
        }

        // 单次遍历所有事件，分配到对应日期
        for event in events {
            for date in dates {
                if calendar.isDate(event.startTime, inSameDayAs: date) {
                    // 安全地添加事件到对应日期
                    if result[date] != nil {
                        result[date]!.append(event)
                    }
                    break // 找到匹配日期后跳出内循环
                }
            }
        }

        // 对每个日期的事件进行排序
        var sortedResult: [Date: [PomodoroEvent]] = [:]
        for (date, eventList) in result {
            let sortedEvents = eventList.sorted { $0.startTime < $1.startTime }
            sortedResult[date] = sortedEvents
        }

        // 异步缓存结果
        cacheQueue.async { [weak self] in
            guard let self = self else { return }
            for (date, events) in sortedResult {
                let key = self.cacheKey(for: date)
                self.dateEventsCache[key] = events
            }
        }

        return sortedResult
    }

    func todayEvents() -> [PomodoroEvent] {
        eventsForDate(Date())
    }

    func completedPomodorosToday() -> Int {
        todayEvents().filter { $0.type == .pomodoro && $0.isCompleted }.count
    }

    func totalFocusTimeToday() -> TimeInterval {
        todayEvents()
            .filter { $0.type == .pomodoro && $0.isCompleted }
            .reduce(0) { $0 + $1.duration }
    }

    /// 搜索事件（优化版本）
    /// - Parameter searchText: 搜索关键词
    /// - Returns: 匹配的事件列表，按时间倒序排列
    func searchEvents(_ searchText: String) -> [PomodoroEvent] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        let trimmedText = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // 使用预排序的事件列表提高搜索性能
        let sortedEvents = getSortedEvents()

        return sortedEvents.filter { event in
            // 搜索标题
            event.title.lowercased().contains(trimmedText) ||
            // 搜索事件类型
            event.type.displayName.lowercased().contains(trimmedText)
        }
        .reversed() // 已经是升序，反转为倒序
    }

    /// 获取排序后的事件列表（带缓存）
    private func getSortedEvents() -> [PomodoroEvent] {
        if let cached = sortedEventsCache {
            return cached
        }

        let sorted = events.sorted { $0.startTime < $1.startTime }
        sortedEventsCache = sorted
        return sorted
    }

    /// 获取日期范围内的事件（优化版本）
    func eventsInDateRange(from startDate: Date, to endDate: Date) -> [PomodoroEvent] {
        return events.filter { event in
            event.startTime >= startDate && event.startTime <= endDate
        }.sorted { $0.startTime < $1.startTime }
    }

    /// 获取指定类型的事件
    func events(ofType type: PomodoroEvent.EventType, on date: Date? = nil) -> [PomodoroEvent] {
        var filtered = events.filter { $0.type == type }

        if let date = date {
            filtered = filtered.filter { event in
                calendar.isDate(event.startTime, inSameDayAs: date)
            }
        }

        return filtered.sorted { $0.startTime < $1.startTime }
    }
    
    private func addCompletedSession(from notification: Notification) {
        guard let userInfo = notification.userInfo,
              let mode = userInfo["mode"],
              let startTime = userInfo["startTime"] as? Date,
              let endTime = userInfo["endTime"] as? Date else {
            // 如果没有足够的信息，使用默认值
            addLegacyCompletedSession()
            return
        }

        let task = userInfo["task"] as? String ?? ""
        let isPartial = userInfo["isPartial"] as? Bool ?? false

        // 根据计时器模式确定事件类型和标题
        let (eventType, title) = getEventTypeAndTitle(for: mode, task: task)

        let event = PomodoroEvent(
            title: title,
            startTime: startTime,
            endTime: endTime,
            type: eventType,
            isCompleted: true
        )
        addEvent(event)

        // 如果是任务切换产生的事件，添加调试日志（仅用于开发调试）
        if isPartial {
            print("📝 创建任务切换事件: \(title), 时长: \(event.formattedDuration)")
        }
    }

    private func addLegacyCompletedSession() {
        // 兼容旧版本的方法
        let now = Date()
        let event = PomodoroEvent(
            title: "专注时间",
            startTime: now.addingTimeInterval(-25 * 60),
            endTime: now,
            type: .pomodoro,
            isCompleted: true
        )
        addEvent(event)
    }

    private func getEventTypeAndTitle(for mode: Any, task: String) -> (PomodoroEvent.EventType, String) {
        // 使用字符串匹配来避免循环依赖
        let modeString = "\(mode)"

        if modeString.contains("singlePomodoro") {
            let title = task.isEmpty ? "番茄时间" : task
            return (.pomodoro, title)
        } else if modeString.contains("pureRest") {
            return (.rest, "休息")
        } else if modeString.contains("countUp") {
            let title = task.isEmpty ? "正计时" : task
            return (.countUp, title)
        } else if modeString.contains("custom") {
            let title = task.isEmpty ? "自定义时间" : task
            return (.custom, title)
        } else {
            // 默认情况
            let title = task.isEmpty ? "专注时间" : task
            return (.pomodoro, title)
        }
    }
    
    func saveEvents() {
        if let encoded = try? JSONEncoder().encode(events) {
            userDefaults.set(encoded, forKey: eventsKey)
        }
    }
    
    private func loadEvents() {
        if let data = userDefaults.data(forKey: eventsKey),
           let decoded = try? JSONDecoder().decode([PomodoroEvent].self, from: data) {
            events = decoded
        }
    }

    /// 发送事件数据变更通知
    private func notifyEventDataChanged() {
        NotificationCenter.default.post(
            name: Notification.Name("EventDataChanged"),
            object: self
        )
    }

    /// 公开方法：手动触发事件数据变更通知（用于同步等场景）
    func triggerDataChangeNotification() {
        notifyEventDataChanged()
    }

    /// 清除所有事件数据
    func clearAllEvents() {
        events.removeAll()
        saveEvents()
        notifyEventDataChanged()
    }

    /// 导出事件数据
    func exportEvents() -> Data? {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            return try encoder.encode(events)
        } catch {
            print("导出事件数据失败: \(error)")
            return nil
        }
    }

    /// 导入事件数据
    func importEvents(from data: Data) -> Bool {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let importedEvents = try decoder.decode([PomodoroEvent].self, from: data)

            // 清除现有数据
            events.removeAll()

            // 导入新数据
            events = importedEvents
            saveEvents()
            notifyEventDataChanged()

            print("成功导入 \(importedEvents.count) 个事件")
            return true
        } catch {
            print("导入事件数据失败: \(error)")
            return false
        }
    }

    // MARK: - 任务选择器优化方法

    /// 线程安全地获取任务标题列表（用于任务选择器）
    func getTaskTitlesSnapshot() -> [String] {
        // 创建事件数组的快照，避免在处理过程中数据被修改
        let eventsSnapshot = events
        return eventsSnapshot.map { $0.title }
    }

    /// 异步获取最近常用任务（优化版本）
    func getRecentTasksAsync(limit: Int = 10) async -> [String] {
        return await withCheckedContinuation { continuation in
            cacheQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: [])
                    return
                }

                // 线程安全地获取事件快照
                let eventsSnapshot = self.events

                // 提取所有任务标题
                let allTitles = eventsSnapshot.map { $0.title }
                let uniqueTitles = Array(Set(allTitles))

                // 计算任务使用频率
                let taskFrequency = Dictionary(grouping: allTitles, by: { $0 })
                    .mapValues { $0.count }

                // 按使用频率排序，取前N个
                let sortedTasks = uniqueTitles
                    .sorted { taskFrequency[$0] ?? 0 > taskFrequency[$1] ?? 0 }
                    .prefix(limit)
                    .map { $0 }

                continuation.resume(returning: sortedTasks)
            }
        }
    }

    /// 获取任务使用频率统计（异步，线程安全）
    func getTaskFrequencyAsync() async -> [String: Int] {
        return await withCheckedContinuation { continuation in
            cacheQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: [:])
                    return
                }

                // 线程安全地获取事件快照
                let eventsSnapshot = self.events

                // 计算任务使用频率
                let allTitles = eventsSnapshot.map { $0.title }
                let taskFrequency = Dictionary(grouping: allTitles, by: { $0 })
                    .mapValues { $0.count }

                continuation.resume(returning: taskFrequency)
            }
        }
    }
}