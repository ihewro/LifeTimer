//
//  SyncManager.swift
//  PomodoroTimer
//
//  Created by Assistant on 2024
//

import Foundation
import Combine
import SwiftUI

/// 删除事件的详细信息
struct DeletedEventInfo: Codable {
    let uuid: String
    let title: String
    let eventType: String
    let startTime: Date
    let endTime: Date
    let deletedAt: Date
    let reason: String? // 删除原因（可选）

    init(from event: PomodoroEvent, reason: String? = nil) {
        self.uuid = event.id.uuidString
        self.title = event.title
        self.eventType = event.type.rawValue
        self.startTime = event.startTime
        self.endTime = event.endTime
        self.deletedAt = Date()
        self.reason = reason
    }
}

/// 同步状态枚举
enum SyncStatus {
    case notAuthenticated
    case authenticating
    case idle
    case syncing
    case success
    case error(String)
    case tokenExpired
}

enum SyncError: LocalizedError {
    case notAuthenticated
    case tokenExpired
    case networkError
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "用户未认证，请先登录"
        case .tokenExpired:
            return "认证已过期，请重新登录"
        case .networkError:
            return "网络连接错误"
        case .serverError(let message):
            return "服务器错误：\(message)"
        }
    }
}

/// 同步模式 - 类似Git的操作模式
enum SyncMode: String, Codable {
    case forceOverwriteLocal = "forceOverwriteLocal"    // 强制覆盖本地 (类似 git reset --hard origin/main)
    case forceOverwriteRemote = "forceOverwriteRemote"   // 强制覆盖远程 (类似 git push --force)
    case smartMerge = "smartMerge"            // 智能同步 (类似 git pull + git push)
    case incremental = "incremental"          // 增量同步
    case autoIncremental = "autoIncremental"  // 自动增量同步

    var displayName: String {
        switch self {
        case .forceOverwriteLocal:
            return "强制覆盖本地"
        case .forceOverwriteRemote:
            return "强制覆盖远程"
        case .smartMerge:
            return "智能同步"
        case .incremental:
            return "增量同步"
        case .autoIncremental:
            return "自动同步"
        }
    }

    var description: String {
        switch self {
        case .forceOverwriteLocal:
            return "用服务端数据完全替换本地数据"
        case .forceOverwriteRemote:
            return "用本地数据完全替换服务端数据"
        case .smartMerge:
            return "双向同步：拉取并推送数据"
        case .incremental:
            return "增量同步：仅同步变更的数据"
        case .autoIncremental:
            return "自动增量同步：定时同步变更的数据"
        }
    }

    var icon: String {
        switch self {
        case .forceOverwriteLocal:
            return "arrow.down.circle.fill"
        case .forceOverwriteRemote:
            return "arrow.up.circle.fill"
        case .smartMerge:
            return "arrow.up.arrow.down"
        case .incremental:
            return "arrow.triangle.2.circlepath"
        case .autoIncremental:
            return "clock.arrow.2.circlepath"
        }
    }

    var isDestructive: Bool {
        switch self {
        case .forceOverwriteLocal, .forceOverwriteRemote:
            return true
        default:
            return false
        }
    }
}

/// 同步管理器
class SyncManager: ObservableObject {
    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncTime: Date?
    @Published var isSyncing = false
    @Published var serverURL: String = ""
    @Published var pendingSyncCount: Int = 0

    // 标记是否正在进行同步更新操作（用于避免误跟踪删除）
    private var isPerformingSyncUpdate = false

    // 调试模式
    @Published var isDebugMode = false
    private var deletionTrackingLog: [String] = []
    @Published var serverData: ServerDataPreview? = nil
    @Published var serverDataSummary: ServerDataSummary? = nil // 轻量级数据摘要
    @Published var isLoadingServerData = false
    @Published var localData: LocalDataPreview? = nil

    // MARK: - 增量变更数据存储
    @Published var serverIncrementalChanges: IncrementalSyncResponse? = nil
    @Published var syncWorkspace: SyncWorkspace? = nil
    @Published var lastSyncRecord: SyncRecord? = nil
    @Published var syncHistory: [SyncRecord] = []

    // 服务器响应状态
    @Published var lastServerResponseStatus: String = "未知"
    @Published var lastServerResponseTime: Date? = nil
    @Published var serverConnectionStatus: String = "未连接"

    // 数据预览缓存
    private var serverDataSummaryCache: ServerDataSummary? = nil
    private var summaryCache: (summary: ServerDataSummary, timestamp: Date)? = nil
    private let summaryCacheExpiry: TimeInterval = 30 // 30秒缓存过期时间

    // 跟踪删除的事件
    private var deletedEventUUIDs: Set<String> = [] // 保持向后兼容
    private var deletedEventInfos: [String: DeletedEventInfo] = [:] // 新的详细信息存储
    private let deletedEventsKey = "DeletedEventUUIDs"
    private let deletedEventInfosKey = "DeletedEventInfos"

    private var apiClient: APIClient
    private var authManager: AuthManager?
    private let userDefaults = UserDefaults.standard



    // 设备UUID（向后兼容）
    private let deviceUUID: String
    
    // 依赖的管理器
    private weak var eventManager: EventManager?
    private weak var activityMonitor: ActivityMonitorManager?
    private weak var timerModel: TimerModel?
    
    // 同步配置
    private let syncInterval: TimeInterval = 5*60 // 5分钟自动同步
    private var syncTimer: Timer?
    
    // UserDefaults键
    private let lastSyncTimeKey = "LastSyncTime"
    private let deviceUUIDKey = "DeviceUUID"
    private let lastSyncTimestampKey = "LastSyncTimestamp"
    private let serverURLKey = "ServerURL"
    private let syncSystemEventsKey = "SyncSystemEvents"

    // 同步设置
    @Published var syncSystemEvents: Bool = true
    
    init(serverURL: String, authManager: AuthManager? = nil) {
        self.serverURL = serverURL
        self.apiClient = APIClient(baseURL: serverURL)
        self.authManager = authManager

        // 获取或生成设备UUID（向后兼容）
        let deviceUUIDKey = "DeviceUUID"
        if let existingUUID = UserDefaults.standard.string(forKey: deviceUUIDKey) {
            self.deviceUUID = existingUUID
        } else {
            self.deviceUUID = UUID().uuidString
            UserDefaults.standard.set(self.deviceUUID, forKey: deviceUUIDKey)
        }

        // 加载最后同步时间
        if let lastSyncData = userDefaults.object(forKey: lastSyncTimeKey) as? Date {
            self.lastSyncTime = lastSyncData
        }

        // 加载服务器URL
        self.serverURL = userDefaults.string(forKey: serverURLKey) ?? serverURL

        // 加载同步系统事件设置（默认为true）
        self.syncSystemEvents = userDefaults.object(forKey: syncSystemEventsKey) as? Bool ?? false

        setupAutoSync()

        // 初始化时计算待同步数据数量
        updatePendingSyncCount()

        // 加载同步历史
        loadSyncHistory()

        // 加载删除的事件列表
        loadDeletedEvents()
        loadDeletedEventInfos()

        // 监听设置变更
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange),
            name: TimerModel.settingsChangedNotification,
            object: nil
        )

        // 监听事件删除
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(eventDeleted(_:)),
            name: Notification.Name("EventDeleted"),
            object: nil
        )

        // 监听事件变更（新增、修改）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(eventDataChanged),
            name: Notification.Name("EventDataChanged"),
            object: nil
        )
    }
    
    /// 设置依赖的管理器
    func setDependencies(eventManager: EventManager, activityMonitor: ActivityMonitorManager, timerModel: TimerModel) {
        self.eventManager = eventManager
        self.activityMonitor = activityMonitor
        self.timerModel = timerModel
    }

    /// 设置认证管理器（用于后续升级到用户系统）
    func setAuthManager(_ authManager: AuthManager) {
        self.authManager = authManager
    }

    @objc private func settingsDidChange() {
        print("🔄 SyncManager: Received settings change notification")
        Task {
            await generateSyncWorkspace()
            loadLocalDataPreview()
            updatePendingSyncCount()
            print("🔄 SyncManager: Updated sync workspace and pending count after settings change")
        }
    }

    @objc private func eventDeleted(_ notification: Notification) {
        if let eventUUID = notification.userInfo?["eventUUID"] as? String {
            // 尝试获取事件详细信息
            if let eventInfo = notification.userInfo?["eventInfo"] as? DeletedEventInfo {
                trackDeletedEvent(eventInfo)
            } else {
                // 向后兼容：只有UUID的情况
                trackDeletedEvent(eventUUID)
            }
        }
    }

    @objc private func eventDataChanged() {
        // 当事件数据发生变更时，立即刷新本地数据预览和同步工作区
        Task {
            loadLocalDataPreview()
            await generateSyncWorkspace()
            updatePendingSyncCount()
        }
    }



    /// 确保用户已认证
    private func ensureAuthenticated() async throws {
        guard let authManager = authManager,
              authManager.isAuthenticated,
              let _ = authManager.sessionToken else {
            throw SyncError.notAuthenticated
        }

        // 检查token是否即将过期
        if let expiresAt = authManager.tokenExpiresAt,
           expiresAt.timeIntervalSinceNow < 300 { // 5分钟内过期
            try await authManager.refreshToken()
        }
    }



    /// 获取设备名称
    private func getDeviceName() -> String {
        #if canImport(Cocoa)
        return Host.current().localizedName ?? "Mac"
        #else
        return "Unknown Device"
        #endif
    }

    /// 获取平台信息
    private func getPlatform() -> String {
        #if os(macOS)
        return "macOS"
        #elseif os(iOS)
        return "iOS"
        #else
        return "Unknown"
        #endif
    }
    
    /// 执行增量同步
    func performIncrementalSync() async {
        await performSync(mode: .autoIncremental)
    }
    
    /// 启用自动同步
    func enableAutoSync() {
//        setupAutoSync()
    }
    
    /// 禁用自动同步
    func disableAutoSync() {
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    // MARK: - Private Methods

    /// 执行指定模式的同步
    func performSync(mode: SyncMode) async {
        guard !isSyncing else { return }

        let startTime = Date()

        DispatchQueue.main.async {
            self.isSyncing = true
            self.syncStatus = .syncing
        }

        do {
            let (uploadedCount, downloadedCount, conflictCount, syncDetails) = try await performSyncInternal(mode: mode)

            let duration = Date().timeIntervalSince(startTime)
            let record = SyncRecord(
                syncMode: mode,
                success: true,
                uploadedCount: uploadedCount,
                downloadedCount: downloadedCount,
                conflictCount: conflictCount,
                duration: duration,
                syncDetails: syncDetails
            )

            // 同步成功后刷新所有数据预览和工作区状态
            clearServerDataSummaryCache() // 清除缓存，确保获取最新数据
            await loadServerDataPreview() // 总是刷新服务端数据
            loadLocalDataPreview()
            await generateSyncWorkspace()
            updatePendingSyncCount() // 重新计算待同步数据数量

            DispatchQueue.main.async {
                self.syncStatus = .success
                self.lastSyncTime = Date()
                self.userDefaults.set(self.lastSyncTime, forKey: self.lastSyncTimeKey)
                self.isSyncing = false

                // 更新服务器响应状态
                self.lastServerResponseStatus = "同步成功 (HTTP 200)"
                self.lastServerResponseTime = Date()
                self.serverConnectionStatus = "已连接"

                // 清除已同步的删除记录
                self.clearSyncedDeletions()

                // 记录同步历史
                self.addSyncRecord(record)

                // 发送同步完成通知，用于UI刷新
                NotificationCenter.default.post(
                    name: Notification.Name("SyncCompleted"),
                    object: self
                )
            }
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            let record = SyncRecord(
                syncMode: mode,
                success: false,
                errorMessage: error.localizedDescription,
                duration: duration
            )

            DispatchQueue.main.async {
                self.syncStatus = .error(error.localizedDescription)
                self.isSyncing = false

                // 更新服务器响应状态
                self.lastServerResponseStatus = "同步失败: \(error.localizedDescription)"
                self.lastServerResponseTime = Date()
                self.serverConnectionStatus = "连接失败"

                // 记录同步历史
                self.addSyncRecord(record)
            }
        }
    }

    /// 内部同步实现
    private func performSyncInternal(mode: SyncMode) async throws -> (uploadedCount: Int, downloadedCount: Int, conflictCount: Int, syncDetails: SyncDetails?) {
        // 如果有认证管理器，确保用户已认证
        if authManager != nil {
            try await ensureAuthenticated()
        }

        guard let authManager = authManager,
              let _ = authManager.sessionToken else {
            throw SyncError.notAuthenticated
        }

        // 创建同步详情收集器
        var syncDetailsCollector = SyncDetailsCollector()

        switch mode {
        case .forceOverwriteLocal:
            try await performForceOverwriteLocal(detailsCollector: &syncDetailsCollector)
            let details = syncDetailsCollector.build()
            return (0, details.downloadedItems.count, 0, details)

        case .forceOverwriteRemote:
            try await performForceOverwriteRemote(detailsCollector: &syncDetailsCollector)
            let details = syncDetailsCollector.build()
            return (details.uploadedItems.count, 0, 0, details)

        case .smartMerge:
            try await performSmartMerge(detailsCollector: &syncDetailsCollector)
            let details = syncDetailsCollector.build()
            return (details.uploadedItems.count, details.downloadedItems.count, details.conflictItems.count, details)

        case .incremental:
            try await performIncrementalSync(detailsCollector: &syncDetailsCollector)
            let details = syncDetailsCollector.build()
            return (details.uploadedItems.count, details.downloadedItems.count, details.conflictItems.count, details)

        case .autoIncremental:
            try await performIncrementalSync(detailsCollector: &syncDetailsCollector)
            let details = syncDetailsCollector.build()
            return (details.uploadedItems.count, details.downloadedItems.count, details.conflictItems.count, details)
        }
    }



    /// 强制覆盖本地
    private func performForceOverwriteLocal(detailsCollector: inout SyncDetailsCollector) async throws {
        guard let authManager = authManager,
              let token = authManager.sessionToken else {
            throw SyncError.notAuthenticated
        }
        let response = try await apiClient.fullSync(token: token)

        // 收集下载的详情
        collectDownloadDetails(from: response.data, to: &detailsCollector)

        await applyServerData(response.data, mode: .forceOverwriteLocal)
        userDefaults.set(response.data.serverTimestamp, forKey: lastSyncTimestampKey)
    }

    /// 强制覆盖远程
    private func performForceOverwriteRemote(detailsCollector: inout SyncDetailsCollector) async throws {
        // 收集所有本地数据
        let changes = await collectAllLocalData()

        // 收集上传的详情
        collectUploadDetails(from: changes, to: &detailsCollector)

        // 强制覆盖远程的策略：
        // 1. 使用lastSyncTimestamp = 0，表示从头开始同步
        // 2. 发送所有本地数据作为"新增"数据
        // 3. 服务端应该理解这是一个完全替换操作
        guard let authManager = authManager,
              let token = authManager.sessionToken else {
            throw SyncError.notAuthenticated
        }

        let request = IncrementalSyncRequest(
            lastSyncTimestamp: 0, // 使用0表示强制覆盖，服务端应该清空现有数据
            changes: changes
        )

        let response = try await apiClient.incrementalSync(request, token: token)

        // 更新本地的最后同步时间戳
        userDefaults.set(response.data.serverTimestamp, forKey: lastSyncTimestampKey)

        // 强制覆盖远程后，直接基于本地数据更新服务端预览
        // 因为我们刚刚把本地数据推送到了服务端，所以服务端数据应该和本地一致
        await updateServerDataPreviewFromLocal(serverTimestamp: response.data.serverTimestamp)
    }

    /// 更新服务端数据预览（不应用到本地）
    private func updateServerDataPreview(_ data: FullSyncData) async {
        let preview = ServerDataPreview(
            pomodoroEvents: data.pomodoroEvents,
            systemEvents: data.systemEvents,
            timerSettings: data.timerSettings,
            lastUpdated: Date(timeIntervalSince1970: TimeInterval(data.serverTimestamp) / 1000)
        )

        DispatchQueue.main.async {
            self.serverData = preview
        }
    }

    /// 基于本地数据更新服务端数据预览（用于强制覆盖远程后）
    private func updateServerDataPreviewFromLocal(serverTimestamp: Int64) async {
        // 收集本地数据并转换为服务端格式
        var serverPomodoroEvents: [ServerPomodoroEvent] = []
        if let eventManager = eventManager {
            for event in eventManager.events {
                let serverEvent = createServerEventFromLocal(event)
                serverPomodoroEvents.append(serverEvent)
            }
        }

        // 收集本地系统事件并转换为服务端格式（仅在启用同步系统事件时）
        var serverSystemEvents: [ServerSystemEvent] = []
        if syncSystemEvents {
            let systemEvents = SystemEventStore.shared.events
            for systemEvent in systemEvents {
                let serverSystemEvent = createServerSystemEventFromLocal(systemEvent)
                serverSystemEvents.append(serverSystemEvent)
            }
        }

        // 收集本地计时器设置并转换为服务端格式
        var serverTimerSettings: ServerTimerSettings? = nil
        if let timerModel = timerModel {
            serverTimerSettings = ServerTimerSettings(
                pomodoroTime: Int(timerModel.pomodoroTime),
                shortBreakTime: Int(timerModel.shortBreakTime),
                longBreakTime: Int(timerModel.longBreakTime),
                updatedAt: serverTimestamp
            )
        }

        // 创建服务端数据预览
        let preview = ServerDataPreview(
            pomodoroEvents: serverPomodoroEvents,
            systemEvents: serverSystemEvents,
            timerSettings: serverTimerSettings,
            lastUpdated: Date(timeIntervalSince1970: TimeInterval(serverTimestamp) / 1000)
        )

        DispatchQueue.main.async {
            self.serverData = preview
        }
    }





    /// 智能合并 - 使用单一增量同步操作
    private func performSmartMerge(detailsCollector: inout SyncDetailsCollector) async throws {
        // 获取当前的同步基准时间戳
        let lastSyncTimestamp = userDefaults.object(forKey: lastSyncTimestampKey) as? Int64 ?? 0

        // 收集本地变更（基于当前的同步基准时间戳）
        let localChanges = await collectLocalChanges(since: lastSyncTimestamp)

        // 收集上传详情
        collectUploadDetails(from: localChanges, to: &detailsCollector)

        // 执行增量同步：同时发送本地变更并接收服务器变更
        guard let authManager = authManager,
              let token = authManager.sessionToken else {
            throw SyncError.notAuthenticated
        }

        let request = IncrementalSyncRequest(
            lastSyncTimestamp: lastSyncTimestamp,
            changes: localChanges
        )

        let response = try await apiClient.incrementalSync(request, token: token)

        // 收集下载详情（服务器返回的变更）
        collectDownloadDetails(from: response.data.serverChanges, to: &detailsCollector)

        // 收集冲突详情
        collectConflictDetails(from: response.data.conflicts, to: &detailsCollector)

        // 应用服务器端的变更到本地
        await applyServerChanges(response.data.serverChanges)

        // 最后统一更新同步时间戳
        userDefaults.set(response.data.serverTimestamp, forKey: lastSyncTimestampKey)

        // 更新服务端数据预览
        await updateServerDataPreviewFromIncrementalResponse(response.data)
    }

    /// 收集增量同步响应的下载详情
    private func collectDownloadDetails(from serverChanges: ServerChanges, to collector: inout SyncDetailsCollector) {
        // 收集番茄事件下载详情
        for event in serverChanges.pomodoroEvents {
            let item = SyncItemDetail(
                id: event.uuid,
                type: .pomodoroEvent,
                operation: .download,
                title: event.title,
                description: "从服务器下载 - \(event.eventType)",
                timestamp: Date(timeIntervalSince1970: TimeInterval(event.updatedAt) / 1000),
                details: SyncItemSpecificDetails(
                    eventStartTime: Date(timeIntervalSince1970: TimeInterval(event.startTime) / 1000),
                    eventEndTime: Date(timeIntervalSince1970: TimeInterval(event.endTime) / 1000),
                    eventType: event.eventType,
                    taskName: event.title
                )
            )
            collector.addDownloadedItem(item)
        }

        // 收集系统事件下载详情
        for event in serverChanges.systemEvents {
            let item = SyncItemDetail(
                id: event.uuid,
                type: .systemEvent,
                operation: .download,
                title: event.eventType,
                description: "从服务器下载系统事件",
                timestamp: Date(timeIntervalSince1970: TimeInterval(event.createdAt) / 1000),
                details: SyncItemSpecificDetails(
                    systemEventType: event.eventType,
                    systemEventData: String(describing: event.data)
                )
            )
            collector.addDownloadedItem(item)
        }

        // 收集计时器设置下载详情
        if let settings = serverChanges.timerSettings {
            let item = SyncItemDetail(
                id: "timer_settings",
                type: .timerSettings,
                operation: .download,
                title: "计时器设置",
                description: "从服务器下载计时器设置",
                timestamp: Date(timeIntervalSince1970: TimeInterval(settings.updatedAt) / 1000),
                details: SyncItemSpecificDetails(
                    pomodoroTime: TimeInterval(settings.pomodoroTime),
                    shortBreakTime: TimeInterval(settings.shortBreakTime),
                    longBreakTime: TimeInterval(settings.longBreakTime)
                )
            )
            collector.addDownloadedItem(item)
        }
    }

    /// 收集冲突详情
    private func collectConflictDetails(from conflicts: [SyncConflict], to collector: inout SyncDetailsCollector) {
        for conflict in conflicts {
            let item = SyncItemDetail(
                id: conflict.uuid,
                type: conflict.type == "pomodoro_event" ? .pomodoroEvent : .systemEvent,
                operation: .conflict,
                title: "冲突项目",
                description: "同步冲突: \(conflict.reason)",
                timestamp: Date(),
                details: nil
            )
            collector.addConflictItem(item)
        }
    }

    /// 应用服务器端的增量变更到本地
    private func applyServerChanges(_ serverChanges: ServerChanges) async {
        // 1. 应用番茄事件变更
        if let eventManager = eventManager {
            DispatchQueue.main.async {
                // 设置同步更新标志，防止误跟踪删除
                self.isPerformingSyncUpdate = true

                // 智能合并服务器端的番茄事件
                self.smartMergeServerPomodoroEvents(serverChanges.pomodoroEvents, into: eventManager)

                // 重置同步更新标志
                self.isPerformingSyncUpdate = false
            }
        }

        // 2. 应用系统事件变更
        await applySystemEventChanges(serverChanges.systemEvents)

        // 3. 应用计时器设置变更
        if let serverSettings = serverChanges.timerSettings {
            await applyTimerSettingsChanges(serverSettings)
        }
    }

    /// 智能合并服务器端的番茄事件
    private func smartMergeServerPomodoroEvents(_ serverEvents: [ServerPomodoroEvent], into eventManager: EventManager) {
        let existingEvents = eventManager.events
        var mergedEvents = existingEvents

        for serverEvent in serverEvents {
            // 查找本地是否已存在该事件
            if let existingIndex = existingEvents.firstIndex(where: { $0.id.uuidString == serverEvent.uuid }) {
                // 事件已存在：比较更新时间，使用较新的版本
                let localEvent = existingEvents[existingIndex]
                let serverUpdatedAt = Date(timeIntervalSince1970: TimeInterval(serverEvent.updatedAt) / 1000)

                if serverUpdatedAt > localEvent.updatedAt {
                    // 服务端版本更新，替换本地数据
                    mergedEvents[existingIndex] = self.createEventFromServer(serverEvent)
                }
                // 如果本地版本更新或相同，保留本地数据（不做任何操作）
            } else {
                // 新事件：直接添加服务端事件
                mergedEvents.append(self.createEventFromServer(serverEvent))
            }
        }

        // 按时间排序并应用
        eventManager.events = mergedEvents.sorted { $0.startTime < $1.startTime }
        // 立即保存到持久化存储
        eventManager.saveEvents()
    }

    /// 应用系统事件变更
    private func applySystemEventChanges(_ serverSystemEvents: [ServerSystemEvent]) async {
        // 如果禁用了系统事件同步，则跳过
        guard syncSystemEvents else { return }

        let systemEventStore = SystemEventStore.shared

        DispatchQueue.main.async {
            // 智能合并系统事件
            self.smartMergeServerSystemEvents(serverSystemEvents, into: systemEventStore)
        }
    }

    /// 智能合并服务器端的系统事件
    private func smartMergeServerSystemEvents(_ serverEvents: [ServerSystemEvent], into systemEventStore: SystemEventStore) {
        let existingEvents = systemEventStore.events
        var mergedEvents = existingEvents

        for serverEvent in serverEvents {
            // 查找本地是否已存在该事件
            if !existingEvents.contains(where: { $0.id.uuidString == serverEvent.uuid }) {
                // 新事件：添加到本地
                mergedEvents.append(self.createSystemEventFromServer(serverEvent))
            }
            // 系统事件通常不会更新，所以如果已存在就跳过
        }

        // 按时间排序并应用
        systemEventStore.events = mergedEvents.sorted { $0.timestamp < $1.timestamp }
        // 保存合并后的数据
        systemEventStore.saveCurrentEvents()
    }

    /// 应用计时器设置变更
    private func applyTimerSettingsChanges(_ serverSettings: ServerTimerSettings) async {
        guard let timerModel = timerModel else { return }

        DispatchQueue.main.async {
            // 比较服务器设置和本地设置的更新时间
            // 注意：这里我们需要一个方式来跟踪本地设置的更新时间
            // 暂时直接应用服务器设置（可以根据需要添加更复杂的冲突解决逻辑）
            timerModel.pomodoroTime = TimeInterval(serverSettings.pomodoroTime)
            timerModel.shortBreakTime = TimeInterval(serverSettings.shortBreakTime)
            timerModel.longBreakTime = TimeInterval(serverSettings.longBreakTime)
        }
    }

    /// 从增量同步响应更新服务端数据预览
    private func updateServerDataPreviewFromIncrementalResponse(_ responseData: IncrementalSyncResponse) async {
        // 获取当前的服务端数据预览
        let currentServerData = self.serverData

        // 基于当前预览数据和增量变更构建新的预览
        var updatedPomodoroEvents = currentServerData?.pomodoroEvents ?? []
        var updatedSystemEvents = currentServerData?.systemEvents ?? []
        var updatedTimerSettings = currentServerData?.timerSettings

        // 应用番茄事件变更
        for serverEvent in responseData.serverChanges.pomodoroEvents {
            // 查找是否已存在
            if let existingIndex = updatedPomodoroEvents.firstIndex(where: { $0.uuid == serverEvent.uuid }) {
                // 更新现有事件
                updatedPomodoroEvents[existingIndex] = serverEvent
            } else {
                // 添加新事件
                updatedPomodoroEvents.append(serverEvent)
            }
        }

        // 应用系统事件变更
        for serverEvent in responseData.serverChanges.systemEvents {
            // 查找是否已存在
            if !updatedSystemEvents.contains(where: { $0.uuid == serverEvent.uuid }) {
                // 添加新事件
                updatedSystemEvents.append(serverEvent)
            }
        }

        // 应用计时器设置变更
        if let serverSettings = responseData.serverChanges.timerSettings {
            updatedTimerSettings = serverSettings
        }

        // 创建新的服务端数据预览
        let preview = ServerDataPreview(
            pomodoroEvents: updatedPomodoroEvents,
            systemEvents: updatedSystemEvents,
            timerSettings: updatedTimerSettings,
            lastUpdated: Date(timeIntervalSince1970: TimeInterval(responseData.serverTimestamp) / 1000)
        )

        DispatchQueue.main.async {
            self.serverData = preview
        }
    }
    


    /// 增量同步 - 直接使用增量同步API
    private func performIncrementalSync(detailsCollector: inout SyncDetailsCollector) async throws {
        // 获取当前的同步基准时间戳
        let lastSyncTimestamp = userDefaults.object(forKey: lastSyncTimestampKey) as? Int64 ?? 0

        // 收集本地变更（基于当前的同步基准时间戳）
        let localChanges = await collectLocalChanges(since: lastSyncTimestamp)

        // 收集上传详情
        collectUploadDetails(from: localChanges, to: &detailsCollector)

        // 执行增量同步：同时发送本地变更并接收服务器变更
        guard let authManager = authManager,
              let token = authManager.sessionToken else {
            throw SyncError.notAuthenticated
        }

        let request = IncrementalSyncRequest(
            lastSyncTimestamp: lastSyncTimestamp,
            changes: localChanges
        )

        let response = try await apiClient.incrementalSync(request, token: token)

        // 收集下载详情（服务器返回的变更）
        collectDownloadDetails(from: response.data.serverChanges, to: &detailsCollector)

        // 收集冲突详情
        collectConflictDetails(from: response.data.conflicts, to: &detailsCollector)

        // 应用服务器端的变更到本地
        await applyServerChanges(response.data.serverChanges)

        // 最后统一更新同步时间戳
        userDefaults.set(response.data.serverTimestamp, forKey: lastSyncTimestampKey)

        // 更新服务端数据预览
        await updateServerDataPreviewFromIncrementalResponse(response.data)
    }

    private func collectLocalChanges(since timestamp: Int64) async -> SyncChanges {
        let lastSyncDate = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        var createdEvents: [ServerPomodoroEvent] = []
        var updatedEvents: [ServerPomodoroEvent] = []

        // 收集番茄事件变更
        if let eventManager = eventManager {
            for event in eventManager.events {
                // 创建一个临时的ServerPomodoroEvent来发送到服务器
                // 注意：这里我们需要创建一个符合服务器期望格式的事件
                let serverEvent = createServerEventFromLocal(event)

                if event.createdAt > lastSyncDate {
                    // 新创建的事件
                    createdEvents.append(serverEvent)
                } else if event.updatedAt > lastSyncDate {
                    // 更新的事件
                    updatedEvents.append(serverEvent)
                }
            }
        }

        // 收集系统事件变更（仅在启用同步系统事件时）
        var createdSystemEvents: [ServerSystemEvent] = []
        if syncSystemEvents {
            let systemEvents = SystemEventStore.shared.events
            for systemEvent in systemEvents {
                if systemEvent.timestamp > lastSyncDate {
                    let serverSystemEvent = createServerSystemEventFromLocal(systemEvent)
                    createdSystemEvents.append(serverSystemEvent)
                }
            }
        }

        // 收集计时器设置变更（只有真正变更时才包含）
        var timerSettings: ServerTimerSettings? = nil
        if let timerModel = timerModel, let serverData = serverData {
            let hasTimerSettingsChanged = checkTimerSettingsChanged(timerModel: timerModel, serverData: serverData)
            if hasTimerSettingsChanged {
                timerSettings = ServerTimerSettings(
                    pomodoroTime: Int(timerModel.pomodoroTime),
                    shortBreakTime: Int(timerModel.shortBreakTime),
                    longBreakTime: Int(timerModel.longBreakTime),
                    updatedAt: Int64(Date().timeIntervalSince1970 * 1000)
                )
            }
        }

        return SyncChanges(
            pomodoroEvents: PomodoroEventChanges(
                created: createdEvents,
                updated: updatedEvents,
                deleted: Array(deletedEventUUIDs) // 包含删除的事件UUID
            ),
            systemEvents: SystemEventChanges(created: createdSystemEvents),
            timerSettings: timerSettings
        )
    }

    /// 从本地系统事件创建服务端系统事件格式
    private func createServerSystemEventFromLocal(_ systemEvent: SystemEvent) -> ServerSystemEvent {
        return ServerSystemEvent(
            uuid: systemEvent.id.uuidString,
            eventType: systemEvent.type.rawValue,
            timestamp: Int64(systemEvent.timestamp.timeIntervalSince1970 * 1000),
            data: systemEvent.data,
            createdAt: Int64(systemEvent.timestamp.timeIntervalSince1970 * 1000),
            updatedAt: Int64(systemEvent.timestamp.timeIntervalSince1970 * 1000)
        )
    }

    /// 从本地事件创建服务端事件格式
    private func createServerEventFromLocal(_ event: PomodoroEvent) -> ServerPomodoroEvent {
        // 注意：这里我们需要手动创建ServerPomodoroEvent
        // 由于ServerPomodoroEvent有自定义的init(from decoder:)，我们需要创建一个临时的结构
        return ServerPomodoroEvent(
            uuid: event.id.uuidString,
            title: event.title,
            startTime: Int64(event.startTime.timeIntervalSince1970 * 1000),
            endTime: Int64(event.endTime.timeIntervalSince1970 * 1000),
            eventType: mapEventTypeToServer(event.type),
            isCompleted: event.isCompleted,
            createdAt: Int64(event.createdAt.timeIntervalSince1970 * 1000),
            updatedAt: Int64(event.updatedAt.timeIntervalSince1970 * 1000)
        )
    }

    /// 映射事件类型到服务端格式
    private func mapEventTypeToServer(_ type: PomodoroEvent.EventType) -> String {
        switch type {
        case .pomodoro:
            return "pomodoro"
        case .rest:
            return "rest"
        case .countUp:
            return "count_up"
        case .custom:
            return "custom"
        }
    }

    /// 映射服务端事件类型到本地格式
    private func mapServerEventTypeToLocal(_ eventType: String) -> PomodoroEvent.EventType {
        switch eventType {
        case "pomodoro":
            return .pomodoro
        case "rest", "short_break", "long_break":
            return .rest
        case "count_up":
            return .countUp
        case "custom":
            return .custom
        default:
            return .custom
        }
    }

    /// 从服务端事件创建本地事件
    private func createEventFromServer(_ serverEvent: ServerPomodoroEvent) -> PomodoroEvent {
        return PomodoroEvent(
            id: serverEvent.uuid,
            title: serverEvent.title,
            startTime: Date(timeIntervalSince1970: TimeInterval(serverEvent.startTime) / 1000),
            endTime: Date(timeIntervalSince1970: TimeInterval(serverEvent.endTime) / 1000),
            type: mapServerEventTypeToLocal(serverEvent.eventType),
            isCompleted: serverEvent.isCompleted,
            createdAt: Date(timeIntervalSince1970: TimeInterval(serverEvent.createdAt) / 1000),
            updatedAt: Date(timeIntervalSince1970: TimeInterval(serverEvent.updatedAt) / 1000)
        )
    }
    
    /// 应用服务端数据 - 根据同步模式决定如何处理
    private func applyServerData(_ data: FullSyncData, mode: SyncMode = .smartMerge) async {
        // 1. 应用番茄钟事件
        if let eventManager = eventManager {
            DispatchQueue.main.async {
                // 设置同步更新标志，防止误跟踪删除
                self.isPerformingSyncUpdate = true

                switch mode {
                case .forceOverwriteLocal:
                    // 强制覆盖本地：完全使用服务端数据
                    eventManager.events = data.pomodoroEvents.map { self.createEventFromServer($0) }
                    // 立即保存到持久化存储
                    eventManager.saveEvents()

                case .forceOverwriteRemote:
                    // 强制覆盖远程：保持本地数据不变（这个模式在这里不适用）
                    break

                case .smartMerge, .incremental, .autoIncremental:
                    // 智能合并数据
                    self.smartMergeServerData(data, into: eventManager)
                }

                // 重置同步更新标志
                self.isPerformingSyncUpdate = false
            }
        }

        // 2. 应用系统事件
        await applySystemEvents(data.systemEvents, mode: mode)

        // 3. 应用计时器设置
        await applyTimerSettings(data)

        // 应用计时器设置
        if let timerModel = timerModel, let settings = data.timerSettings {
            DispatchQueue.main.async {
                timerModel.pomodoroTime = TimeInterval(settings.pomodoroTime)
                timerModel.shortBreakTime = TimeInterval(settings.shortBreakTime)
                timerModel.longBreakTime = TimeInterval(settings.longBreakTime)
            }
        }
    }

    /// 应用系统事件数据
    private func applySystemEvents(_ serverSystemEvents: [ServerSystemEvent], mode: SyncMode) async {
        // 如果禁用了系统事件同步，则跳过应用系统事件
        guard syncSystemEvents else { return }

        let systemEventStore = SystemEventStore.shared

        DispatchQueue.main.async {
            switch mode {
            case .forceOverwriteLocal:
                // 强制覆盖本地：完全使用服务端数据
                systemEventStore.events = serverSystemEvents.map { self.createSystemEventFromServer($0) }
                // 立即保存到持久化存储
                systemEventStore.saveCurrentEvents()

            case .forceOverwriteRemote:
                // 强制覆盖远程：保持本地数据不变
                break

            case .smartMerge, .incremental, .autoIncremental:
                // 智能合并系统事件
                self.smartMergeSystemEvents(serverSystemEvents, into: systemEventStore)
            }
        }
    }

    /// 从服务端系统事件创建本地系统事件
    private func createSystemEventFromServer(_ serverEvent: ServerSystemEvent) -> SystemEvent {
        let eventType = SystemEventType(rawValue: serverEvent.eventType) ?? .userActive
        return SystemEvent(
            type: eventType,
            timestamp: Date(timeIntervalSince1970: TimeInterval(serverEvent.timestamp) / 1000),
            data: serverEvent.data
        )
    }

    /// 智能合并系统事件
    private func smartMergeSystemEvents(_ serverEvents: [ServerSystemEvent], into systemEventStore: SystemEventStore) {
        let existingEvents = systemEventStore.events
        var mergedEvents: [SystemEvent] = []
        var processedServerUUIDs = Set<String>()

        // 1. 处理服务端系统事件
        for serverEvent in serverEvents {
            processedServerUUIDs.insert(serverEvent.uuid)

            // 查找本地是否已存在该事件
            if let existingIndex = existingEvents.firstIndex(where: { $0.id.uuidString == serverEvent.uuid }) {
                // 事件已存在：比较时间戳，使用较新的版本
                let localEvent = existingEvents[existingIndex]
                let serverTimestamp = Date(timeIntervalSince1970: TimeInterval(serverEvent.timestamp) / 1000)

                if serverTimestamp > localEvent.timestamp {
                    // 服务端版本更新，使用服务端数据
                    mergedEvents.append(self.createSystemEventFromServer(serverEvent))
                } else {
                    // 本地版本更新或相同，保留本地数据
                    mergedEvents.append(localEvent)
                }
            } else {
                // 新事件：直接添加服务端事件
                mergedEvents.append(self.createSystemEventFromServer(serverEvent))
            }
        }

        // 2. 添加本地独有的事件（服务端没有的）
        for localEvent in existingEvents {
            if !processedServerUUIDs.contains(localEvent.id.uuidString) {
                mergedEvents.append(localEvent)
            }
        }

        // 3. 按时间排序并应用
        systemEventStore.events = mergedEvents.sorted { $0.timestamp < $1.timestamp }
        // 保存合并后的数据
        systemEventStore.saveCurrentEvents()
    }

    /// 智能合并服务端数据到本地
    private func smartMergeServerData(_ data: FullSyncData, into eventManager: EventManager) {
        // 设置同步更新标志，防止误跟踪删除
        isPerformingSyncUpdate = true
        defer { isPerformingSyncUpdate = false }

        let existingEvents = eventManager.events
        var mergedEvents: [PomodoroEvent] = []
        var processedServerUUIDs = Set<String>()

        // 1. 处理服务端事件
        for serverEvent in data.pomodoroEvents {
            processedServerUUIDs.insert(serverEvent.uuid)

            // 查找本地是否已存在该事件
            if let existingIndex = existingEvents.firstIndex(where: { $0.id.uuidString == serverEvent.uuid }) {
                // 事件已存在：比较更新时间，使用较新的版本
                let localEvent = existingEvents[existingIndex]
                let serverUpdatedAt = Date(timeIntervalSince1970: TimeInterval(serverEvent.updatedAt) / 1000)

                if serverUpdatedAt > localEvent.updatedAt {
                    // 服务端版本更新，使用服务端数据
                    mergedEvents.append(self.createEventFromServer(serverEvent))
                } else {
                    // 本地版本更新或相同，保留本地数据
                    mergedEvents.append(localEvent)
                }
            } else {
                // 新事件：直接添加服务端事件
                mergedEvents.append(self.createEventFromServer(serverEvent))
            }
        }

        // 2. 添加本地独有的事件（服务端没有的）
        for localEvent in existingEvents {
            if !processedServerUUIDs.contains(localEvent.id.uuidString) {
                mergedEvents.append(localEvent)
            }
        }

        // 3. 按时间排序并应用
        eventManager.events = mergedEvents.sorted { $0.startTime < $1.startTime }
        // 保存合并后的数据
        eventManager.saveEvents()
    }

    /// 应用计时器设置
    private func applyTimerSettings(_ data: FullSyncData) async {
        if let timerModel = timerModel, let settings = data.timerSettings {
            DispatchQueue.main.async {
                timerModel.pomodoroTime = TimeInterval(settings.pomodoroTime)
                timerModel.shortBreakTime = TimeInterval(settings.shortBreakTime)
                timerModel.longBreakTime = TimeInterval(settings.longBreakTime)
            }
        }
    }
    
    private func handleConflicts(_ conflicts: [SyncConflict]) async {
        // 处理同步冲突
        // 目前采用服务器优先策略
        for conflict in conflicts {
            print("Sync conflict detected: \(conflict)")

            // 根据冲突类型进行处理
            switch conflict.type {
            case "pomodoro_event":
                await handlePomodoroEventConflict(conflict)
            case "timer_settings":
                await handleTimerSettingsConflict(conflict)
            default:
                print("Unknown conflict type: \(conflict.type)")
            }
        }
    }

    private func handlePomodoroEventConflict(_ conflict: SyncConflict) async {
        // 对于番茄事件冲突，采用服务器优先策略
        // 实际应用中可能需要更复杂的冲突解决策略
        print("Handling pomodoro event conflict for UUID: \(conflict.uuid)")

        // 可以在这里实现更复杂的冲突解决逻辑
        // 例如：提示用户选择、合并数据等
    }

    private func handleTimerSettingsConflict(_ conflict: SyncConflict) async {
        // 对于计时器设置冲突，也采用服务器优先策略
        print("Handling timer settings conflict")
    }

    /// 获取服务端数据预览（优化版本 - 使用轻量级数据摘要）
    /// 用于初始加载和同步后的完整数据预览
    func loadServerDataPreview() async {
        // 如果正在同步，跳过服务端数据加载，避免冲突
        if isSyncing {
            print("Skipping server data preview load during sync operation")
            return
        }

        // // 检查缓存是否有效
        // if let cache = summaryCache,
        //    Date().timeIntervalSince(cache.timestamp) < summaryCacheExpiry {
        //     print("🎯 使用缓存的服务端数据摘要")
        //     DispatchQueue.main.async {
        //         self.serverDataSummary = cache.summary
        //         self.isLoadingServerData = false
        //         self.lastServerResponseStatus = "缓存 (已缓存)"
        //         self.serverConnectionStatus = "已连接"
        //     }
        //     return
        // }

        print("🔄 开始加载服务端数据摘要...")
        print("📱 设备UUID: \(deviceUUID)")
        print("🌐 服务器URL: \(serverURL)")

        DispatchQueue.main.async {
            self.isLoadingServerData = true
        }

        do {
            // 使用轻量级数据摘要API
            print("📡 请求服务端数据摘要...")
            guard let authManager = authManager,
                  let token = authManager.sessionToken else {
                throw SyncError.notAuthenticated
            }
            let response = try await apiClient.dataSummary(token: token)

            print("✅ 服务端摘要响应成功")
            print("📊 番茄事件数量: \(response.data.summary.pomodoroEventCount)")
            print("📊 系统事件数量: \(response.data.summary.systemEventCount)")
            print("⚙️ 计时器设置: \(response.data.summary.hasTimerSettings ? "已设置" : "未设置")")

            let summary = ServerDataSummary(
                pomodoroEventCount: response.data.summary.pomodoroEventCount,
                systemEventCount: response.data.summary.systemEventCount,
                hasTimerSettings: response.data.summary.hasTimerSettings,
                serverTimestamp: response.data.summary.serverTimestamp,
                lastUpdated: Date(),
                recentEvents: response.data.recentEvents
            )

            // 更新缓存
            summaryCache = (summary: summary, timestamp: Date())

            DispatchQueue.main.async {
                self.serverDataSummary = summary
                self.isLoadingServerData = false
                self.lastServerResponseStatus = "成功 (HTTP 200)"
                self.lastServerResponseTime = Date()
                self.serverConnectionStatus = "已连接"
                print("🎯 服务端数据摘要已更新: \(summary.pomodoroEventCount)个番茄钟, \(summary.systemEventCount)个系统事件")
            }
        } catch {
            print("❌ 加载服务端数据摘要失败: \(error)")
            DispatchQueue.main.async {
                self.serverDataSummary = nil
                self.isLoadingServerData = false
                self.lastServerResponseStatus = "失败: \(error.localizedDescription)"
                self.lastServerResponseTime = Date()
                self.serverConnectionStatus = "连接失败"
            }
        }
    }

    /// 增量拉取远端变更数据（仅用于预览，不应用到本地数据库）
    func loadServerChangesPreview() async {
        // 如果正在同步，跳过服务端变更加载，避免冲突
        if isSyncing {
            print("Skipping server changes preview load during sync operation")
            return
        }

        await loadServerDataPreview()

        print("🔄 开始增量拉取远端变更数据...")
        print("📱 设备UUID: \(deviceUUID)")
        print("🌐 服务器URL: \(serverURL)")

        DispatchQueue.main.async {
            self.isLoadingServerData = true
        }

        do {
            // 获取当前的同步基准时间戳
            let lastSyncTimestamp = userDefaults.object(forKey: lastSyncTimestampKey) as? Int64 ?? 0

            // 创建一个空的本地变更请求，只是为了获取服务端变更
            let emptyChanges = SyncChanges(
                pomodoroEvents: PomodoroEventChanges(created: [], updated: [], deleted: []),
                systemEvents: SystemEventChanges(created: []),
                timerSettings: nil
            )

            let request = IncrementalSyncRequest(
                lastSyncTimestamp: lastSyncTimestamp,
                changes: emptyChanges
            )

            guard let authManager = authManager,
                  let token = authManager.sessionToken else {
                throw SyncError.notAuthenticated
            }

            print("📡 请求增量服务端变更数据...")
            let response = try await apiClient.incrementalSync(request, token: token)

            print("✅ 增量服务端变更响应成功")
            print("📊 服务端番茄事件变更: \(response.data.serverChanges.pomodoroEvents.count)")
            print("📊 服务端系统事件变更: \(response.data.serverChanges.systemEvents.count)")
            print("⚙️ 服务端计时器设置变更: \(response.data.serverChanges.timerSettings != nil ? "有变更" : "无变更")")

            // 存储增量变更数据供 generateSyncWorkspace() 使用
            DispatchQueue.main.async {
                self.serverIncrementalChanges = response.data
            }

            // 更新服务端数据预览（基于增量变更）
            await updateServerDataPreviewFromIncrementalResponse(response.data)

            DispatchQueue.main.async {
                self.isLoadingServerData = false
                self.lastServerResponseStatus = "增量拉取成功 (HTTP 200)"
                self.lastServerResponseTime = Date()
                self.serverConnectionStatus = "已连接"
                print("🎯 服务端变更数据预览已更新")
            }
        } catch {
            print("❌ 增量拉取远端变更数据失败: \(error)")
            DispatchQueue.main.async {
                self.isLoadingServerData = false
                self.lastServerResponseStatus = "增量拉取失败: \(error.localizedDescription)"
                self.lastServerResponseTime = Date()
                self.serverConnectionStatus = "连接失败"
            }
        }
    }

    /// 加载完整服务端数据预览（降级方案）
    func loadFullServerDataPreview() async {
        // 如果正在同步，跳过服务端数据加载，避免冲突
        if isSyncing {
            print("Skipping full server data preview load during sync operation")
            return
        }

        print("🔄 开始加载完整服务端数据预览...")
        print("📱 设备UUID: \(deviceUUID)")
        print("🌐 服务器URL: \(serverURL)")

        DispatchQueue.main.async {
            self.isLoadingServerData = true
        }

        do {
            // 获取完整服务端数据
            print("📡 请求完整服务端数据...")
            guard let authManager = authManager,
                  let token = authManager.sessionToken else {
                throw SyncError.notAuthenticated
            }
            let response = try await apiClient.fullSync(token: token)

            print("✅ 完整服务端响应成功")
            print("📊 番茄事件数量: \(response.data.pomodoroEvents.count)")
            print("📊 系统事件数量: \(response.data.systemEvents.count)")
            print("⚙️ 计时器设置: \(response.data.timerSettings != nil ? "已设置" : "未设置")")

            let preview = ServerDataPreview(
                pomodoroEvents: response.data.pomodoroEvents,
                systemEvents: response.data.systemEvents,
                timerSettings: response.data.timerSettings,
                lastUpdated: Date()
            )

            DispatchQueue.main.async {
                self.serverData = preview
                self.isLoadingServerData = false
                self.lastServerResponseStatus = "成功 (HTTP 200)"
                self.lastServerResponseTime = Date()
                self.serverConnectionStatus = "已连接"
                print("🎯 完整服务端数据预览已更新: \(preview.eventCount)个番茄钟, \(preview.systemEventCount)个系统事件")
            }
        } catch {
            print("❌ 加载完整服务端数据预览失败: \(error)")
            DispatchQueue.main.async {
                self.serverData = nil
                self.isLoadingServerData = false
                self.lastServerResponseStatus = "失败: \(error.localizedDescription)"
                self.lastServerResponseTime = Date()
                self.serverConnectionStatus = "连接失败"
            }
        }
    }

    /// 加载本地数据预览
    func loadLocalDataPreview() {
        var events: [PomodoroEvent] = []
        var systemEvents: [SystemEvent] = []
        var timerSettings: LocalTimerSettings? = nil

        // 获取本地事件
        if let eventManager = eventManager {
            events = eventManager.events
        }

        // 获取本地系统事件
        systemEvents = SystemEventStore.shared.events

        // 获取本地计时器设置
        if let timerModel = timerModel {
            timerSettings = LocalTimerSettings(
                pomodoroTime: Int(timerModel.pomodoroTime),
                shortBreakTime: Int(timerModel.shortBreakTime),
                longBreakTime: Int(timerModel.longBreakTime)
            )
        }

        let preview = LocalDataPreview(
            pomodoroEvents: events,
            systemEvents: systemEvents,
            timerSettings: timerSettings,
            lastUpdated: Date()
        )

        DispatchQueue.main.async {
            self.localData = preview
        }
    }

    /// 清除服务端数据摘要缓存
    func clearServerDataSummaryCache() {
        summaryCache = nil
        print("🗑️ 服务端数据摘要缓存已清除")
    }

    /// 检查缓存是否有效
    private func isSummaryCacheValid() -> Bool {
        guard let cache = summaryCache else { return false }
        return Date().timeIntervalSince(cache.timestamp) < summaryCacheExpiry
    }

    /// 生成Git风格的同步工作区状态
    func generateSyncWorkspace() async {
        let lastSyncTimestamp = userDefaults.object(forKey: lastSyncTimestampKey) as? Int64 ?? 0
        let lastSyncDate = Date(timeIntervalSince1970: TimeInterval(lastSyncTimestamp) / 1000)

        var staged: [WorkspaceItem] = []
        let unstaged: [WorkspaceItem] = []
        var remoteChanges: [WorkspaceItem] = []

        // 分析本地变更

        // 1. 分析番茄钟事件变更
        if let eventManager = eventManager {
            for event in eventManager.events {
                if event.updatedAt > lastSyncDate {
                    let item = WorkspaceItem(
                        id: event.id.uuidString,
                        type: .pomodoroEvent,
                        status: event.createdAt > lastSyncDate ? .added : .modified,
                        title: event.title,
                        description: "\(event.type.displayName) - \(formatDuration(event.duration))",
                        timestamp: event.updatedAt
                    )
                    // 简化处理：所有变更都视为已暂存
                    staged.append(item)
                }
            }
        }

        // 2. 分析系统事件变更（仅在启用同步系统事件时）
        if syncSystemEvents {
            let systemEvents = SystemEventStore.shared.events
            for systemEvent in systemEvents {
                if systemEvent.timestamp > lastSyncDate {
                    let item = WorkspaceItem(
                        id: systemEvent.id.uuidString,
                        type: .systemEvent,
                        status: .added,
                        title: systemEvent.type.displayName,
                        description: "系统活动 - \(systemEvent.type.displayName)",
                        timestamp: systemEvent.timestamp
                    )
                    staged.append(item)
                }
            }
        }

        // 3. 分析删除的事件
        for deletedUUID in deletedEventUUIDs {
            let item: WorkspaceItem

            if let deletedInfo = deletedEventInfos[deletedUUID] {
                // 使用详细信息创建工作区项目
                let eventTypeDisplay = PomodoroEvent.EventType(rawValue: deletedInfo.eventType)?.displayName ?? deletedInfo.eventType
                let duration = deletedInfo.endTime.timeIntervalSince(deletedInfo.startTime)
                let durationText = formatDuration(duration)

                item = WorkspaceItem(
                    id: deletedUUID,
                    type: .pomodoroEvent,
                    status: .deleted,
                    title: deletedInfo.title.isEmpty ? "已删除的\(eventTypeDisplay)" : deletedInfo.title,
                    description: "\(eventTypeDisplay) - \(durationText) (删除于 \(formatTime(deletedInfo.deletedAt)))",
                    timestamp: deletedInfo.deletedAt
                )
            } else {
                // 向后兼容：使用通用信息
                item = WorkspaceItem(
                    id: deletedUUID,
                    type: .pomodoroEvent,
                    status: .deleted,
                    title: "已删除的事件",
                    description: "事件已从本地删除",
                    timestamp: Date()
                )
            }

            staged.append(item)
        }

        // 4. 分析设置变更（优先使用增量变更数据，回退到完整服务端数据）
        if let timerModel = timerModel {
            var hasTimerSettingsChanged = false

            // 优先使用增量变更数据检测设置变更
            if let incrementalChanges = serverIncrementalChanges {
                // 如果服务端有设置变更，直接与服务端设置比较
                if let serverSettings = incrementalChanges.serverChanges.timerSettings {
                    hasTimerSettingsChanged = checkTimerSettingsChangedWithServerSettings(timerModel: timerModel, serverSettings: serverSettings)
                } 
            } else if let serverData = serverData {
                // 回退到使用完整服务端数据
                hasTimerSettingsChanged = checkTimerSettingsChanged(timerModel: timerModel, serverData: serverData)
            }

            if hasTimerSettingsChanged {
                let item = WorkspaceItem(
                    id: "timer-settings",
                    type: .timerSettings,
                    status: .modified,
                    title: "计时器设置",
                    description: "番茄钟: \(Int(timerModel.pomodoroTime/60))分钟",
                    timestamp: Date()
                )
                staged.append(item)
            }
        }

        // 分析远程变更（优先使用增量变更数据，回退到完整服务端数据）
        if let eventManager = eventManager {
            // 创建本地事件的映射表，包含UUID和更新时间
            var localEventMap: [String: Date] = [:]
            for event in eventManager.events {
                localEventMap[event.id.uuidString] = event.updatedAt
            }

            // 优先使用增量变更数据
            if let incrementalChanges = serverIncrementalChanges {
                // 使用增量变更数据分析远程变更
                for serverEvent in incrementalChanges.serverChanges.pomodoroEvents {
                    let serverUpdatedAt = Date(timeIntervalSince1970: TimeInterval(serverEvent.updatedAt) / 1000)

                    if let localUpdatedAt = localEventMap[serverEvent.uuid] {
                        // 本地存在该事件，检查是否有远程更新
                        if serverUpdatedAt > localUpdatedAt && serverUpdatedAt > lastSyncDate {
                            let item = WorkspaceItem(
                            id: serverEvent.uuid,
                            type: .pomodoroEvent,
                            status: .modified,
                            title: serverEvent.title,
                            description: "远程修改 - \(serverEvent.eventType) - \(formatServerDuration(serverEvent))",
                            timestamp: serverUpdatedAt
                        )
                        remoteChanges.append(item)
                    }
                } else {
                    // 本地不存在该事件，检查是否是远程新增
                    if serverUpdatedAt > lastSyncDate {
                        let item = WorkspaceItem(
                            id: serverEvent.uuid,
                            type: .pomodoroEvent,
                            status: .added,
                            title: serverEvent.title,
                            description: "远程新增 - \(serverEvent.eventType) - \(formatServerDuration(serverEvent))",
                            timestamp: serverUpdatedAt
                        )
                        remoteChanges.append(item)
                    }
                }
            }
            } else if let serverData = serverData {
                // 回退到使用完整服务端数据
                for serverEvent in serverData.pomodoroEvents {
                    let serverUpdatedAt = Date(timeIntervalSince1970: TimeInterval(serverEvent.updatedAt) / 1000)

                    if let localUpdatedAt = localEventMap[serverEvent.uuid] {
                        // 本地存在该事件，检查是否有远程更新
                        if serverUpdatedAt > localUpdatedAt && serverUpdatedAt > lastSyncDate {
                            let item = WorkspaceItem(
                                id: serverEvent.uuid,
                                type: .pomodoroEvent,
                                status: .modified,
                                title: serverEvent.title,
                                description: "远程修改 - \(serverEvent.eventType) - \(formatServerDuration(serverEvent))",
                                timestamp: serverUpdatedAt
                            )
                            remoteChanges.append(item)
                        }
                    } else {
                        // 本地不存在该事件，检查是否是远程新增
                        if serverUpdatedAt > lastSyncDate {
                            let item = WorkspaceItem(
                                id: serverEvent.uuid,
                                type: .pomodoroEvent,
                                status: .added,
                                title: serverEvent.title,
                                description: "远程新增 - \(serverEvent.eventType) - \(formatServerDuration(serverEvent))",
                                timestamp: serverUpdatedAt
                            )
                            remoteChanges.append(item)
                        }
                    }
                }
            }
        }

        let workspace = SyncWorkspace(
            staged: staged,
            unstaged: unstaged,
            conflicts: [], // 暂时不处理冲突
            remoteChanges: remoteChanges,
            lastSyncTime: lastSyncTimestamp > 0 ? lastSyncDate : nil
        )

        DispatchQueue.main.async {
            self.syncWorkspace = workspace
        }
    }

    private func formatServerDuration(_ serverEvent: ServerPomodoroEvent) -> String {
        let duration = TimeInterval(serverEvent.endTime - serverEvent.startTime) / 1000
        return formatDuration(duration)
    }

    /// 根据ID获取本地事件（供UI使用）
    func getLocalEvent(by id: String) -> PomodoroEvent? {
        return eventManager?.events.first { $0.id.uuidString == id }
    }

    /// 收集所有本地数据（用于强制覆盖远程）
    private func collectAllLocalData() async -> SyncChanges {
        var allEvents: [ServerPomodoroEvent] = []

        if let eventManager = eventManager {
            for event in eventManager.events {
                let serverEvent = createServerEventFromLocal(event)
                allEvents.append(serverEvent)
            }
        }

        // 收集所有系统事件（仅在启用同步系统事件时）
        var allSystemEvents: [ServerSystemEvent] = []
        if syncSystemEvents {
            let systemEvents = SystemEventStore.shared.events
            for systemEvent in systemEvents {
                let serverSystemEvent = createServerSystemEventFromLocal(systemEvent)
                allSystemEvents.append(serverSystemEvent)
            }
        }

        var timerSettings: ServerTimerSettings? = nil
        if let timerModel = timerModel {
            timerSettings = ServerTimerSettings(
                pomodoroTime: Int(timerModel.pomodoroTime),
                shortBreakTime: Int(timerModel.shortBreakTime),
                longBreakTime: Int(timerModel.longBreakTime),
                updatedAt: Int64(Date().timeIntervalSince1970 * 1000)
            )
        }

        return SyncChanges(
            pomodoroEvents: PomodoroEventChanges(
                created: allEvents,
                updated: [],
                deleted: []
            ),
            systemEvents: SystemEventChanges(created: allSystemEvents),
            timerSettings: timerSettings
        )
    }

    /// 格式化错误信息，提供更友好的错误描述
    private func formatError(_ error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case .invalidURL:
                return "服务器地址无效"
            case .invalidResponse:
                return "服务器响应格式错误"
            case .httpError(let statusCode):
                switch statusCode {
                case 400:
                    return "请求参数错误 (400)"
                case 401:
                    return "未授权访问 (401)"
                case 404:
                    return "服务器接口不存在 (404)"
                case 500:
                    return "服务器内部错误 (500)"
                default:
                    return "网络错误 (\(statusCode))"
                }
            case .serverError(let message):
                return "服务器错误: \(message)"
            case .networkError(let error):
                return "网络错误: \(error.localizedDescription)"
            }
        } else if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return "无网络连接"
            case .timedOut:
                return "连接超时"
            case .cannotFindHost:
                return "无法找到服务器"
            case .cannotConnectToHost:
                return "无法连接到服务器"
            default:
                return "网络连接错误: \(urlError.localizedDescription)"
            }
        } else {
            return error.localizedDescription
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
    


    // MARK: - 同步界面支持方法

    /// 更新服务器URL
    func updateServerURL(_ url: String) {
        serverURL = url
        userDefaults.set(url, forKey: serverURLKey)

        // 更新APIClient以使用新的服务器地址
        apiClient = APIClient(baseURL: url)

        // 通知AuthManager更新服务器地址（这会清除旧的认证状态）
        authManager?.updateServerURL(url)

        print("🔄 SyncManager: 服务器地址已更新为 \(url)，认证状态已重置")
    }

    /// 更新同步系统事件设置
    func updateSyncSystemEvents(_ enabled: Bool) {
        syncSystemEvents = enabled
        userDefaults.set(enabled, forKey: syncSystemEventsKey)
    }

    /// 获取待同步数据数量
    func updatePendingSyncCount() {
        Task {
            let count = await calculatePendingSyncCount()
            DispatchQueue.main.async {
                self.pendingSyncCount = count
            }
        }
    }

    /// 计算待同步数据数量
    private func calculatePendingSyncCount() async -> Int {
        let lastSyncTimestamp = userDefaults.object(forKey: lastSyncTimestampKey) as? Int64 ?? 0
        let lastSyncDate = Date(timeIntervalSince1970: TimeInterval(lastSyncTimestamp) / 1000)

        var count = 0

        // 计算待同步的番茄事件（使用updatedAt而不是startTime）
        if let eventManager = eventManager {
            count += eventManager.events.filter { event in
                return event.updatedAt > lastSyncDate
            }.count
        }

        // 计算待同步的系统事件（仅在启用同步系统事件时）
        if syncSystemEvents {
            let systemEvents = SystemEventStore.shared.events
            count += systemEvents.filter { event in
                return event.timestamp > lastSyncDate
            }.count
        }

        // 计算待同步的设置变更
        if timerModel != nil {
            // 检查设置是否有变更（简化处理：如果有任何本地数据变更，就认为设置可能有变更）
            if count > 0 {
                count += 1 // 设置变更算作1个待同步项
            }
        }

        return count
    }

    /// 添加同步记录
    private func addSyncRecord(_ record: SyncRecord) {
        syncHistory.insert(record, at: 0) // 最新的记录在前面
        lastSyncRecord = record

        // 只保留最近50条记录
        if syncHistory.count > 50 {
            syncHistory = Array(syncHistory.prefix(50))
        }

        // 保存到UserDefaults
        saveSyncHistory()
    }

    /// 保存同步历史到UserDefaults
    private func saveSyncHistory() {
        if let encoded = try? JSONEncoder().encode(syncHistory) {
            userDefaults.set(encoded, forKey: "SyncHistory")
        }
        if let lastRecord = lastSyncRecord,
           let encoded = try? JSONEncoder().encode(lastRecord) {
            userDefaults.set(encoded, forKey: "LastSyncRecord")
        }
    }

    /// 从UserDefaults加载同步历史
    private func loadSyncHistory() {
        if let data = userDefaults.data(forKey: "SyncHistory"),
           let history = try? JSONDecoder().decode([SyncRecord].self, from: data) {
            syncHistory = history
        }
        if let data = userDefaults.data(forKey: "LastSyncRecord"),
           let record = try? JSONDecoder().decode(SyncRecord.self, from: data) {
            lastSyncRecord = record
        }
    }

    /// 跟踪删除的事件（使用详细信息）
    private func trackDeletedEvent(_ eventInfo: DeletedEventInfo) {
        let timestamp = Date()
        let logEntry = "[\(formatTimestamp(timestamp))] 尝试跟踪删除事件: UUID=\(eventInfo.uuid), 标题=\(eventInfo.title), 类型=\(eventInfo.eventType), 原因=\(eventInfo.reason ?? "未知")"

        // 检查是否正在进行同步更新操作，如果是则不跟踪删除
        // 这避免了在同步过程中更新事件时被误标记为删除
        guard !isPerformingSyncUpdate else {
            let skipLogEntry = "[\(formatTimestamp(timestamp))] ⚠️ 跳过删除跟踪 - 正在进行同步更新 (UUID: \(eventInfo.uuid))"
            print(skipLogEntry)
            addDeletionLog(skipLogEntry)
            return
        }

        let trackLogEntry = "[\(formatTimestamp(timestamp))] 🗑️ 成功跟踪删除事件 (UUID: \(eventInfo.uuid), 标题: \(eventInfo.title))"
        print(trackLogEntry)
        addDeletionLog(logEntry)
        addDeletionLog(trackLogEntry)

        deletedEventUUIDs.insert(eventInfo.uuid)
        deletedEventInfos[eventInfo.uuid] = eventInfo
        saveDeletedEvents()
        saveDeletedEventInfos()

        // 更新待同步数据计数
        updatePendingSyncCount()

        // 重新生成同步工作区
        Task {
            await generateSyncWorkspace()
        }
    }

    /// 跟踪删除的事件（仅UUID，向后兼容）
    private func trackDeletedEvent(_ eventUUID: String) {
        let timestamp = Date()
        let logEntry = "[\(formatTimestamp(timestamp))] 尝试跟踪删除事件 (仅UUID模式): UUID=\(eventUUID)"

        // 检查是否正在进行同步更新操作，如果是则不跟踪删除
        // 这避免了在同步过程中更新事件时被误标记为删除
        guard !isPerformingSyncUpdate else {
            let skipLogEntry = "[\(formatTimestamp(timestamp))] ⚠️ 跳过删除跟踪 - 正在进行同步更新 (UUID: \(eventUUID))"
            print(skipLogEntry)
            addDeletionLog(skipLogEntry)
            return
        }

        let trackLogEntry = "[\(formatTimestamp(timestamp))] 🗑️ 成功跟踪删除事件 (UUID: \(eventUUID)) - 仅UUID模式"
        print(trackLogEntry)
        addDeletionLog(logEntry)
        addDeletionLog(trackLogEntry)

        deletedEventUUIDs.insert(eventUUID)
        saveDeletedEvents()

        // 更新待同步数据计数
        updatePendingSyncCount()

        // 重新生成同步工作区
        Task {
            await generateSyncWorkspace()
        }
    }

    /// 保存删除的事件列表到UserDefaults
    private func saveDeletedEvents() {
        let array = Array(deletedEventUUIDs)
        userDefaults.set(array, forKey: deletedEventsKey)
    }

    /// 从UserDefaults加载删除的事件列表
    private func loadDeletedEvents() {
        if let array = userDefaults.array(forKey: deletedEventsKey) as? [String] {
            deletedEventUUIDs = Set(array)
        }
    }

    /// 保存删除的事件详细信息到UserDefaults
    private func saveDeletedEventInfos() {
        if let encoded = try? JSONEncoder().encode(deletedEventInfos) {
            userDefaults.set(encoded, forKey: deletedEventInfosKey)
        }
    }

    /// 从UserDefaults加载删除的事件详细信息
    private func loadDeletedEventInfos() {
        if let data = userDefaults.data(forKey: deletedEventInfosKey),
           let decoded = try? JSONDecoder().decode([String: DeletedEventInfo].self, from: data) {
            deletedEventInfos = decoded
        }
    }

    /// 清除已同步的删除记录
    private func clearSyncedDeletions() {
        deletedEventUUIDs.removeAll()
        deletedEventInfos.removeAll()
        saveDeletedEvents()
        saveDeletedEventInfos()
    }

    /// 检查计时器设置是否有变更
    private func checkTimerSettingsChanged(timerModel: TimerModel, serverData: ServerDataPreview) -> Bool {
        // 如果服务端没有计时器设置，说明是首次同步，需要上传
        guard let serverSettings = serverData.timerSettings else {
            print("🔄 Timer settings: No server settings found, need to upload local settings")
            return true
        }

        // 比较本地和服务端的计时器设置
        let localPomodoroTime = Int(timerModel.pomodoroTime)
        let localShortBreakTime = Int(timerModel.shortBreakTime)
        let localLongBreakTime = Int(timerModel.longBreakTime)

        let pomodoroChanged = localPomodoroTime != serverSettings.pomodoroTime
        let shortBreakChanged = localShortBreakTime != serverSettings.shortBreakTime
        let longBreakChanged = localLongBreakTime != serverSettings.longBreakTime

        let hasChanges = pomodoroChanged || shortBreakChanged || longBreakChanged

        if hasChanges {
            print("🔄 Timer settings changed:")
            if pomodoroChanged {
                print("   - Pomodoro: \(localPomodoroTime)s (local) vs \(serverSettings.pomodoroTime)s (server)")
            }
            if shortBreakChanged {
                print("   - Short break: \(localShortBreakTime)s (local) vs \(serverSettings.shortBreakTime)s (server)")
            }
            if longBreakChanged {
                print("   - Long break: \(localLongBreakTime)s (local) vs \(serverSettings.longBreakTime)s (server)")
            }
        } else {
            print("🔄 Timer settings: No changes detected")
        }

        return hasChanges
    }

    /// 检查计时器设置是否有变更（使用服务端设置对象）
    private func checkTimerSettingsChangedWithServerSettings(timerModel: TimerModel, serverSettings: ServerTimerSettings) -> Bool {
        // 比较本地和服务端的计时器设置
        let localPomodoroTime = Int(timerModel.pomodoroTime)
        let localShortBreakTime = Int(timerModel.shortBreakTime)
        let localLongBreakTime = Int(timerModel.longBreakTime)

        let pomodoroChanged = localPomodoroTime != serverSettings.pomodoroTime
        let shortBreakChanged = localShortBreakTime != serverSettings.shortBreakTime
        let longBreakChanged = localLongBreakTime != serverSettings.longBreakTime

        let hasChanges = pomodoroChanged || shortBreakChanged || longBreakChanged

        if hasChanges {
            print("🔄 Timer settings changed (from incremental data):")
            if pomodoroChanged {
                print("   - Pomodoro: \(localPomodoroTime)s (local) vs \(serverSettings.pomodoroTime)s (server)")
            }
            if shortBreakChanged {
                print("   - Short break: \(localShortBreakTime)s (local) vs \(serverSettings.shortBreakTime)s (server)")
            }
            if longBreakChanged {
                print("   - Long break: \(localLongBreakTime)s (local) vs \(serverSettings.longBreakTime)s (server)")
            }
        } else {
            print("🔄 Timer settings: No changes detected (from incremental data)")
        }

        return hasChanges
    }

    /// 获取待同步数据列表
    func getPendingSyncData() async -> [PendingSyncItem] {
        let lastSyncTimestamp = userDefaults.object(forKey: lastSyncTimestampKey) as? Int64 ?? 0
        let lastSyncDate = Date(timeIntervalSince1970: TimeInterval(lastSyncTimestamp) / 1000)
        var items: [PendingSyncItem] = []

        // 获取待同步的番茄事件
        if let eventManager = eventManager {
            let events = eventManager.events.filter { event in
                // 使用更新时间来判断是否需要同步
                return event.updatedAt > lastSyncDate
            }

            for event in events {
                let isNew = event.createdAt > lastSyncDate
                let actionType = isNew ? "新增" : "更新"

                items.append(PendingSyncItem(
                    id: event.id.uuidString,
                    type: .pomodoroEvent,
                    title: event.title,
                    description: "\(actionType) - \(event.type.displayName) - \(formatDuration(event.duration))",
                    timestamp: event.updatedAt
                ))
            }
        }

        return items.sorted { $0.timestamp > $1.timestamp }
    }

    /// 格式化时长
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// 格式化时间戳
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    /// 格式化详细时间戳（用于调试日志）
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: date)
    }

    /// 添加删除跟踪日志
    private func addDeletionLog(_ message: String) {
        deletionTrackingLog.append(message)
        // 限制日志数量，保留最近的100条
        if deletionTrackingLog.count > 100 {
            deletionTrackingLog.removeFirst(deletionTrackingLog.count - 100)
        }
    }

    /// 获取删除跟踪日志（用于调试）
    func getDeletionTrackingLog() -> [String] {
        return deletionTrackingLog
    }

    /// 清除删除跟踪日志
    func clearDeletionTrackingLog() {
        deletionTrackingLog.removeAll()
    }

    /// 获取所有删除记录的详细信息（用于调试和管理）
    func getAllDeletedEventInfos() -> [DeletedEventInfo] {
        return Array(deletedEventInfos.values).sorted { $0.deletedAt > $1.deletedAt }
    }

    /// 获取删除记录统计信息
    func getDeletionStatistics() -> (totalCount: Int, withDetails: Int, uuidOnly: Int) {
        let totalCount = deletedEventUUIDs.count
        let withDetails = deletedEventInfos.count
        let uuidOnly = totalCount - withDetails
        return (totalCount: totalCount, withDetails: withDetails, uuidOnly: uuidOnly)
    }

    /// 清除特定的删除记录
    func clearDeletedEvent(uuid: String) {
        deletedEventUUIDs.remove(uuid)
        deletedEventInfos.removeValue(forKey: uuid)
        saveDeletedEvents()
        saveDeletedEventInfos()

        // 更新待同步数据计数
        updatePendingSyncCount()

        // 重新生成同步工作区
        Task {
            await generateSyncWorkspace()
        }

        let logEntry = "[\(formatTimestamp(Date()))] 🧹 手动清除删除记录: UUID=\(uuid)"
        print(logEntry)
        addDeletionLog(logEntry)
    }

    /// 清除所有删除记录（不仅仅是已同步的）
    func clearAllDeletionRecords() {
        let count = deletedEventUUIDs.count
        deletedEventUUIDs.removeAll()
        deletedEventInfos.removeAll()
        saveDeletedEvents()
        saveDeletedEventInfos()

        // 更新待同步数据计数
        updatePendingSyncCount()

        // 重新生成同步工作区
        Task {
            await generateSyncWorkspace()
        }

        let logEntry = "[\(formatTimestamp(Date()))] 🧹 手动清除所有删除记录: 共清除\(count)条记录"
        print(logEntry)
        addDeletionLog(logEntry)
    }

    /// 清除可能的虚假删除记录（基于启发式规则）
    func clearSpuriousDeletionRecords() {
        let now = Date()
        var clearedCount = 0
        var uuidsToRemove: [String] = []

        // 规则1: 清除没有详细信息的删除记录（可能是同步过程中误创建的）
        for uuid in deletedEventUUIDs {
            if deletedEventInfos[uuid] == nil {
                uuidsToRemove.append(uuid)
                clearedCount += 1
            }
        }

        // 规则2: 清除删除时间过于接近的记录（可能是批量误删）
        let sortedInfos = deletedEventInfos.values.sorted { $0.deletedAt < $1.deletedAt }
        for i in 1..<sortedInfos.count {
            let current = sortedInfos[i]
            let previous = sortedInfos[i-1]

            // 如果两个删除事件间隔小于1秒，且都没有明确的删除原因，可能是误删
            if current.deletedAt.timeIntervalSince(previous.deletedAt) < 1.0 &&
               current.reason == nil && previous.reason == nil {
                uuidsToRemove.append(current.uuid)
                clearedCount += 1
            }
        }

        // 执行清除
        for uuid in uuidsToRemove {
            deletedEventUUIDs.remove(uuid)
            deletedEventInfos.removeValue(forKey: uuid)
        }

        if clearedCount > 0 {
            saveDeletedEvents()
            saveDeletedEventInfos()

            // 更新待同步数据计数
            updatePendingSyncCount()

            // 重新生成同步工作区
            Task {
                await generateSyncWorkspace()
            }
        }

        let logEntry = "[\(formatTimestamp(now))] 🧹 智能清除虚假删除记录: 共清除\(clearedCount)条记录"
        print(logEntry)
        addDeletionLog(logEntry)
    }


}

// MARK: - 数据模型

/// 待同步数据项
struct PendingSyncItem: Identifiable {
    let id: String
    let type: PendingSyncItemType
    let title: String
    let description: String
    let timestamp: Date
}

/// 待同步数据类型
enum PendingSyncItemType {
    case pomodoroEvent
    case systemEvent
    case timerSettings

    var displayName: String {
        switch self {
        case .pomodoroEvent:
            return "番茄事件"
        case .systemEvent:
            return "系统事件"
        case .timerSettings:
            return "计时器设置"
        }
    }

    var iconName: String {
        switch self {
        case .pomodoroEvent:
            return "timer"
        case .systemEvent:
            return "desktopcomputer"
        case .timerSettings:
            return "gear"
        }
    }
}



// MARK: - 服务端数据预览

/// 轻量级服务端数据摘要
struct ServerDataSummary {
    let pomodoroEventCount: Int
    let systemEventCount: Int
    let hasTimerSettings: Bool
    let serverTimestamp: Int64
    let lastUpdated: Date
    let recentEvents: [ServerPomodoroEvent] // 最近几个事件用于预览

    var eventCount: Int {
        return pomodoroEventCount
    }

    var completedEventCount: Int {
        return recentEvents.filter { $0.isCompleted }.count
    }
}

/// 完整的服务端数据预览（向后兼容）
struct ServerDataPreview {
    let pomodoroEvents: [ServerPomodoroEvent]
    let systemEvents: [ServerSystemEvent]
    let timerSettings: ServerTimerSettings?
    let lastUpdated: Date

    var eventCount: Int {
        return pomodoroEvents.count
    }

    var systemEventCount: Int {
        return systemEvents.count
    }

    var completedEventCount: Int {
        return pomodoroEvents.filter { $0.isCompleted }.count
    }

    var totalPomodoroTime: TimeInterval {
        return pomodoroEvents
            .filter { $0.eventType == "pomodoro" && $0.isCompleted }
            .reduce(0) { total, event in
                total + TimeInterval(event.endTime - event.startTime) / 1000
            }
    }

    var recentEvents: [ServerPomodoroEvent] {
        return Array(pomodoroEvents.sorted { $0.startTime > $1.startTime }.prefix(5))
    }
}

// MARK: - 本地数据预览
struct LocalDataPreview {
    let pomodoroEvents: [PomodoroEvent]
    let systemEvents: [SystemEvent]
    let timerSettings: LocalTimerSettings?
    let lastUpdated: Date

    var eventCount: Int {
        return pomodoroEvents.count
    }

    var systemEventCount: Int {
        return systemEvents.count
    }

    var completedEventCount: Int {
        return pomodoroEvents.filter { $0.isCompleted }.count
    }

    var totalPomodoroTime: TimeInterval {
        return pomodoroEvents
            .filter { $0.type == .pomodoro && $0.isCompleted }
            .reduce(0) { total, event in
                total + event.duration
            }
    }

    var recentEvents: [PomodoroEvent] {
        return Array(pomodoroEvents.sorted { $0.updatedAt > $1.updatedAt }.prefix(5))
    }
}

struct LocalTimerSettings {
    let pomodoroTime: Int
    let shortBreakTime: Int
    let longBreakTime: Int
}

// MARK: - Git风格的同步工作区
struct SyncWorkspace {
    let staged: [WorkspaceItem]           // 已暂存的变更
    let unstaged: [WorkspaceItem]         // 未暂存的变更
    let conflicts: [WorkspaceItem]        // 冲突的项目
    let remoteChanges: [WorkspaceItem]    // 远程变更
    let lastSyncTime: Date?               // 最后同步时间

    var hasChanges: Bool {
        return !staged.isEmpty || !unstaged.isEmpty
    }

    var hasConflicts: Bool {
        return !conflicts.isEmpty
    }

    var hasRemoteChanges: Bool {
        return !remoteChanges.isEmpty
    }

    var totalLocalChanges: Int {
        return staged.count + unstaged.count
    }

    var totalRemoteChanges: Int {
        return remoteChanges.count
    }
}

struct WorkspaceItem: Identifiable {
    let id: String
    let type: WorkspaceItemType
    let status: WorkspaceItemStatus
    let title: String
    let description: String
    let timestamp: Date

    enum WorkspaceItemType {
        case pomodoroEvent
        case timerSettings
        case systemEvent

        var icon: String {
            switch self {
            case .pomodoroEvent:
                return "clock"
            case .timerSettings:
                return "gear"
            case .systemEvent:
                return "desktopcomputer"
            }
        }
    }

    enum WorkspaceItemStatus {
        case added      // 新增
        case modified   // 修改
        case deleted    // 删除
        case conflict   // 冲突

        var color: Color {
            switch self {
            case .added:
                return .green
            case .modified:
                return .blue
            case .deleted:
                return .red
            case .conflict:
                return .orange
            }
        }

        var icon: String {
            switch self {
            case .added:
                return "plus.circle"
            case .modified:
                return "pencil.circle"
            case .deleted:
                return "minus.circle"
            case .conflict:
                return "exclamationmark.triangle"
            }
        }

        var displayName: String {
            switch self {
            case .added:
                return "新增"
            case .modified:
                return "修改"
            case .deleted:
                return "删除"
            case .conflict:
                return "冲突"
            }
        }
    }
}

// MARK: - 同步记录
struct SyncRecord: Identifiable, Codable {
    let id: String
    let timestamp: Date
    let syncMode: SyncMode
    let success: Bool
    let errorMessage: String?
    let uploadedCount: Int
    let downloadedCount: Int
    let conflictCount: Int
    let duration: TimeInterval

    // 详细同步内容信息
    let syncDetails: SyncDetails?

    init(syncMode: SyncMode, success: Bool, errorMessage: String? = nil, uploadedCount: Int = 0, downloadedCount: Int = 0, conflictCount: Int = 0, duration: TimeInterval = 0, syncDetails: SyncDetails? = nil) {
        self.id = UUID().uuidString
        self.timestamp = Date()
        self.syncMode = syncMode
        self.success = success
        self.errorMessage = errorMessage
        self.uploadedCount = uploadedCount
        self.downloadedCount = downloadedCount
        self.conflictCount = conflictCount
        self.duration = duration
        self.syncDetails = syncDetails
    }
}

// MARK: - 同步详情
struct SyncDetails: Codable {
    let uploadedItems: [SyncItemDetail]
    let downloadedItems: [SyncItemDetail]
    let conflictItems: [SyncItemDetail]
    let deletedItems: [SyncItemDetail]

    var totalItems: Int {
        return uploadedItems.count + downloadedItems.count + conflictItems.count + deletedItems.count
    }

    var summary: String {
        var parts: [String] = []
        if !uploadedItems.isEmpty {
            parts.append("上传\(uploadedItems.count)项")
        }
        if !downloadedItems.isEmpty {
            parts.append("下载\(downloadedItems.count)项")
        }
        if !conflictItems.isEmpty {
            parts.append("冲突\(conflictItems.count)项")
        }
        if !deletedItems.isEmpty {
            parts.append("删除\(deletedItems.count)项")
        }
        return parts.joined(separator: "，")
    }
}

// MARK: - 同步项目详情
struct SyncItemDetail: Identifiable, Codable {
    let id: String
    let type: SyncItemType
    let operation: SyncOperation
    let title: String
    let description: String
    let timestamp: Date
    let details: SyncItemSpecificDetails?

    enum SyncItemType: String, Codable {
        case pomodoroEvent = "pomodoroEvent"
        case timerSettings = "timerSettings"
        case systemEvent = "systemEvent"

        var displayName: String {
            switch self {
            case .pomodoroEvent:
                return "番茄钟事件"
            case .timerSettings:
                return "计时器设置"
            case .systemEvent:
                return "系统事件"
            }
        }

        var icon: String {
            switch self {
            case .pomodoroEvent:
                return "clock"
            case .timerSettings:
                return "gear"
            case .systemEvent:
                return "desktopcomputer"
            }
        }
    }

    enum SyncOperation: String, Codable {
        case upload = "upload"
        case download = "download"
        case conflict = "conflict"
        case delete = "delete"

        var displayName: String {
            switch self {
            case .upload:
                return "上传"
            case .download:
                return "下载"
            case .conflict:
                return "冲突"
            case .delete:
                return "删除"
            }
        }

        var color: Color {
            switch self {
            case .upload:
                return .blue
            case .download:
                return .green
            case .conflict:
                return .orange
            case .delete:
                return .red
            }
        }

        var icon: String {
            switch self {
            case .upload:
                return "arrow.up.circle"
            case .download:
                return "arrow.down.circle"
            case .conflict:
                return "exclamationmark.triangle"
            case .delete:
                return "trash"
            }
        }
    }
}

// MARK: - 同步项目具体详情
struct SyncItemSpecificDetails: Codable {
    // 番茄钟事件详情
    let eventStartTime: Date?
    let eventEndTime: Date?
    let eventType: String?
    let taskName: String?

    // 计时器设置详情
    let pomodoroTime: TimeInterval?
    let shortBreakTime: TimeInterval?
    let longBreakTime: TimeInterval?
    let autoStartBreak: Bool?

    // 系统事件详情
    let systemEventType: String?
    let systemEventData: String?

    init(eventStartTime: Date? = nil, eventEndTime: Date? = nil, eventType: String? = nil, taskName: String? = nil,
         pomodoroTime: TimeInterval? = nil, shortBreakTime: TimeInterval? = nil, longBreakTime: TimeInterval? = nil, autoStartBreak: Bool? = nil,
         systemEventType: String? = nil, systemEventData: String? = nil) {
        self.eventStartTime = eventStartTime
        self.eventEndTime = eventEndTime
        self.eventType = eventType
        self.taskName = taskName
        self.pomodoroTime = pomodoroTime
        self.shortBreakTime = shortBreakTime
        self.longBreakTime = longBreakTime
        self.autoStartBreak = autoStartBreak
        self.systemEventType = systemEventType
        self.systemEventData = systemEventData
    }
}

// MARK: - 同步详情收集器
class SyncDetailsCollector {
    private var uploadedItems: [SyncItemDetail] = []
    private var downloadedItems: [SyncItemDetail] = []
    private var conflictItems: [SyncItemDetail] = []
    private var deletedItems: [SyncItemDetail] = []

    func addUploadedItem(_ item: SyncItemDetail) {
        uploadedItems.append(item)
    }

    func addDownloadedItem(_ item: SyncItemDetail) {
        downloadedItems.append(item)
    }

    func addConflictItem(_ item: SyncItemDetail) {
        conflictItems.append(item)
    }

    func addDeletedItem(_ item: SyncItemDetail) {
        deletedItems.append(item)
    }

    func build() -> SyncDetails {
        return SyncDetails(
            uploadedItems: uploadedItems,
            downloadedItems: downloadedItems,
            conflictItems: conflictItems,
            deletedItems: deletedItems
        )
    }
}

// MARK: - 同步详情收集辅助方法
extension SyncManager {

    /// 收集上传详情
    private func collectUploadDetails(from changes: SyncChanges, to collector: inout SyncDetailsCollector) {
        // 收集番茄钟事件上传详情
        for event in changes.pomodoroEvents.created + changes.pomodoroEvents.updated {
            let detail = SyncItemDetail(
                id: event.uuid,
                type: .pomodoroEvent,
                operation: .upload,
                title: event.title,
                description: formatEventTimeRange(start: Date(timeIntervalSince1970: TimeInterval(event.startTime) / 1000),
                                                end: Date(timeIntervalSince1970: TimeInterval(event.endTime) / 1000)),
                timestamp: Date(timeIntervalSince1970: TimeInterval(event.startTime) / 1000),
                details: SyncItemSpecificDetails(
                    eventStartTime: Date(timeIntervalSince1970: TimeInterval(event.startTime) / 1000),
                    eventEndTime: Date(timeIntervalSince1970: TimeInterval(event.endTime) / 1000),
                    eventType: event.eventType,
                    taskName: event.title
                )
            )
            collector.addUploadedItem(detail)
        }

        // 收集设置上传详情
        if let settings = changes.timerSettings {
            let detail = SyncItemDetail(
                id: "timer_settings",
                type: .timerSettings,
                operation: .upload,
                title: "计时器设置",
                description: "番茄钟: \(settings.pomodoroTime/60)分钟, 短休息: \(settings.shortBreakTime/60)分钟",
                timestamp: Date(),
                details: SyncItemSpecificDetails(
                    pomodoroTime: TimeInterval(settings.pomodoroTime),
                    shortBreakTime: TimeInterval(settings.shortBreakTime),
                    longBreakTime: TimeInterval(settings.longBreakTime)
                )
            )
            collector.addUploadedItem(detail)
        }

        // 收集系统事件上传详情
        for systemEvent in changes.systemEvents.created {
            let detail = SyncItemDetail(
                id: systemEvent.uuid,
                type: .systemEvent,
                operation: .upload,
                title: "系统事件",
                description: systemEvent.eventType,
                timestamp: Date(timeIntervalSince1970: TimeInterval(systemEvent.timestamp) / 1000),
                details: SyncItemSpecificDetails(
                    systemEventType: systemEvent.eventType,
                    systemEventData: systemEvent.data.description
                )
            )
            collector.addUploadedItem(detail)
        }
    }

    /// 收集下载详情
    private func collectDownloadDetails(from data: FullSyncData, to collector: inout SyncDetailsCollector) {
        // 收集番茄钟事件下载详情
        for event in data.pomodoroEvents {
            let detail = SyncItemDetail(
                id: event.uuid,
                type: .pomodoroEvent,
                operation: .download,
                title: event.title,
                description: formatEventTimeRange(start: Date(timeIntervalSince1970: TimeInterval(event.startTime) / 1000),
                                                end: Date(timeIntervalSince1970: TimeInterval(event.endTime) / 1000)),
                timestamp: Date(timeIntervalSince1970: TimeInterval(event.startTime) / 1000),
                details: SyncItemSpecificDetails(
                    eventStartTime: Date(timeIntervalSince1970: TimeInterval(event.startTime) / 1000),
                    eventEndTime: Date(timeIntervalSince1970: TimeInterval(event.endTime) / 1000),
                    eventType: event.eventType,
                    taskName: event.title
                )
            )
            collector.addDownloadedItem(detail)
        }

        // 收集设置下载详情
        if let settings = data.timerSettings {
            let detail = SyncItemDetail(
                id: "timer_settings",
                type: .timerSettings,
                operation: .download,
                title: "计时器设置",
                description: "番茄钟: \(settings.pomodoroTime/60)分钟, 短休息: \(settings.shortBreakTime/60)分钟",
                timestamp: Date(),
                details: SyncItemSpecificDetails(
                    pomodoroTime: TimeInterval(settings.pomodoroTime),
                    shortBreakTime: TimeInterval(settings.shortBreakTime),
                    longBreakTime: TimeInterval(settings.longBreakTime)
                )
            )
            collector.addDownloadedItem(detail)
        }

        // 收集系统事件下载详情（仅在启用同步系统事件时）
        if syncSystemEvents {
            for systemEvent in data.systemEvents {
                let detail = SyncItemDetail(
                    id: systemEvent.uuid,
                    type: .systemEvent,
                    operation: .download,
                    title: "系统事件",
                    description: systemEvent.eventType,
                    timestamp: Date(timeIntervalSince1970: TimeInterval(systemEvent.timestamp) / 1000),
                    details: SyncItemSpecificDetails(
                        systemEventType: systemEvent.eventType,
                        systemEventData: systemEvent.data.description
                    )
                )
                collector.addDownloadedItem(detail)
            }
        }
    }

    /// 格式化事件时间范围
    private func formatEventTimeRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}
