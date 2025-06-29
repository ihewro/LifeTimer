//
//  SystemEventStore.swift
//  PomodoroTimer
//
//  Created by Assistant on 2024
//

import Foundation
import SwiftUI

/// 系统事件存储管理器
class SystemEventStore: ObservableObject {
    static let shared = SystemEventStore()
    
    @Published var events: [SystemEvent] = []
    @Published var isLoading = false
    
    private let fileURL: URL
    private let maxEvents = 10000 // 最大事件数量限制
    
    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = documentsPath.appendingPathComponent("system_events.json")
        loadEvents()
    }
    
    /// 保存事件
    func saveEvent(_ event: SystemEvent) {
        DispatchQueue.main.async {
            self.events.append(event)
            
            // 限制事件数量，删除最旧的事件
            if self.events.count > self.maxEvents {
                self.events.removeFirst(self.events.count - self.maxEvents)
            }
            
            self.saveToFile()
        }
    }
    
    /// 批量保存事件
    func saveEvents(_ newEvents: [SystemEvent]) {
        DispatchQueue.main.async {
            self.events.append(contentsOf: newEvents)
            
            // 限制事件数量
            if self.events.count > self.maxEvents {
                self.events.removeFirst(self.events.count - self.maxEvents)
            }
            
            self.saveToFile()
        }
    }
    
    /// 清除所有事件
    func clearAllEvents() {
        DispatchQueue.main.async {
            self.events.removeAll()
            self.saveToFile()
        }
    }
    
    /// 清除指定日期之前的事件
    func clearEventsBefore(_ date: Date) {
        DispatchQueue.main.async {
            self.events.removeAll { $0.timestamp < date }
            self.saveToFile()
        }
    }
    
    /// 获取指定日期的事件
    func getEvents(for date: Date) -> [SystemEvent] {
        let calendar = Calendar.current
        return events.filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
    }
    
    /// 获取指定日期范围的事件
    func getEvents(from startDate: Date, to endDate: Date) -> [SystemEvent] {
        return events.filter { event in
            event.timestamp >= startDate && event.timestamp <= endDate
        }
    }
    
    /// 获取应用使用统计
    func getAppUsageStats(for date: Date) -> [AppUsageStats] {
        let dayEvents = getEvents(for: date)
        var appStats: [String: (totalTime: TimeInterval, count: Int, lastUsed: Date?)] = [:]
        
        // 计算每个应用的使用时间
        var currentApp: String?
        var appStartTime: Date?
        
        for event in dayEvents.sorted(by: { $0.timestamp < $1.timestamp }) {
            switch event.type {
            case .appActivated:
                // 结束上一个应用的计时
                if let lastApp = currentApp, let startTime = appStartTime {
                    let duration = event.timestamp.timeIntervalSince(startTime)
                    let current = appStats[lastApp] ?? (totalTime: 0, count: 0, lastUsed: nil)
                    appStats[lastApp] = (totalTime: current.totalTime + duration, 
                                       count: current.count + 1, 
                                       lastUsed: event.timestamp)
                }
                
                // 开始新应用的计时
                if let appName = event.appName {
                    currentApp = appName
                    appStartTime = event.timestamp
                }
                
            case .appTerminated:
                // 如果终止的是当前应用，结束计时
                if let appName = event.appName, appName == currentApp,
                   let startTime = appStartTime {
                    let duration = event.timestamp.timeIntervalSince(startTime)
                    let current = appStats[appName] ?? (totalTime: 0, count: 0, lastUsed: nil)
                    appStats[appName] = (totalTime: current.totalTime + duration, 
                                       count: current.count, 
                                       lastUsed: event.timestamp)
                    currentApp = nil
                    appStartTime = nil
                }
                
            default:
                break
            }
        }
        
        // 如果还有正在运行的应用，计算到当前时间的使用时长
        if let lastApp = currentApp, let startTime = appStartTime {
            let duration = Date().timeIntervalSince(startTime)
            let current = appStats[lastApp] ?? (totalTime: 0, count: 0, lastUsed: nil)
            appStats[lastApp] = (totalTime: current.totalTime + duration, 
                               count: current.count, 
                               lastUsed: Date())
        }
        
        return appStats.map { (appName, stats) in
            AppUsageStats(
                appName: appName,
                totalTime: stats.totalTime,
                activationCount: stats.count,
                lastUsed: stats.lastUsed
            )
        }.sorted { $0.totalTime > $1.totalTime }
    }
    
    /// 获取网站访问统计
    func getWebsiteStats(for date: Date) -> [WebsiteStats] {
        let dayEvents = getEvents(for: date)
        let urlEvents = dayEvents.filter { $0.type == .urlVisit }
        
        var websiteStats: [String: (visits: Int, totalTime: TimeInterval, lastVisited: Date?)] = [:]
        
        for event in urlEvents {
            guard let domain = event.domain,
                  let duration = event.duration else { continue }
            
            let current = websiteStats[domain] ?? (visits: 0, totalTime: 0, lastVisited: nil)
            websiteStats[domain] = (
                visits: current.visits + 1,
                totalTime: current.totalTime + duration,
                lastVisited: max(current.lastVisited ?? event.timestamp, event.timestamp)
            )
        }
        
        return websiteStats.map { (domain, stats) in
            WebsiteStats(
                domain: domain,
                visits: stats.visits,
                totalTime: stats.totalTime,
                lastVisited: stats.lastVisited
            )
        }.sorted { $0.totalTime > $1.totalTime }
    }
    
    /// 获取今日总体统计
    func getTodayOverview() -> (activeTime: TimeInterval, appSwitches: Int, websiteVisits: Int) {
        let todayEvents = getEvents(for: Date())
        
        let appSwitches = todayEvents.filter { $0.type == .appActivated }.count
        let websiteVisits = todayEvents.filter { $0.type == .urlVisit }.count
        
        // 计算活跃时间（简化计算）
        let activeEvents = todayEvents.filter { 
            $0.type == .userActive || $0.type == .appActivated 
        }
        let activeTime = TimeInterval(activeEvents.count * 60) // 假设每个事件代表1分钟活跃时间
        
        return (activeTime: activeTime, appSwitches: appSwitches, websiteVisits: websiteVisits)
    }
    
    // MARK: - Private Methods
    
    private func saveToFile() {
        DispatchQueue.global(qos: .background).async {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(self.events)
                try data.write(to: self.fileURL)
            } catch {
                print("Failed to save events: \(error)")
            }
        }
    }
    
    private func loadEvents() {
        DispatchQueue.global(qos: .background).async {
            do {
                let data = try Data(contentsOf: self.fileURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let loadedEvents = try decoder.decode([SystemEvent].self, from: data)
                
                DispatchQueue.main.async {
                    self.events = loadedEvents
                    self.isLoading = false
                }
            } catch {
                print("Failed to load events: \(error)")
                DispatchQueue.main.async {
                    self.events = []
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Helper Extensions

extension SystemEventStore {
    /// 记录事件的便利方法
    func recordEvent(type: SystemEventType, data: [String: Any] = [:]) {
        let event = SystemEvent(type: type, data: data)
        saveEvent(event)
    }
}