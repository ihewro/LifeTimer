//
//  APIClient.swift
//  PomodoroTimer
//
//  Created by Assistant on 2024
//

import Foundation

/// API响应基础结构
struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T
    let message: String
    let timestamp: Int64
}

/// API客户端
class APIClient {
    private let baseURL: String
    private let session: URLSession
    
    init(baseURL: String) {
        self.baseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }
    
    /// 注册设备
    func registerDevice(_ request: DeviceRegistrationRequest) async throws -> DeviceRegistrationResponse {
        let url = URL(string: "\(baseURL)/api/device/register")!
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let apiResponse = try JSONDecoder().decode(APIResponse<DeviceRegistrationResponse>.self, from: data)
        
        guard apiResponse.success else {
            throw APIError.serverError(apiResponse.message)
        }
        
        return apiResponse.data
    }
    
    /// 全量同步
    func fullSync(deviceUUID: String) async throws -> APIResponse<FullSyncData> {
        let url = URL(string: "\(baseURL)/api/sync/full?device_uuid=\(deviceUUID)")!
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        
        return try decoder.decode(APIResponse<FullSyncData>.self, from: data)
    }
    
    /// 增量同步
    func incrementalSync(_ request: IncrementalSyncRequest) async throws -> APIResponse<IncrementalSyncResponse> {
        let url = URL(string: "\(baseURL)/api/sync/incremental")!
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        urlRequest.httpBody = try encoder.encode(request)
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        
        return try decoder.decode(APIResponse<IncrementalSyncResponse>.self, from: data)
    }
}

/// API错误类型
enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case serverError(String)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - 同步数据模型

/// 全量同步数据
struct FullSyncData: Codable {
    let pomodoroEvents: [ServerPomodoroEvent]
    let systemEvents: [ServerSystemEvent]
    let timerSettings: ServerTimerSettings?
    let serverTimestamp: Int64
    
    private enum CodingKeys: String, CodingKey {
        case pomodoroEvents = "pomodoro_events"
        case systemEvents = "system_events"
        case timerSettings = "timer_settings"
        case serverTimestamp = "server_timestamp"
    }
}

/// 增量同步请求
struct IncrementalSyncRequest: Codable {
    let deviceUUID: String
    let lastSyncTimestamp: Int64
    let changes: SyncChanges
    
    private enum CodingKeys: String, CodingKey {
        case deviceUUID = "device_uuid"
        case lastSyncTimestamp = "last_sync_timestamp"
        case changes
    }
}

/// 增量同步响应
struct IncrementalSyncResponse: Codable {
    let conflicts: [SyncConflict]
    let serverChanges: ServerChanges
    let serverTimestamp: Int64
    
    private enum CodingKeys: String, CodingKey {
        case conflicts
        case serverChanges = "server_changes"
        case serverTimestamp = "server_timestamp"
    }
}

/// 同步变更
struct SyncChanges: Codable {
    let pomodoroEvents: PomodoroEventChanges
    let systemEvents: SystemEventChanges
    let timerSettings: ServerTimerSettings?
    
    private enum CodingKeys: String, CodingKey {
        case pomodoroEvents = "pomodoro_events"
        case systemEvents = "system_events"
        case timerSettings = "timer_settings"
    }
}

/// 番茄事件变更
struct PomodoroEventChanges: Codable {
    let created: [ServerPomodoroEvent]
    let updated: [ServerPomodoroEvent]
    let deleted: [String] // UUIDs
}

/// 系统事件变更
struct SystemEventChanges: Codable {
    let created: [ServerSystemEvent]
}

/// 服务器变更
struct ServerChanges: Codable {
    let pomodoroEvents: [ServerPomodoroEvent]
    let systemEvents: [ServerSystemEvent]
    let timerSettings: ServerTimerSettings?
    
    private enum CodingKeys: String, CodingKey {
        case pomodoroEvents = "pomodoro_events"
        case systemEvents = "system_events"
        case timerSettings = "timer_settings"
    }
}

/// 同步冲突
struct SyncConflict: Codable {
    let type: String
    let uuid: String
    let reason: String
    let serverUpdatedAt: Int64?
    let clientUpdatedAt: Int64?
    
    private enum CodingKeys: String, CodingKey {
        case type
        case uuid
        case reason
        case serverUpdatedAt = "server_updated_at"
        case clientUpdatedAt = "client_updated_at"
    }
}

/// 服务器端番茄事件
struct ServerPomodoroEvent: Codable {
    let uuid: String
    let title: String
    let startTime: Int64
    let endTime: Int64
    let eventType: String
    let isCompleted: Bool
    let createdAt: Int64
    let updatedAt: Int64
    
    private enum CodingKeys: String, CodingKey {
        case uuid
        case title
        case startTime = "start_time"
        case endTime = "end_time"
        case eventType = "event_type"
        case isCompleted = "is_completed"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// 服务器端系统事件
struct ServerSystemEvent: Codable {
    let uuid: String
    let eventType: String
    let timestamp: Int64
    let data: String?
    let createdAt: Int64
    
    private enum CodingKeys: String, CodingKey {
        case uuid
        case eventType = "event_type"
        case timestamp
        case data
        case createdAt = "created_at"
    }
}

/// 服务器端计时器设置
struct ServerTimerSettings: Codable {
    let pomodoroTime: Int
    let shortBreakTime: Int
    let longBreakTime: Int
    let updatedAt: Int64
    
    private enum CodingKeys: String, CodingKey {
        case pomodoroTime = "pomodoro_time"
        case shortBreakTime = "short_break_time"
        case longBreakTime = "long_break_time"
        case updatedAt = "updated_at"
    }
}
