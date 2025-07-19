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
    @Published var events: [PomodoroEvent] = []

    private let userDefaults = UserDefaults.standard
    private let eventsKey = "PomodoroEvents"

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
    
    func addEvent(_ event: PomodoroEvent) {
        events.append(event)
        saveEvents()
        notifyEventDataChanged()
    }
    
    func removeEvent(_ event: PomodoroEvent) {
        events.removeAll { $0.id == event.id }
        saveEvents()

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
            events[index] = event
            saveEvents()
            notifyEventDataChanged()
        }
    }
    
    func eventsForDate(_ date: Date) -> [PomodoroEvent] {
        let calendar = Calendar.current
        return events.filter { event in
            calendar.isDate(event.startTime, inSameDayAs: date)
        }.sorted { $0.startTime < $1.startTime }
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

    /// 搜索事件
    /// - Parameter searchText: 搜索关键词
    /// - Returns: 匹配的事件列表，按时间倒序排列
    func searchEvents(_ searchText: String) -> [PomodoroEvent] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        let trimmedText = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return events.filter { event in
            // 搜索标题
            event.title.lowercased().contains(trimmedText) ||
            // 搜索事件类型
            event.type.displayName.lowercased().contains(trimmedText)
        }
        .sorted { $0.startTime > $1.startTime } // 按时间倒序排列，最新的在前
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
}