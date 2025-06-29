//
//  SyncManager.swift
//  PomodoroTimer
//
//  Created by Assistant on 2024
//

import Foundation
import Combine

/// 同步状态枚举
enum SyncStatus {
    case idle
    case syncing
    case success
    case error(String)
}

/// 同步管理器
class SyncManager: ObservableObject {
    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncTime: Date?
    @Published var isSyncing = false
    
    private let apiClient: APIClient
    private let deviceUUID: String
    private let userDefaults = UserDefaults.standard
    
    // 依赖的管理器
    private weak var eventManager: EventManager?
    private weak var activityMonitor: ActivityMonitorManager?
    private weak var timerModel: TimerModel?
    
    // 同步配置
    private let syncInterval: TimeInterval = 300 // 5分钟自动同步
    private var syncTimer: Timer?
    
    // UserDefaults键
    private let lastSyncTimeKey = "LastSyncTime"
    private let deviceUUIDKey = "DeviceUUID"
    private let lastSyncTimestampKey = "LastSyncTimestamp"
    
    init(serverURL: String) {
        self.apiClient = APIClient(baseURL: serverURL)
        
        // 获取或生成设备UUID
        if let existingUUID = userDefaults.string(forKey: deviceUUIDKey) {
            self.deviceUUID = existingUUID
        } else {
            self.deviceUUID = UUID().uuidString
            userDefaults.set(self.deviceUUID, forKey: deviceUUIDKey)
        }
        
        // 加载最后同步时间
        if let lastSyncData = userDefaults.object(forKey: lastSyncTimeKey) as? Date {
            self.lastSyncTime = lastSyncData
        }
        
        setupAutoSync()
    }
    
    /// 设置依赖的管理器
    func setDependencies(eventManager: EventManager, activityMonitor: ActivityMonitorManager, timerModel: TimerModel) {
        self.eventManager = eventManager
        self.activityMonitor = activityMonitor
        self.timerModel = timerModel
    }
    
    /// 注册设备
    func registerDevice() async {
        do {
            let deviceInfo = DeviceRegistrationRequest(
                deviceUUID: deviceUUID,
                deviceName: getDeviceName(),
                platform: getPlatform()
            )
            
            let response = try await apiClient.registerDevice(deviceInfo)
            
            DispatchQueue.main.async {
                self.userDefaults.set(response.lastSyncTimestamp, forKey: self.lastSyncTimestampKey)
                print("Device registered successfully: \(response.deviceUUID)")
            }
        } catch {
            DispatchQueue.main.async {
                self.syncStatus = .error("Device registration failed: \(error.localizedDescription)")
            }
        }
    }
    
    /// 执行全量同步
    func performFullSync() async {
        await performSync(isFullSync: true)
    }
    
    /// 执行增量同步
    func performIncrementalSync() async {
        await performSync(isFullSync: false)
    }
    
    /// 手动同步
    func manualSync() async {
        await performIncrementalSync()
    }
    
    /// 启用自动同步
    func enableAutoSync() {
        setupAutoSync()
    }
    
    /// 禁用自动同步
    func disableAutoSync() {
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    // MARK: - Private Methods
    
    private func performSync(isFullSync: Bool) async {
        guard !isSyncing else { return }
        
        DispatchQueue.main.async {
            self.isSyncing = true
            self.syncStatus = .syncing
        }
        
        do {
            if isFullSync {
                try await performFullSyncInternal()
            } else {
                try await performIncrementalSyncInternal()
            }
            
            DispatchQueue.main.async {
                self.syncStatus = .success
                self.lastSyncTime = Date()
                self.userDefaults.set(self.lastSyncTime, forKey: self.lastSyncTimeKey)
                self.isSyncing = false
            }
        } catch {
            DispatchQueue.main.async {
                self.syncStatus = .error(error.localizedDescription)
                self.isSyncing = false
            }
        }
    }
    
    private func performFullSyncInternal() async throws {
        let response = try await apiClient.fullSync(deviceUUID: deviceUUID)
        
        // 应用服务器数据到本地
        await applyServerData(response.data)
        
        // 更新最后同步时间戳
        userDefaults.set(response.data.serverTimestamp, forKey: lastSyncTimestampKey)
    }
    
    private func performIncrementalSyncInternal() async throws {
        let lastSyncTimestamp = userDefaults.object(forKey: lastSyncTimestampKey) as? Int64 ?? 0
        
        // 收集本地变更
        let changes = await collectLocalChanges(since: lastSyncTimestamp)
        
        let request = IncrementalSyncRequest(
            deviceUUID: deviceUUID,
            lastSyncTimestamp: lastSyncTimestamp,
            changes: changes
        )
        
        let response = try await apiClient.incrementalSync(request)
        
        // 处理冲突
        if !response.data.conflicts.isEmpty {
            await handleConflicts(response.data.conflicts)
        }
        
        // 应用服务器变更
        await applyServerChanges(response.data.serverChanges)
        
        // 更新最后同步时间戳
        userDefaults.set(response.data.serverTimestamp, forKey: lastSyncTimestampKey)
    }
    
    private func collectLocalChanges(since timestamp: Int64) async -> SyncChanges {
        // 这里需要实现收集本地变更的逻辑
        // 暂时返回空变更
        return SyncChanges(
            pomodoroEvents: PomodoroEventChanges(created: [], updated: [], deleted: []),
            systemEvents: SystemEventChanges(created: []),
            timerSettings: nil
        )
    }
    
    private func applyServerData(_ data: FullSyncData) async {
        // 应用番茄事件
        if let eventManager = eventManager {
            DispatchQueue.main.async {
                // 清空本地数据并应用服务器数据
                eventManager.events = data.pomodoroEvents.map { serverEvent in
                    PomodoroEvent(
                        id: UUID(uuidString: serverEvent.uuid) ?? UUID(),
                        title: serverEvent.title,
                        startTime: Date(timeIntervalSince1970: TimeInterval(serverEvent.startTime) / 1000),
                        endTime: Date(timeIntervalSince1970: TimeInterval(serverEvent.endTime) / 1000),
                        type: PomodoroEvent.EventType(rawValue: serverEvent.eventType) ?? .custom,
                        isCompleted: serverEvent.isCompleted
                    )
                }
            }
        }
        
        // 应用计时器设置
        if let timerModel = timerModel, let settings = data.timerSettings {
            DispatchQueue.main.async {
                timerModel.pomodoroTime = TimeInterval(settings.pomodoroTime)
                timerModel.shortBreakTime = TimeInterval(settings.shortBreakTime)
                timerModel.longBreakTime = TimeInterval(settings.longBreakTime)
            }
        }
    }
    
    private func applyServerChanges(_ changes: ServerChanges) async {
        // 应用服务器端的变更
        // 实现逻辑类似 applyServerData，但只处理变更的部分
    }
    
    private func handleConflicts(_ conflicts: [SyncConflict]) async {
        // 处理同步冲突
        // 目前采用服务器优先策略
        for conflict in conflicts {
            print("Sync conflict detected: \(conflict)")
        }
    }
    
    private func setupAutoSync() {
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { _ in
            Task {
                await self.performIncrementalSync()
            }
        }
    }
    
    private func getDeviceName() -> String {
        #if os(macOS)
        return Host.current().localizedName ?? "Mac"
        #else
        return UIDevice.current.name
        #endif
    }
    
    private func getPlatform() -> String {
        #if os(macOS)
        return "macOS"
        #else
        return "iOS"
        #endif
    }
}

// MARK: - 数据模型

struct DeviceRegistrationRequest: Codable {
    let deviceUUID: String
    let deviceName: String
    let platform: String
    
    private enum CodingKeys: String, CodingKey {
        case deviceUUID = "device_uuid"
        case deviceName = "device_name"
        case platform
    }
}

struct DeviceRegistrationResponse: Codable {
    let deviceUUID: String
    let lastSyncTimestamp: Int64
    let status: String
    
    private enum CodingKeys: String, CodingKey {
        case deviceUUID = "device_uuid"
        case lastSyncTimestamp = "last_sync_timestamp"
        case status
    }
}
