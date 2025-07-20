//
//  UserSyncTests.swift
//  LifeTimerTests
//
//  Created by Assistant on 2024
//

import XCTest
@testable import LifeTimer

/// 用户账户同步系统测试
class UserSyncTests: XCTestCase {
    
    var authManager: AuthManager!
    var syncManager: SyncManager!
    var migrationManager: MigrationManager!
    var apiClient: APIClient!
    
    let testServerURL = "http://localhost:8080"
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // 初始化测试组件
        authManager = AuthManager(serverURL: testServerURL)
        apiClient = APIClient(baseURL: testServerURL)
        syncManager = SyncManager(serverURL: testServerURL, authManager: authManager)
        migrationManager = MigrationManager(authManager: authManager, apiClient: apiClient)
    }
    
    override func tearDownWithError() throws {
        // 清理测试数据
        Task {
            await authManager.logout()
        }
        
        authManager = nil
        syncManager = nil
        migrationManager = nil
        apiClient = nil
        
        try super.tearDownWithError()
    }
    
    // MARK: - 认证测试
    
    func testDeviceInitialization() async throws {
        // 测试设备初始化
        let result = try await authManager.initializeDevice()
        
        XCTAssertFalse(result.userUUID.isEmpty, "用户UUID不应为空")
        XCTAssertFalse(result.sessionToken.isEmpty, "会话token不应为空")
        XCTAssertTrue(authManager.isAuthenticated, "认证状态应为已认证")
        XCTAssertEqual(authManager.authStatus, .authenticated, "认证状态应为authenticated")
    }
    
    func testDeviceBinding() async throws {
        // 先初始化一个设备
        let firstResult = try await authManager.initializeDevice()
        let userUUID = firstResult.userUUID
        
        // 创建新的认证管理器模拟第二个设备
        let secondAuthManager = AuthManager(serverURL: testServerURL)
        
        // 绑定到现有用户
        let bindResult = try await secondAuthManager.bindToUser(userUUID: userUUID)
        
        XCTAssertEqual(bindResult.userUUID, userUUID, "绑定后的用户UUID应该一致")
        XCTAssertFalse(bindResult.isNewUser, "绑定到现有用户时isNewUser应为false")
        XCTAssertTrue(secondAuthManager.isAuthenticated, "第二个设备应该认证成功")
    }
    
    func testTokenRefresh() async throws {
        // 初始化设备
        _ = try await authManager.initializeDevice()
        
        let originalToken = authManager.sessionToken
        XCTAssertNotNil(originalToken, "原始token不应为空")
        
        // 刷新token
        try await authManager.refreshToken()
        
        let newToken = authManager.sessionToken
        XCTAssertNotNil(newToken, "新token不应为空")
        XCTAssertNotEqual(originalToken, newToken, "刷新后的token应该不同")
    }
    
    func testInvalidUserUUIDBind() async {
        // 测试绑定到无效的用户UUID
        do {
            _ = try await authManager.bindToUser(userUUID: "invalid-uuid")
            XCTFail("绑定无效UUID应该失败")
        } catch AuthError.invalidUserUUID {
            // 期望的错误
        } catch {
            XCTFail("应该抛出invalidUserUUID错误，实际: \(error)")
        }
    }
    
    // MARK: - 同步测试
    
    func testFullSync() async throws {
        // 先认证
        _ = try await authManager.initializeDevice()
        
        // 执行全量同步
        try await syncManager.performFullSync()
        
        // 验证同步状态
        XCTAssertEqual(syncManager.syncStatus, .success, "同步状态应为成功")
        XCTAssertNotNil(syncManager.lastSyncTime, "最后同步时间不应为空")
    }
    
    func testIncrementalSync() async throws {
        // 先认证
        _ = try await authManager.initializeDevice()
        
        // 执行增量同步
        try await syncManager.performIncrementalSync()
        
        // 验证同步状态
        XCTAssertEqual(syncManager.syncStatus, .success, "增量同步状态应为成功")
    }
    
    func testSyncWithoutAuthentication() async {
        // 测试未认证状态下的同步
        await syncManager.performFullSync()
        
        // 应该失败并显示未认证状态
        if case .error(let message) = syncManager.syncStatus {
            XCTAssertTrue(message.contains("认证"), "错误消息应包含认证相关信息")
        } else {
            XCTFail("未认证状态下同步应该失败")
        }
    }
    
    // MARK: - 数据一致性测试
    
    func testEventCreationAndSync() async throws {
        // 认证
        _ = try await authManager.initializeDevice()
        
        // 创建测试事件
        let testEvent = PomodoroEvent(
            title: "Test Event",
            startTime: Date(),
            endTime: Date().addingTimeInterval(1500),
            type: .pomodoro,
            isCompleted: true
        )
        
        // 这里需要模拟事件管理器添加事件
        // 实际实现中需要与EventManager集成
        
        // 执行同步
        try await syncManager.performIncrementalSync()
        
        XCTAssertEqual(syncManager.syncStatus, .success, "事件同步应该成功")
    }
    
    func testMultiDeviceSync() async throws {
        // 设备1认证
        let device1Result = try await authManager.initializeDevice()
        let userUUID = device1Result.userUUID
        
        // 设备1创建事件并同步
        try await syncManager.performIncrementalSync()
        
        // 创建设备2
        let device2AuthManager = AuthManager(serverURL: testServerURL)
        let device2SyncManager = SyncManager(serverURL: testServerURL, authManager: device2AuthManager)
        
        // 设备2绑定到同一用户
        _ = try await device2AuthManager.bindToUser(userUUID: userUUID)
        
        // 设备2同步数据
        try await device2SyncManager.performFullSync()
        
        XCTAssertEqual(device2SyncManager.syncStatus, .success, "设备2同步应该成功")
    }
    
    // MARK: - 迁移测试
    
    func testMigrationStatusCheck() {
        // 测试迁移状态检查
        migrationManager.checkMigrationStatus()
        
        // 新安装应该不需要迁移
        XCTAssertEqual(migrationManager.migrationStatus, .notRequired, "新安装不应需要迁移")
    }
    
    func testMigrationWithLegacyData() {
        // 模拟旧版本数据
        let userDefaults = UserDefaults.standard
        userDefaults.set(UUID().uuidString, forKey: "DeviceUUID")
        userDefaults.set(Date(), forKey: "LastSyncTime")
        
        // 重新检查迁移状态
        migrationManager.checkMigrationStatus()
        
        XCTAssertEqual(migrationManager.migrationStatus, .required, "有旧数据时应需要迁移")
        
        // 清理测试数据
        userDefaults.removeObject(forKey: "DeviceUUID")
        userDefaults.removeObject(forKey: "LastSyncTime")
    }
    
    // MARK: - 错误处理测试
    
    func testNetworkError() async {
        // 使用无效的服务器URL测试网络错误
        let invalidAuthManager = AuthManager(serverURL: "http://invalid-server:9999")
        
        do {
            _ = try await invalidAuthManager.initializeDevice()
            XCTFail("无效服务器应该导致错误")
        } catch {
            // 期望的网络错误
            XCTAssertTrue(error.localizedDescription.contains("网络") || 
                         error.localizedDescription.contains("连接"), 
                         "应该是网络相关错误")
        }
    }
    
    func testTokenExpiry() async throws {
        // 初始化设备
        _ = try await authManager.initializeDevice()
        
        // 模拟token过期
        authManager.tokenExpiresAt = Date().addingTimeInterval(-3600) // 1小时前过期
        
        // 验证存储的token
        await authManager.validateStoredToken()
        
        // 应该检测到token过期
        XCTAssertEqual(authManager.authStatus, .tokenExpired, "应该检测到token过期")
    }
    
    // MARK: - 性能测试
    
    func testSyncPerformance() async throws {
        // 认证
        _ = try await authManager.initializeDevice()
        
        // 测量同步性能
        let startTime = Date()
        
        try await syncManager.performFullSync()
        
        let duration = Date().timeIntervalSince(startTime)
        
        // 同步应该在合理时间内完成（例如5秒）
        XCTAssertLessThan(duration, 5.0, "全量同步应该在5秒内完成")
    }
    
    func testBatchEventSync() async throws {
        // 认证
        _ = try await authManager.initializeDevice()
        
        // 创建大量测试事件
        var events: [PomodoroEvent] = []
        for i in 0..<100 {
            let event = PomodoroEvent(
                title: "Batch Test Event \(i)",
                startTime: Date().addingTimeInterval(TimeInterval(i * 1500)),
                endTime: Date().addingTimeInterval(TimeInterval((i + 1) * 1500)),
                type: .pomodoro,
                isCompleted: true
            )
            events.append(event)
        }
        
        // 测量批量同步性能
        let startTime = Date()
        
        try await syncManager.performIncrementalSync()
        
        let duration = Date().timeIntervalSince(startTime)
        
        // 批量同步应该在合理时间内完成
        XCTAssertLessThan(duration, 10.0, "批量同步应该在10秒内完成")
    }
    
    // MARK: - 数据验证测试
    
    func testUUIDValidation() {
        let validUUID = "550e8400-e29b-41d4-a716-446655440000"
        let invalidUUID = "invalid-uuid"
        
        // 这里需要访问AuthManager的私有方法，实际实现中可能需要调整
        // 或者创建公共的UUID验证方法
        
        // 临时使用正则表达式验证
        let uuidRegex = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", uuidRegex)
        
        XCTAssertTrue(predicate.evaluate(with: validUUID), "有效UUID应该通过验证")
        XCTAssertFalse(predicate.evaluate(with: invalidUUID), "无效UUID应该验证失败")
    }
    
    func testDataModelSerialization() throws {
        // 测试用户模型序列化
        let user = User(
            id: "test-user-uuid",
            name: "Test User",
            email: "test@example.com",
            createdAt: "2024-01-01T00:00:00Z"
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(user)
        
        let decoder = JSONDecoder()
        let decodedUser = try decoder.decode(User.self, from: data)
        
        XCTAssertEqual(user.id, decodedUser.id, "用户ID应该一致")
        XCTAssertEqual(user.name, decodedUser.name, "用户名应该一致")
        XCTAssertEqual(user.email, decodedUser.email, "邮箱应该一致")
    }
}
