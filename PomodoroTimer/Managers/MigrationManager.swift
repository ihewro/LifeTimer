//
//  MigrationManager.swift
//  PomodoroTimer
//
//  Created by Assistant on 2024
//

import Foundation
import Combine

/// 数据迁移管理器
/// 负责将基于设备的数据迁移到基于用户账户的系统
class MigrationManager: ObservableObject {
    // MARK: - Published Properties
    @Published var migrationStatus: MigrationStatus = .notRequired
    @Published var migrationProgress: Double = 0.0
    @Published var migrationMessage: String = ""
    
    // MARK: - Private Properties
    private let authManager: AuthManager
    private let apiClient: APIClient
    private let userDefaults = UserDefaults.standard
    
    // UserDefaults Keys
    private let migrationCompletedKey = "MigrationToUserSystemCompleted"
    private let legacyDeviceUUIDKey = "DeviceUUID"
    private let legacyLastSyncTimeKey = "LastSyncTime"
    
    // MARK: - Initialization
    init(authManager: AuthManager, apiClient: APIClient) {
        self.authManager = authManager
        self.apiClient = apiClient
        
        checkMigrationStatus()
    }
    
    // MARK: - Public Methods
    
    /// 检查是否需要迁移
    func checkMigrationStatus() {
        // 如果已经完成迁移，不需要再次迁移
        if userDefaults.bool(forKey: migrationCompletedKey) {
            migrationStatus = .completed
            return
        }
        
        // 检查是否有旧版本数据
        if hasLegacyData() {
            migrationStatus = .required
        } else {
            migrationStatus = .notRequired
        }
    }
    
    /// 执行自动迁移
    func performAutoMigration() async {
        guard migrationStatus == .required else { return }
        
        await MainActor.run {
            migrationStatus = .inProgress
            migrationProgress = 0.0
            migrationMessage = "开始数据迁移..."
        }
        
        do {
            // 步骤1：获取设备UUID
            guard let deviceUUID = userDefaults.string(forKey: legacyDeviceUUIDKey) else {
                throw MigrationError.noLegacyData
            }
            
            await updateProgress(0.2, "检测到设备数据：\(deviceUUID)")
            
            // 步骤2：调用服务端迁移API
            let migrationResult = try await performServerMigration(deviceUUID: deviceUUID)
            
            await updateProgress(0.6, "服务端数据迁移完成")
            
            // 步骤3：更新本地认证状态
            let authResult = AuthResult(
                userUUID: migrationResult.userUUID,
                sessionToken: migrationResult.sessionToken,
                expiresAt: parseDate(migrationResult.expiresAt),
                isNewUser: false,
                userInfo: nil
            )
            
            await authManager.updateAuthState(with: authResult)
            
            await updateProgress(0.8, "更新本地认证状态")
            
            // 步骤4：清理旧数据
            cleanupLegacyData()
            
            await updateProgress(1.0, "迁移完成！")
            
            // 标记迁移完成
            userDefaults.set(true, forKey: migrationCompletedKey)
            
            await MainActor.run {
                migrationStatus = .completed
                migrationMessage = "数据迁移成功完成，您现在可以在多个设备间同步数据"
            }
            
        } catch {
            await MainActor.run {
                migrationStatus = .failed(error.localizedDescription)
                migrationMessage = "迁移失败：\(error.localizedDescription)"
            }
        }
    }
    
    /// 手动迁移到指定用户
    func performManualMigration(targetUserUUID: String) async {
        guard migrationStatus == .required else { return }
        
        await MainActor.run {
            migrationStatus = .inProgress
            migrationProgress = 0.0
            migrationMessage = "开始手动迁移到用户：\(targetUserUUID)"
        }
        
        do {
            guard let deviceUUID = userDefaults.string(forKey: legacyDeviceUUIDKey) else {
                throw MigrationError.noLegacyData
            }
            
            await updateProgress(0.2, "准备迁移数据")
            
            let migrationResult = try await performServerMigration(
                deviceUUID: deviceUUID,
                targetUserUUID: targetUserUUID
            )
            
            await updateProgress(0.8, "迁移完成，更新认证状态")
            
            let authResult = AuthResult(
                userUUID: migrationResult.userUUID,
                sessionToken: migrationResult.sessionToken,
                expiresAt: parseDate(migrationResult.expiresAt),
                isNewUser: false,
                userInfo: nil
            )
            
            await authManager.updateAuthState(with: authResult)
            
            cleanupLegacyData()
            userDefaults.set(true, forKey: migrationCompletedKey)
            
            await updateProgress(1.0, "手动迁移完成")
            
            await MainActor.run {
                migrationStatus = .completed
                migrationMessage = "成功迁移到用户账户：\(targetUserUUID)"
            }
            
        } catch {
            await MainActor.run {
                migrationStatus = .failed(error.localizedDescription)
                migrationMessage = "手动迁移失败：\(error.localizedDescription)"
            }
        }
    }
    
    /// 跳过迁移
    func skipMigration() {
        userDefaults.set(true, forKey: migrationCompletedKey)
        migrationStatus = .skipped
        migrationMessage = "已跳过数据迁移"
    }
    
    /// 重置迁移状态（用于测试）
    func resetMigrationStatus() {
        userDefaults.removeObject(forKey: migrationCompletedKey)
        checkMigrationStatus()
    }
    
    // MARK: - Private Methods
    
    private func hasLegacyData() -> Bool {
        // 检查是否有旧版本的设备UUID和同步数据
        return userDefaults.string(forKey: legacyDeviceUUIDKey) != nil &&
               userDefaults.object(forKey: legacyLastSyncTimeKey) != nil
    }
    
    private func performServerMigration(deviceUUID: String, targetUserUUID: String? = nil) async throws -> MigrationResult {
        let request = MigrationRequest(
            deviceUUID: deviceUUID,
            targetUserUUID: targetUserUUID
        )
        
        let response = try await apiClient.performMigration(request)
        return response.data
    }
    
    @MainActor
    private func updateProgress(_ progress: Double, _ message: String) {
        migrationProgress = progress
        migrationMessage = message
    }
    
    private func cleanupLegacyData() {
        // 保留设备UUID，但清理其他旧数据
        userDefaults.removeObject(forKey: legacyLastSyncTimeKey)
        
        // 可以选择清理其他旧的同步相关数据
        let keysToClean = [
            "LastSyncTimestamp",
            "DeletedEventUUIDs",
            "DeletedEventInfos"
        ]
        
        for key in keysToClean {
            userDefaults.removeObject(forKey: key)
        }
    }
    
    private func parseDate(_ dateString: String) -> Date {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString) ?? Date()
    }
}

// MARK: - Supporting Types

/// 迁移状态
enum MigrationStatus: Equatable {
    case notRequired
    case required
    case inProgress
    case completed
    case skipped
    case failed(String)

    static func == (lhs: MigrationStatus, rhs: MigrationStatus) -> Bool {
        switch (lhs, rhs) {
        case (.notRequired, .notRequired),
             (.required, .required),
             (.inProgress, .inProgress),
             (.completed, .completed),
             (.skipped, .skipped):
            return true
        case (.failed(let lhsMessage), .failed(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
    
    var displayMessage: String {
        switch self {
        case .notRequired:
            return "无需迁移"
        case .required:
            return "需要迁移数据"
        case .inProgress:
            return "正在迁移..."
        case .completed:
            return "迁移完成"
        case .skipped:
            return "已跳过迁移"
        case .failed(let error):
            return "迁移失败：\(error)"
        }
    }
}

/// 迁移错误
enum MigrationError: LocalizedError {
    case noLegacyData
    case serverError
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .noLegacyData:
            return "未找到需要迁移的旧数据"
        case .serverError:
            return "服务器迁移失败"
        case .networkError:
            return "网络连接错误"
        }
    }
}

/// 迁移请求
struct MigrationRequest: Codable {
    let deviceUUID: String
    let targetUserUUID: String?
    
    private enum CodingKeys: String, CodingKey {
        case deviceUUID = "device_uuid"
        case targetUserUUID = "target_user_uuid"
    }
}

/// 迁移结果
struct MigrationResult: Codable {
    let userUUID: String
    let sessionToken: String
    let expiresAt: String
    let migrationSummary: MigrationSummary
    
    private enum CodingKeys: String, CodingKey {
        case userUUID = "user_uuid"
        case sessionToken = "session_token"
        case expiresAt = "expires_at"
        case migrationSummary = "migration_summary"
    }
}

/// 迁移摘要
struct MigrationSummary: Codable {
    let migratedEvents: Int
    let migratedSystemEvents: Int
    let migratedSettings: Int
    
    private enum CodingKeys: String, CodingKey {
        case migratedEvents = "migrated_events"
        case migratedSystemEvents = "migrated_system_events"
        case migratedSettings = "migrated_settings"
    }
}
