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
        case shortBreak = "短休息"
        case longBreak = "长休息"
        case custom = "自定义"
        
        var displayName: String {
            return self.rawValue
        }
        
        var color: Color {
            switch self {
            case .pomodoro:
                return .blue
            case .shortBreak:
                return .green
            case .longBreak:
                return .green
            case .custom:
                return .orange
            }
        }
        
        var icon: String {
            switch self {
            case .pomodoro:
                return "timer"
            case .shortBreak:
                return "cup.and.saucer"
            case .longBreak:
                return "bed.double"
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
        ) { _ in
            self.addCompletedSession()
        }
    }
    
    func addEvent(_ event: PomodoroEvent) {
        events.append(event)
        saveEvents()
    }
    
    func removeEvent(_ event: PomodoroEvent) {
        events.removeAll { $0.id == event.id }
        saveEvents()
    }
    
    func updateEvent(_ event: PomodoroEvent) {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index] = event
            saveEvents()
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
    
    private func addCompletedSession() {
        let now = Date()
        let event = PomodoroEvent(
            title: "专注时间",
            startTime: now.addingTimeInterval(-25 * 60), // 假设是25分钟前开始
            endTime: now,
            type: .pomodoro,
            isCompleted: true
        )
        addEvent(event)
    }
    
    private func saveEvents() {
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
}