#!/usr/bin/env swift

import Foundation

// 模拟客户端认证测试
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

struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T?
    let message: String
    let timestamp: Int64
}

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

struct User: Codable {
    let userUUID: String
    let userName: String
    let createdAt: String
    
    private enum CodingKeys: String, CodingKey {
        case userUUID = "user_uuid"
        case userName = "user_name"
        case createdAt = "created_at"
    }
}

func testDeviceInit() async {
    print("🧪 开始测试设备认证...")
    
    // 生成测试UUID
    let testUUID = UUID().uuidString
    print("📱 测试设备UUID: \(testUUID)")
    
    let request = DeviceInitRequest(
        deviceUUID: testUUID,
        deviceName: "Test MacBook Pro",
        platform: "macOS"
    )
    
    guard let url = URL(string: "http://localhost:8080/api/auth/device-init") else {
        print("❌ 无效的URL")
        return
    }
    
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "POST"
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    do {
        let encoder = JSONEncoder()
        let requestData = try encoder.encode(request)
        urlRequest.httpBody = requestData
        
        print("📤 发送请求到: \(url)")
        print("📤 请求数据: \(String(data: requestData, encoding: .utf8) ?? "无法解析")")
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 HTTP状态码: \(httpResponse.statusCode)")
        }
        
        print("📥 响应数据: \(String(data: data, encoding: .utf8) ?? "无法解析")")
        
        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(APIResponse<DeviceInitResponse>.self, from: data)
        
        if apiResponse.success {
            print("✅ 认证成功!")
            if let responseData = apiResponse.data {
                print("👤 用户UUID: \(responseData.userUUID)")
                print("🔑 会话Token: \(responseData.sessionToken)")
                print("⏰ 过期时间: \(responseData.expiresAt)")
                print("🆕 是否新用户: \(responseData.isNewUser)")
                if let userInfo = responseData.userInfo {
                    print("📝 用户信息: \(userInfo.userName)")
                }
            }
        } else {
            print("❌ 认证失败: \(apiResponse.message)")
        }
        
    } catch {
        print("❌ 错误: \(error)")
    }
}

// 运行测试
Task {
    await testDeviceInit()
    exit(0)
}

RunLoop.main.run()
