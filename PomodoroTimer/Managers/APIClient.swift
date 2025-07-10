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

    // MARK: - Authentication Methods

    /// 设备初始化
    func deviceInit(_ request: DeviceInitRequest) async throws -> APIResponse<DeviceInitResponse> {
        let url = URL(string: "\(baseURL)/api/auth/device-init")!
        return try await performRequest(url: url, method: "POST", body: request)
    }

    /// 设备绑定
    func deviceBind(_ request: DeviceBindRequest) async throws -> APIResponse<DeviceBindResponse> {
        let url = URL(string: "\(baseURL)/api/auth/device-bind")!
        return try await performRequest(url: url, method: "POST", body: request)
    }

    /// 设备解绑
    func deviceUnbind(_ request: DeviceUnbindRequest, token: String) async throws -> APIResponse<DeviceUnbindResponse> {
        let url = URL(string: "\(baseURL)/api/auth/device-unbind")!
        return try await performAuthenticatedRequest(url: url, method: "POST", body: request, token: token)
    }

    /// Token刷新
    func refreshToken(token: String) async throws -> APIResponse<TokenRefreshResponse> {
        let url = URL(string: "\(baseURL)/api/auth/refresh")!
        return try await performAuthenticatedRequest(url: url, method: "POST", token: token)
    }

    /// 登出
    func logout(token: String) async throws -> APIResponse<EmptyResponse> {
        let url = URL(string: "\(baseURL)/api/auth/logout")!
        return try await performAuthenticatedRequest(url: url, method: "POST", token: token)
    }
    

    
    /// 全量同步（用户认证版本）
    func fullSync(token: String) async throws -> APIResponse<FullSyncData> {
        let url = URL(string: "\(baseURL)/api/user/sync/full")!
        print("Full sync token: \(token)")
        return try await performAuthenticatedRequest(url: url, method: "GET", token: token)
    }

    /// 增量同步（用户认证版本）
    func incrementalSync(_ request: IncrementalSyncRequest, token: String) async throws -> APIResponse<IncrementalSyncResponse> {
        let url = URL(string: "\(baseURL)/api/user/sync/incremental")!
        return try await performAuthenticatedRequest(url: url, method: "POST", body: request, token: token)
    }



    // MARK: - Private Helper Methods

    /// 执行认证请求
    private func performAuthenticatedRequest<T: Codable, U: Codable>(
        url: URL,
        method: String,
        body: T? = nil,
        token: String
    ) async throws -> APIResponse<U> {
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        // GET 请求不应该包含 HTTP body
        if let body = body, method.uppercased() != "GET" {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .millisecondsSince1970
            urlRequest.httpBody = try encoder.encode(body)
        }

        return try await executeRequest(urlRequest)
    }

    /// 执行认证请求（无 body）
    private func performAuthenticatedRequest<U: Codable>(
        url: URL,
        method: String,
        token: String
    ) async throws -> APIResponse<U> {
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        return try await executeRequest(urlRequest)
    }

    /// 执行普通请求
    private func performRequest<T: Codable, U: Codable>(
        url: URL,
        method: String,
        body: T? = nil
    ) async throws -> APIResponse<U> {
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // GET 请求不应该包含 HTTP body
        if let body = body, method.uppercased() != "GET" {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .millisecondsSince1970
            urlRequest.httpBody = try encoder.encode(body)
        }

        return try await executeRequest(urlRequest)
    }

    /// 执行请求
    private func executeRequest<T: Codable>(_ request: URLRequest) async throws -> APIResponse<T> {
        print("🌐 API Request: \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "unknown")")
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            print("📤 Request Body: \(bodyString)")
        }

        let (data, response) = try await session.data(for: request)

        // 打印响应数据用于调试
        if let responseString = String(data: data, encoding: .utf8) {
            print("📥 Response Data: \(responseString)")
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Invalid HTTP response")
            throw APIError.invalidResponse
        }

        print("📊 HTTP Status: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            // 尝试解析错误响应
            if let errorData = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                print("❌ Server Error: \(errorData.message)")
                throw APIError.serverError(errorData.message)
            }
            print("❌ HTTP Error: \(httpResponse.statusCode)")
            throw APIError.httpError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        do {
            let result = try decoder.decode(APIResponse<T>.self, from: data)
            print("✅ Successfully decoded response")
            return result
        } catch {
            print("❌ JSON Decode Error: \(error)")
            print("❌ Expected type: \(T.self)")
            throw error
        }
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

/// 增量同步请求（用户认证版本）
struct IncrementalSyncRequest: Codable {
    // 移除deviceUUID，改用Authorization header
    let lastSyncTimestamp: Int64
    let changes: SyncChanges

    private enum CodingKeys: String, CodingKey {
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

// MARK: - Authentication Data Models

/// 设备初始化请求
struct DeviceInitRequest: Codable {
    let deviceUUID: String
    let deviceName: String
    let platform: String

    private enum CodingKeys: String, CodingKey {
        case deviceUUID = "device_uuid"
        case deviceName = "device_name"
        case platform
    }
}

/// 设备初始化响应
struct DeviceInitResponse: Codable {
    let userUUID: String
    let sessionToken: String
    let expiresAt: String
    let isNewUser: Bool
    let userInfo: User?

    private enum CodingKeys: String, CodingKey {
        case userUUID = "user_uuid"
        case sessionToken = "session_token"
        case expiresAt = "expires_at"
        case isNewUser = "is_new_user"
        case userInfo = "user_info"
    }
}

/// 设备绑定请求
struct DeviceBindRequest: Codable {
    let userUUID: String
    let deviceUUID: String
    let deviceName: String
    let platform: String

    private enum CodingKeys: String, CodingKey {
        case userUUID = "user_uuid"
        case deviceUUID = "device_uuid"
        case deviceName = "device_name"
        case platform
    }
}

/// 设备绑定响应
struct DeviceBindResponse: Codable {
    let sessionToken: String
    let expiresAt: String
    let userData: User

    private enum CodingKeys: String, CodingKey {
        case sessionToken = "session_token"
        case expiresAt = "expires_at"
        case userData = "user_data"
    }
}

/// Token刷新响应
struct TokenRefreshResponse: Codable {
    let sessionToken: String
    let expiresAt: String

    private enum CodingKeys: String, CodingKey {
        case sessionToken = "session_token"
        case expiresAt = "expires_at"
    }
}

/// 空响应
struct EmptyResponse: Codable {}

/// 空请求
struct EmptyRequest: Codable {}

/// API错误响应
struct APIErrorResponse: Codable {
    let success: Bool
    let message: String
    let timestamp: Int64
}

/// 服务器端系统事件
struct ServerSystemEvent: Codable {
    let uuid: String
    let eventType: String
    let timestamp: Int64
    let data: [String: String]
    let createdAt: Int64
    let updatedAt: Int64?  // 可选字段，因为服务器可能不返回

    private enum CodingKeys: String, CodingKey {
        case uuid, eventType = "event_type", timestamp, data, createdAt = "created_at", updatedAt = "updated_at"
    }

    // 普通初始化方法
    init(uuid: String, eventType: String, timestamp: Int64, data: [String: String], createdAt: Int64, updatedAt: Int64? = nil) {
        self.uuid = uuid
        self.eventType = eventType
        self.timestamp = timestamp
        self.data = data
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        uuid = try container.decode(String.self, forKey: .uuid)
        eventType = try container.decode(String.self, forKey: .eventType)
        timestamp = try container.decode(Int64.self, forKey: .timestamp)
        createdAt = try container.decode(Int64.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Int64.self, forKey: .updatedAt)

        // 处理data字段：可能是字符串或字典
        if let dataString = try? container.decode(String.self, forKey: .data) {
            // 如果是字符串，尝试解析为JSON
            if let jsonData = dataString.data(using: .utf8),
               let parsedData = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                // 将所有值转换为字符串
                data = parsedData.mapValues { String(describing: $0) }
            } else {
                // 如果解析失败，创建一个包含原始字符串的字典
                data = ["raw": dataString]
            }
        } else if let dataDict = try? container.decode([String: String].self, forKey: .data) {
            // 如果已经是字典，直接使用
            data = dataDict
        } else {
            // 如果都不是，使用空字典
            data = [:]
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(uuid, forKey: .uuid)
        try container.encode(eventType, forKey: .eventType)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(data, forKey: .data)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
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

    // 普通初始化方法
    init(uuid: String, title: String, startTime: Int64, endTime: Int64, eventType: String, isCompleted: Bool, createdAt: Int64, updatedAt: Int64) {
        self.uuid = uuid
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.eventType = eventType
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // 自定义解码，处理服务端返回的整数布尔值
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        uuid = try container.decode(String.self, forKey: .uuid)
        title = try container.decode(String.self, forKey: .title)
        startTime = try container.decode(Int64.self, forKey: .startTime)
        endTime = try container.decode(Int64.self, forKey: .endTime)
        eventType = try container.decode(String.self, forKey: .eventType)
        createdAt = try container.decode(Int64.self, forKey: .createdAt)
        updatedAt = try container.decode(Int64.self, forKey: .updatedAt)

        // 处理 is_completed 字段，支持整数和布尔值
        if let boolValue = try? container.decode(Bool.self, forKey: .isCompleted) {
            isCompleted = boolValue
        } else if let intValue = try? container.decode(Int.self, forKey: .isCompleted) {
            isCompleted = intValue != 0
        } else {
            isCompleted = false
        }
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

/// 设备解绑请求
struct DeviceUnbindRequest: Codable {
    let deviceUUID: String

    private enum CodingKeys: String, CodingKey {
        case deviceUUID = "device_uuid"
    }
}

/// 设备解绑响应
struct DeviceUnbindResponse: Codable {
    let deviceUUID: String
    let remainingDeviceCount: Int
    let unboundAt: String

    private enum CodingKeys: String, CodingKey {
        case deviceUUID = "device_uuid"
        case remainingDeviceCount = "remaining_device_count"
        case unboundAt = "unbound_at"
    }
}




