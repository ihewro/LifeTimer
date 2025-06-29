//
//  SystemEvent.swift
//  PomodoroTimer
//
//  Created by Assistant on 2024
//

import Foundation

/// 系统事件类型枚举
enum SystemEventType: String, CaseIterable, Codable {
    case appActivated = "app_activated"
    case appTerminated = "app_terminated"
    case urlVisit = "url_visit"
    case systemSleep = "system_sleep"
    case systemWake = "system_wake"
    case userActive = "user_active"
    case userInactive = "user_inactive"
    case screenLocked = "screen_locked"
    case screenUnlocked = "screen_unlocked"
    
    var displayName: String {
        switch self {
        case .appActivated:
            return "应用激活"
        case .appTerminated:
            return "应用终止"
        case .urlVisit:
            return "网页访问"
        case .systemSleep:
            return "系统休眠"
        case .systemWake:
            return "系统唤醒"
        case .userActive:
            return "用户活跃"
        case .userInactive:
            return "用户非活跃"
        case .screenLocked:
            return "屏幕锁定"
        case .screenUnlocked:
            return "屏幕解锁"
        }
    }
}

/// 系统事件数据结构
struct SystemEvent: Codable, Identifiable {
    let id = UUID()
    let type: SystemEventType
    let timestamp: Date
    let data: [String: String] // 简化为String类型以便于编码
    
    private enum CodingKeys: String, CodingKey {
        case type, timestamp, data
    }
    
    init(type: SystemEventType, timestamp: Date = Date(), data: [String: Any] = [:]) {
        self.type = type
        self.timestamp = timestamp
        // 将Any类型转换为String类型
        self.data = data.compactMapValues { "\($0)" }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(SystemEventType.self, forKey: .type)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        data = try container.decode([String: String].self, forKey: .data)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(data, forKey: .data)
    }
    
    // 便利方法获取特定数据
    var appName: String? {
        return data["app"]
    }
    
    var url: String? {
        return data["url"]
    }
    
    var domain: String? {
        return data["domain"]
    }
    
    var duration: TimeInterval? {
        guard let durationString = data["duration"] else { return nil }
        return TimeInterval(durationString)
    }
}

/// 应用使用统计
struct AppUsageStats {
    let appName: String
    let totalTime: TimeInterval
    let activationCount: Int
    let lastUsed: Date?
    
    var formattedTime: String {
        let hours = Int(totalTime) / 3600
        let minutes = Int(totalTime) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
}

/// 网站访问统计
struct WebsiteStats {
    let domain: String
    let visits: Int
    let totalTime: TimeInterval
    let lastVisited: Date?
    
    var formattedTime: String {
        let hours = Int(totalTime) / 3600
        let minutes = Int(totalTime) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
}