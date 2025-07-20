//
//  SyncView.swift
//  PomodoroTimer
//
//  Created by Assistant on 2024
//

import SwiftUI

/// 全局时间格式化函数
private func formatSyncTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MM-dd HH:mm"
    return formatter.string(from: date)
}

// 弹窗数据管理器
class FullChangesManager: ObservableObject {
    @Published var isPresented = false
    @Published var selectedChanges: SelectedChanges?

    func showChanges(_ changes: SelectedChanges) {
        selectedChanges = changes
        isPresented = true
    }

    func hide() {
        isPresented = false
        // 延迟清理数据，避免弹窗关闭时闪烁
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.selectedChanges = nil
        }
    }
}

struct SyncView: View {
    @EnvironmentObject var syncManager: SyncManager
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var fullChangesManager = FullChangesManager()
    @State private var serverURL = ""
    @State private var debugMode = true // Debug模式默认开启
    @State private var showingLocalDataDetail = false
    @State private var showingServerDataDetail = false
    @State private var showingSyncHistory = false
    @State private var selectedDataType: DataType = .pomodoroEvents
    @State private var showingDeletionDebug = false
    @State private var showingDeletionLog = false
    @State private var showingAuthView = false
    @State private var showingUnbindConfirmation = false
    @State private var isUnbinding = false
    @State private var unbindError: String?

    enum DataType: String, CaseIterable {
        case pomodoroEvents = "番茄钟事件"
        case systemEvents = "系统事件"
        case timerSettings = "计时器设置"
    }

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                authenticatedSyncView
            } else {
                unauthenticatedView
            }
        }
        .sheet(isPresented: $showingAuthView) {
            AuthenticationView(authManager: authManager, syncManager: syncManager)
        }
        .alert("确认解绑设备", isPresented: $showingUnbindConfirmation) {
            Button("取消", role: .cancel) { }
            Button("解绑", role: .destructive) {
                Task {
                    await performDeviceUnbind()
                }
            }
        } message: {
            Text("解绑设备后，您需要重新绑定或者注册新账号才能继续使用同步功能。此操作不可撤销，确定要继续吗？")
        }
        .alert("解绑失败", isPresented: .constant(unbindError != nil)) {
            Button("确定") {
                unbindError = nil
            }
        } message: {
            if let error = unbindError {
                Text(error)
            }
        }
        .alert("认证失败", isPresented: $syncManager.authenticationFailureDetected) {
            Button("重新登录") {
                Task {
                    await handleAuthenticationFailure()
                }
            }
            Button("取消", role: .cancel) {
                // 重置认证失败标志
                syncManager.authenticationFailureDetected = false
                syncManager.authenticationFailureMessage = ""
            }
        } message: {
            Text(syncManager.authenticationFailureMessage.isEmpty ?
                 "检测到认证失效，需要重新登录以继续使用同步功能。" :
                 syncManager.authenticationFailureMessage)
        }
    }

    private var authenticatedSyncView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 用户信息区域
                userInfoSection

                // 服务器配置
                serverConfigurationSection

                // 同步状态总览
                syncStatusOverviewSection

                // 数据对比区域
                dataComparisonSection

                // 数据差异分析
                if shouldShowDataDifferences() {
                    dataDifferenceAnalysisSection
                }

                // 同步操作区域
                syncActionsSection

                // 同步历史记录
                syncHistorySection

                // Debug信息区域
                if debugMode {
                    debugInfoSection
                }
            }
            .padding()
        }
        .toolbar {
            // 左侧：同步图标和标题
            ToolbarItem(placement: .navigation) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                    Text("数据同步")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
            }

            // 中间：占位符确保 toolbar 铺满宽度
            ToolbarItem(placement: .principal) {
                Spacer()
            }

            // 右侧：Debug模式切换
            ToolbarItem(placement: .primaryAction) {
                Toggle("Debug", isOn: $debugMode)
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    .controlSize(.small)
            }
        }
        .onAppear {
            serverURL = syncManager.serverURL
            syncManager.loadLocalDataPreview()
            if !syncManager.isSyncing {
                Task {
                    // 页面初始加载时使用完整的服务端数据预览
                    await syncManager.loadServerChangesPreview()
                    await syncManager.generateSyncWorkspace()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SyncCompleted"))) { _ in
            // 同步完成后自动刷新数据对比区域，使用增量拉取以保持本地数据原始状态
            Task {
                await syncManager.loadServerChangesPreview()
                await syncManager.generateSyncWorkspace()
            }
        }
        // 数据详情弹窗
        .popover(isPresented: $showingLocalDataDetail) {
            dataDetailPopover(isLocal: true)
        }
        .popover(isPresented: $showingServerDataDetail) {
            dataDetailPopover(isLocal: false)
        }
        .popover(isPresented: $fullChangesManager.isPresented) {
            if let changes = fullChangesManager.selectedChanges {
                fullChangesDetailView(changes: changes)
            } else {
                Text("数据加载中...")
                    .padding()
            }
        }
        .popover(isPresented: $showingDeletionDebug) {
            deletionDebugView
        }
        .popover(isPresented: $showingDeletionLog) {
            deletionLogView
        }
    }

    // MARK: - UI组件

    /// 服务器配置区域
    private var serverConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "server.rack")
                    .foregroundColor(.secondary)
                Text("服务器配置")
                    .font(.headline)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("服务端接口地址")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    TextField("请输入服务器地址", text: $serverURL)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            syncManager.updateServerURL(serverURL)
                        }
                    
                    Button("保存") {
                        syncManager.updateServerURL(serverURL)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            
            if !syncManager.serverURL.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("服务器地址已配置")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // 同步设置
            VStack(alignment: .leading, spacing: 8) {
                Text("同步设置")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    Toggle("同步系统事件", isOn: $syncManager.syncSystemEvents)
                        .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                        .controlSize(.small)
                        .onChange(of: syncManager.syncSystemEvents) { newValue in
                            syncManager.updateSyncSystemEvents(newValue)
                            // 重新生成同步工作区以反映设置变更
                            Task {
                                await syncManager.generateSyncWorkspace()
                            }
                        }

                    Spacer()

                    Text("包含活动监控数据")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.systemBackground)
        .cornerRadius(8)
    }

    /// 同步状态总览
    private var syncStatusOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
                Text("同步状态")
                    .font(.headline)
                Spacer()

                // 状态指示器
                syncStatusIndicator
            }

            // 状态详情
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("最后同步:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(lastSyncTimeText)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }

                if let workspace = syncManager.syncWorkspace {
                    HStack {
                        Text("同步状态:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(getSyncStatusDescription(workspace))
                            .font(.subheadline)
                            .foregroundColor(getSyncStatusColor(workspace))
                    }
                }
            }
        }
        .padding()
        .background(Color.systemBackground)
        .cornerRadius(8)
    }

    /// 数据对比区域
    private var dataComparisonSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("数据对比")
                    .font(.headline)
                Spacer()

                // 刷新按钮
                Button(action: refreshAllData) {
                    HStack(spacing: 4) {
                        if syncManager.isLoadingServerData {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text("刷新")
                            .font(.caption)
                    }
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(syncManager.isLoadingServerData)
            }

            // 简化的数据对比表格
            if syncManager.isLoadingServerData {
                HStack {
                    ProgressView()
                    Text("正在加载服务端数据...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
            } else {
                simpleDataComparisonTable
            }
        }
        .padding()
        .background(Color.systemBackground)
        .cornerRadius(8)
    }

    /// 简化的数据对比表格
    private var simpleDataComparisonTable: some View {
        VStack(spacing: 12) {
            // 表头
            HStack {
                Text("数据类型")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(width: 100, alignment: .leading)

                Spacer()

                Text("本地")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(width: 60, alignment: .center)

                Text("服务端")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(width: 60, alignment: .center)

                Text("状态")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(width: 60, alignment: .center)
            }
            .padding(.bottom, 8)

            Divider()

            // 数据行
            dataComparisonRow(
                title: "番茄钟事件",
                localCount: syncManager.localData?.eventCount ?? 0,
                serverCount: getServerEventCount()
            )

            dataComparisonRow(
                title: "系统事件",
                localCount: syncManager.localData?.systemEventCount ?? 0,
                serverCount: getServerSystemEventCount()
            )

            dataComparisonRow(
                title: "计时器设置",
                localCount: syncManager.localData?.timerSettings != nil ? 1 : 0,
                serverCount: hasServerTimerSettings() ? 1 : 0
            )

            // 同步状态说明
            syncStatusLegend
        }
    }

    /// 数据对比行
    private func dataComparisonRow(title: String, localCount: Int, serverCount: Int) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .frame(width: 100, alignment: .leading)

            Spacer()

            // 本地数据 - 可点击
            if debugMode && localCount > 0 {
                Button("\(localCount)") {
                    let dataType = getDataType(from: title)
                    showLocalDataDetail(dataType)
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.accentColor)
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(width: 60, alignment: .center)
            } else {
                Text("\(localCount)")
                    .font(.subheadline)
                    .frame(width: 60, alignment: .center)
                    .foregroundColor(localCount > 0 ? .primary : .secondary)
            }

            // 服务端数据 - 根据连接状态显示
            if isServerDataAvailable() {
                // 服务器连接正常，显示实际数据
                if debugMode && serverCount > 0 {
                    Button("\(serverCount)") {
                        let dataType = getDataType(from: title)
                        showServerDataDetail(dataType)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(.accentColor)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(width: 60, alignment: .center)
                } else {
                    Text("\(serverCount)")
                        .font(.subheadline)
                        .frame(width: 60, alignment: .center)
                        .foregroundColor(serverCount > 0 ? .primary : .secondary)
                }
            } else {
                // 服务器连接失败，显示不可用状态
                Text("--")
                    .font(.subheadline)
                    .frame(width: 60, alignment: .center)
                    .foregroundColor(.red)
            }

            // 状态指示器 - 基于实际数据变更状态
            Group {
                let dataType = getDataType(from: title)
                let status = getDataTypeStatus(dataType)

                switch status {
                case .synced:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                case .localChanges:
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(.blue)
                case .remoteChanges:
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(.orange)
                case .conflicts:
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                case .bothChanges:
                    Image(systemName: "arrow.left.arrow.right.circle.fill")
                        .foregroundColor(.purple)
                case .serverUnavailable:
                    Image(systemName: "wifi.slash")
                        .foregroundColor(.red)
                case .ignored:
                    Image(systemName: "minus.circle")
                        .foregroundColor(.secondary)
                }
            }
            .font(.subheadline)
            .frame(width: 60, alignment: .center)
        }
        .padding(.vertical, 4)
    }

    /// 数据类型同步状态
    private enum DataTypeStatus {
        case synced          // 已同步
        case localChanges    // 本地有变更
        case remoteChanges   // 远程有变更
        case bothChanges     // 双向变更
        case conflicts       // 有冲突
        case serverUnavailable // 服务器不可用
        case ignored         // 忽略变更
    }

    /// 检查服务器数据是否可用
    private func isServerDataAvailable() -> Bool {
        return (syncManager.serverData != nil || syncManager.serverDataSummary != nil) && syncManager.serverConnectionStatus == "已连接"
    }

    /// 获取服务端事件数量（兼容摘要和完整数据）
    private func getServerEventCount() -> Int {
        if let summary = syncManager.serverDataSummary {
            return summary.pomodoroEventCount
        }
        return syncManager.serverData?.eventCount ?? 0
    }

    /// 获取服务端系统事件数量（兼容摘要和完整数据）
    private func getServerSystemEventCount() -> Int {
        if let summary = syncManager.serverDataSummary {
            return summary.systemEventCount
        }
        return syncManager.serverData?.systemEventCount ?? 0
    }

    /// 检查服务端是否有计时器设置（兼容摘要和完整数据）
    private func hasServerTimerSettings() -> Bool {
        if let summary = syncManager.serverDataSummary {
            return summary.hasTimerSettings
        }
        return syncManager.serverData?.timerSettings != nil
    }

    /// 根据标题获取数据类型
    private func getDataType(from title: String) -> DataType {
        switch title {
        case "番茄钟事件":
            return .pomodoroEvents
        case "系统事件":
            return .systemEvents
        case "计时器设置":
            return .timerSettings
        default:
            return .pomodoroEvents
        }
    }

    /// 获取特定数据类型的同步状态
    private func getDataTypeStatus(_ dataType: DataType) -> DataTypeStatus {
        // 检查系统事件是否被忽略
        if dataType == .systemEvents && !syncManager.syncSystemEvents {
            return .ignored
        }

        // 首先检查服务器是否可用
        if !isServerDataAvailable() {
            return .serverUnavailable
        }

        guard let workspace = syncManager.syncWorkspace else {
            // 如果没有工作区信息，回退到数量比较
            let localCount: Int
            let serverCount: Int

            switch dataType {
            case .pomodoroEvents:
                localCount = syncManager.localData?.eventCount ?? 0
                serverCount = getServerEventCount()
            case .systemEvents:
                localCount = syncManager.localData?.systemEventCount ?? 0
                serverCount = getServerSystemEventCount()
            case .timerSettings:
                localCount = syncManager.localData?.timerSettings != nil ? 1 : 0
                serverCount = hasServerTimerSettings() ? 1 : 0
            }

            if localCount == serverCount {
                return .synced
            } else if localCount > serverCount {
                return .localChanges
            } else {
                return .remoteChanges
            }
        }

        // 基于工作区分析具体的数据类型状态
        let hasLocalChanges = workspace.staged.contains { item in
            switch dataType {
            case .pomodoroEvents:
                return item.type == .pomodoroEvent
            case .systemEvents:
                return item.type == .systemEvent
            case .timerSettings:
                return item.type == .timerSettings
            }
        }

        let hasRemoteChanges = workspace.remoteChanges.contains { item in
            switch dataType {
            case .pomodoroEvents:
                return item.type == .pomodoroEvent
            case .systemEvents:
                return item.type == .systemEvent
            case .timerSettings:
                return item.type == .timerSettings
            }
        }

        let hasConflicts = workspace.conflicts.contains { item in
            switch dataType {
            case .pomodoroEvents:
                return item.type == .pomodoroEvent
            case .systemEvents:
                return item.type == .systemEvent
            case .timerSettings:
                return item.type == .timerSettings
            }
        }

        if hasConflicts {
            return .conflicts
        } else if hasLocalChanges && hasRemoteChanges {
            return .bothChanges
        } else if hasLocalChanges {
            return .localChanges
        } else if hasRemoteChanges {
            return .remoteChanges
        } else {
            return .synced
        }
    }

    /// 同步状态图例
    private var syncStatusLegend: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            Text("状态说明:")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                HStack(spacing: 20) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("一致")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text("本地更多")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text("服务端更多")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "wifi.slash")
                            .foregroundColor(.red)
                            .font(.caption)
                        Text("服务器不可用")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "minus.circle")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text("忽略变更")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.top, 8)
    }

    /// 同步历史记录区域
    private var syncHistorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.purple)
                Text("同步历史")
                    .font(.headline)
                Spacer()

                Button("查看全部") {
                    showingSyncHistory = true
                }
                .buttonStyle(BorderlessButtonStyle())
                .font(.caption)
            }

            // 最近的同步记录
            if let lastSync = syncManager.lastSyncRecord {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle()
                            .fill(lastSync.success ? .green : .red)
                            .frame(width: 8, height: 8)
                        Text("最后同步: \(formatTime(lastSync.timestamp))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text(lastSync.syncMode.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.2))
                            .cornerRadius(4)
                    }

                    if lastSync.success {
                        Text("✓ 同步成功")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text("✗ 同步失败: \(lastSync.errorMessage ?? "未知错误")")
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    // 同步数据统计
                    if lastSync.success {
                        HStack(spacing: 16) {
                            syncStatItem("上传", count: lastSync.uploadedCount, color: .blue)
                            syncStatItem("下载", count: lastSync.downloadedCount, color: .green)
                            syncStatItem("冲突", count: lastSync.conflictCount, color: .orange)
                        }
                        .font(.caption2)
                    }
                }
                .padding()
                .background(Color.systemBackground.opacity(0.5))
                .cornerRadius(6)
            } else {
                Text("暂无同步记录")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .padding()
        .background(Color.systemBackground)
        .cornerRadius(8)
        .popover(isPresented: $showingSyncHistory) {
            syncHistoryDetailView
        }
    }

    /// 本地数据卡片
    private var localDataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "desktopcomputer")
                    .foregroundColor(.blue)
                Text("本地数据")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
            }

            if let localData = syncManager.localData {
                VStack(alignment: .leading, spacing: 8) {
                    dataCountRow(
                        title: "番茄钟事件",
                        count: localData.eventCount,
                        isClickable: debugMode,
                        action: { showLocalDataDetail(.pomodoroEvents) }
                    )

                    dataCountRow(
                        title: "系统事件",
                        count: localData.systemEventCount,
                        isClickable: debugMode,
                        action: { showLocalDataDetail(.systemEvents) }
                    )

                    dataCountRow(
                        title: "计时器设置",
                        count: localData.timerSettings != nil ? 1 : 0,
                        isClickable: debugMode,
                        action: { showLocalDataDetail(.timerSettings) }
                    )
                }
            } else {
                Text("暂无数据")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.systemSeparator.opacity(0.1))
        .cornerRadius(8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 服务端数据卡片
    private var serverDataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "cloud")
                    .foregroundColor(.green)
                Text("服务端数据")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
            }

            if syncManager.isLoadingServerData {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("加载中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if syncManager.serverDataSummary != nil || syncManager.serverData != nil {
                VStack(alignment: .leading, spacing: 8) {
                    dataCountRow(
                        title: "番茄钟事件",
                        count: getServerEventCount(),
                        isClickable: debugMode && syncManager.serverData != nil, // 只有完整数据才能点击查看详情
                        action: { showServerDataDetail(.pomodoroEvents) }
                    )

                    dataCountRow(
                        title: "系统事件",
                        count: getServerSystemEventCount(),
                        isClickable: debugMode && syncManager.serverData != nil,
                        action: { showServerDataDetail(.systemEvents) }
                    )

                    dataCountRow(
                        title: "计时器设置",
                        count: hasServerTimerSettings() ? 1 : 0,
                        isClickable: debugMode && syncManager.serverData != nil,
                        action: { showServerDataDetail(.timerSettings) }
                    )

                    // 如果只有摘要数据，显示加载完整数据的按钮
                    if syncManager.serverDataSummary != nil && syncManager.serverData == nil {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                Text("轻量级预览")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            Button("加载完整数据") {
                                Task {
                                    await syncManager.loadFullServerData()
                                }
                            }
                            .font(.caption2)
                            .buttonStyle(BorderlessButtonStyle())
                            .foregroundColor(.accentColor)
                        }
                        .padding(.top, 4)
                    }
                }
            } else {
                Text("暂无数据")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.systemSeparator.opacity(0.1))
        .cornerRadius(8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 数据差异分析区域
    private var dataDifferenceAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.left.arrow.right")
                    .foregroundColor(.orange)
                Text("数据差异分析")
                    .font(.headline)
                Spacer()
            }

            if let workspace = syncManager.syncWorkspace {
                VStack(alignment: .leading, spacing: 12) {
                    // 本地变更
                    let localChanges = filterSystemEventsIfNeeded(workspace.staged + workspace.unstaged)
                    if !localChanges.isEmpty {
                        differenceSection(
                            title: "本地变更",
                            items: localChanges,
                            color: .orange,
                            icon: "arrow.up.circle"
                        )
                    }

                    // 远程变更
                    let remoteChanges = filterSystemEventsIfNeeded(workspace.remoteChanges)
                    if !remoteChanges.isEmpty {
                        differenceSection(
                            title: "远程变更",
                            items: remoteChanges,
                            color: .blue,
                            icon: "arrow.down.circle"
                        )
                    }

                    // 冲突
                    let conflicts = filterSystemEventsIfNeeded(workspace.conflicts)
                    if !conflicts.isEmpty {
                        differenceSection(
                            title: "冲突项目",
                            items: conflicts,
                            color: .red,
                            icon: "exclamationmark.triangle"
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color.systemBackground)
        .cornerRadius(8)
    }

    /// 同步操作区域
    private var syncActionsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.secondary)
                Text("同步操作")
                    .font(.headline)
                Spacer()
            }

            // 主要操作按钮
            VStack(spacing: 12) {
                // 统一的增量同步按钮
                syncActionButton(
                    mode: .incremental,
                    enabled: shouldEnableIncrementalSync(),
                    style: .bordered
                )

                // 危险操作
                HStack(spacing: 12) {
                    // 强制覆盖本地
                    syncActionButton(
                        mode: .forceOverwriteLocal,
                        enabled: shouldShowForceOperations(),
                        style: .destructive
                    )

                    // 强制覆盖远程
                    syncActionButton(
                        mode: .forceOverwriteRemote,
                        enabled: shouldShowForceOperations(),
                        style: .destructive
                    )
                }
            }

            // 同步状态指示器
            if syncManager.isSyncing {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("同步中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // 错误提示
            if syncManager.serverURL.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("请先配置服务器地址")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.systemBackground)
        .cornerRadius(8)
    }

    /// Debug信息区域
    private var debugInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "ladybug")
                    .foregroundColor(.purple)
                Text("Debug信息")
                    .font(.headline)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                debugInfoRow("设备UUID", "已配置")
                debugInfoRow("服务器地址", syncManager.serverURL.isEmpty ? "未配置" : syncManager.serverURL)

                // 服务器响应状态信息
                debugInfoRow("连接状态", syncManager.serverConnectionStatus)
                debugInfoRow("最后响应状态", syncManager.lastServerResponseStatus)
                if let responseTime = syncManager.lastServerResponseTime {
                    debugInfoRow("最后响应时间", formatTime(responseTime))
                }

                if let workspace = syncManager.syncWorkspace {
                    debugInfoRow("本地变更数", "\(workspace.totalLocalChanges)")
                    debugInfoRow("远程变更数", "\(workspace.totalRemoteChanges)")
                    debugInfoRow("冲突数", "\(workspace.conflicts.count)")
                }

                if let lastSync = syncManager.lastSyncTime {
                    debugInfoRow("最后同步时间戳", formatDateWithTimestamp(lastSync))
                }

                // 本地服务端最后时间戳（基准时间戳）
                let localSyncTimestamp = syncManager.lastSyncTimestamp
                if localSyncTimestamp > 0 {
                    debugInfoRow("本地服务端最后时间戳", formatTimestampWithDate(localSyncTimestamp))
                } else {
                    debugInfoRow("本地服务端最后时间戳", "未设置")
                }

                // 服务端数据最后时间戳
                if let serverData = syncManager.serverData {
                    let serverTimestamp = Int64(serverData.lastUpdated.timeIntervalSince1970 * 1000)
                    debugInfoRow("服务端数据最后时间戳（来源完整数据）", formatTimestampWithDate(serverTimestamp))
                } else if let serverSummary = syncManager.serverDataSummary {
                    debugInfoRow("服务端数据最后时间戳（来源摘要数据）", formatTimestampWithDate(serverSummary.serverTimestamp))
                }

                // 删除记录统计
                let deletionStats = syncManager.getDeletionStatistics()
                debugInfoRow("删除记录总数", "\(deletionStats.totalCount)")
                if deletionStats.totalCount > 0 {
                    debugInfoRow("  - 有详细信息", "\(deletionStats.withDetails)")
                    debugInfoRow("  - 仅UUID", "\(deletionStats.uuidOnly)")
                }
            }

            // 删除记录管理按钮
            let deletionStats = syncManager.getDeletionStatistics()
            if deletionStats.totalCount > 0 {
                HStack(spacing: 8) {
                    Button("查看删除记录") {
                        showingDeletionDebug = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("查看删除日志") {
                        showingDeletionLog = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("智能清理") {
                        syncManager.clearSpuriousDeletionRecords()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(.orange)

                    Button("全部清除") {
                        syncManager.clearAllDeletionRecords()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color.systemBackground)
        .cornerRadius(8)
    }

    // MARK: - 辅助视图和方法

    /// 同步状态指示器
    private var syncStatusIndicator: some View {
        HStack {
            switch syncManager.syncStatus {
            case .notAuthenticated:
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .foregroundColor(.orange)
                Text("未认证")
                    .foregroundColor(.orange)
            case .authenticating:
                ProgressView()
                    .controlSize(.small)
                Text("认证中")
                    .foregroundColor(.blue)
            case .idle:
                Image(systemName: "circle")
                    .foregroundColor(.secondary)
                Text("空闲")
                    .foregroundColor(.secondary)
            case .syncing:
                ProgressView()
                    .controlSize(.small)
                Text("同步中")
                    .foregroundColor(.blue)
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("成功")
                    .foregroundColor(.green)
            case .error(let message):
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.red)
                VStack(alignment: .leading, spacing: 2) {
                    Text("错误")
                        .foregroundColor(.red)
                        .fontWeight(.medium)
                    Text(message)
                        .foregroundColor(.red)
                        .font(.caption)
                        .lineLimit(3)
                }
            case .tokenExpired:
                Image(systemName: "key.slash")
                    .foregroundColor(.orange)
                Text("Token已过期")
                    .foregroundColor(.orange)
            }
        }
        .font(.subheadline)
    }

    /// 数据计数行
    private func dataCountRow(title: String, count: Int, isClickable: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()

            if isClickable && count > 0 {
                Button("\(count)") {
                    action()
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.accentColor)
                .font(.caption)
                .fontWeight(.medium)
            } else {
                Text("\(count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(count > 0 ? .primary : .secondary)
            }
        }
    }

    /// 差异区域组件
    private func differenceSection(title: String, items: [WorkspaceItem], color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(color)
                Text("(\(items.count))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }

            // 按时间倒序排序，最新的变更在前面
            let sortedItems = items.sorted { $0.timestamp > $1.timestamp }

            ForEach(sortedItems.prefix(3)) { item in
                HStack(spacing: 8) {
                    // 操作类型标识
                    HStack(spacing: 4) {
                        Image(systemName: item.status.icon)
                            .foregroundColor(item.status.color)
                            .font(.caption)

                        Text(item.status.displayName)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(item.status.color)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(item.status.color.opacity(0.1))
                            .cornerRadius(4)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.caption2)
                            .lineLimit(1)
                        Text(enhancedItemDescription(item))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(formatWorkspaceTime(item.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 16)
            }

            if items.count > 3 {
                Button("... 还有 \(items.count - 3) 个项目") {
                    let changes = SelectedChanges(title: title, items: sortedItems, color: color, icon: icon)
                    fullChangesManager.showChanges(changes)
                }
                .font(.caption2)
                .foregroundColor(.blue)
                .buttonStyle(PlainButtonStyle())
                .padding(.leading, 16)
            }
        }
    }

    /// 同步操作按钮
    private func syncActionButton(mode: SyncMode, enabled: Bool, style: CustomButtonStyle) -> some View {
        Button(action: {
            Task {
                await syncManager.performSync(mode: mode)
            }
        }) {
            HStack {
                Image(systemName: mode.icon)
                Text(mode.displayName)
            }
        }
        .buttonStyle(.bordered)
        .disabled(syncManager.isSyncing || syncManager.serverURL.isEmpty || !enabled)
        .foregroundColor(style == .destructive ? .red : .primary)
    }

    /// Debug信息行
    private func debugInfoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title + ":")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .foregroundColor(.primary)
                .textSelection(.enabled)
        }
    }

    /// 格式化时间戳为：时间戳（具体时间）
    private func formatTimestampWithDate(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return "\(timestamp)（\(formatter.string(from: date))）"
    }

    /// 格式化Date为：时间戳（具体时间）
    private func formatDateWithTimestamp(_ date: Date) -> String {
        let timestamp = Int64(date.timeIntervalSince1970 * 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return "\(timestamp)（\(formatter.string(from: date))）"
    }

    // MARK: - 辅助方法

    /// 根据设置过滤系统事件
    private func filterSystemEventsIfNeeded(_ items: [WorkspaceItem]) -> [WorkspaceItem] {
        if syncManager.syncSystemEvents {
            return items
        } else {
            return items.filter { $0.type != .systemEvent }
        }
    }

    /// 刷新所有数据
    private func refreshAllData() {
        syncManager.loadLocalDataPreview()
        if !syncManager.isSyncing {
            Task {
                // 使用增量拉取远端变更数据，而不是完整的服务端数据预览
                // 这样可以确保本地数据保持原始状态，便于后续的差异计算
                await syncManager.loadServerChangesPreview()
                await syncManager.generateSyncWorkspace()
            }
        }
    }

    /// 显示本地数据详情
    private func showLocalDataDetail(_ type: DataType) {
        selectedDataType = type
        showingLocalDataDetail = true
    }

    /// 显示服务端数据详情
    private func showServerDataDetail(_ type: DataType) {
        selectedDataType = type
        showingServerDataDetail = true
    }

    /// 是否应该显示数据差异
    private func shouldShowDataDifferences() -> Bool {
        guard let workspace = syncManager.syncWorkspace else { return false }
        return workspace.hasChanges || workspace.hasRemoteChanges || workspace.hasConflicts
    }

    /// 获取对比图标
    private func getComparisonIcon() -> String {
        guard let localData = syncManager.localData else {
            return "questionmark.circle"
        }

        // 检查是否有服务端数据（完整或摘要）
        guard syncManager.serverData != nil || syncManager.serverDataSummary != nil else {
            return "questionmark.circle"
        }

        // 基于同步工作区判断是否有变更
        if let workspace = syncManager.syncWorkspace {
            if workspace.hasChanges || workspace.hasRemoteChanges || workspace.hasConflicts {
                return "arrow.left.arrow.right"
            } else {
                return "checkmark.circle"
            }
        }

        // 如果没有工作区信息，回退到数量比较
        if localData.eventCount == getServerEventCount() &&
           localData.systemEventCount == getServerSystemEventCount() {
            return "checkmark.circle"
        } else {
            return "arrow.left.arrow.right"
        }
    }

    /// 获取对比颜色
    private func getComparisonColor() -> Color {
        guard let localData = syncManager.localData else {
            return .secondary
        }

        // 检查是否有服务端数据（完整或摘要）
        guard syncManager.serverData != nil || syncManager.serverDataSummary != nil else {
            return .secondary
        }

        // 基于同步工作区判断是否有变更
        if let workspace = syncManager.syncWorkspace {
            if workspace.hasConflicts {
                return .red
            } else if workspace.hasChanges || workspace.hasRemoteChanges {
                return .orange
            } else {
                return .green
            }
        }

        // 如果没有工作区信息，回退到数量比较
        if localData.eventCount == getServerEventCount() &&
           localData.systemEventCount == getServerSystemEventCount() {
            return .green
        } else {
            return .orange
        }
    }

    /// 获取对比文本
    private func getComparisonText() -> String {
        guard let localData = syncManager.localData else {
            return "数据加载中"
        }

        // 检查是否有服务端数据（完整或摘要）
        guard syncManager.serverData != nil || syncManager.serverDataSummary != nil else {
            return "数据加载中"
        }

        // 基于同步工作区判断是否有变更
        if let workspace = syncManager.syncWorkspace {
            if workspace.hasConflicts {
                return "存在冲突"
            } else if workspace.hasChanges && workspace.hasRemoteChanges {
                return "双向变更"
            } else if workspace.hasChanges {
                return "本地有变更"
            } else if workspace.hasRemoteChanges {
                return "远程有变更"
            } else {
                return "数据一致"
            }
        }

        // 如果没有工作区信息，回退到数量比较
        if localData.eventCount == getServerEventCount() &&
           localData.systemEventCount == getServerSystemEventCount() {
            return "数据一致"
        } else {
            return "数据不一致"
        }
    }

    private var lastSyncTimeText: String {
        if let lastSync = syncManager.lastSyncTime {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: lastSync)
        } else {
            return "从未同步"
        }
    }

    /// 获取同步状态描述
    private func getSyncStatusDescription(_ workspace: SyncWorkspace) -> String {
        if !workspace.hasChanges && !workspace.hasRemoteChanges {
            return "数据已同步"
        } else if workspace.hasChanges && !workspace.hasRemoteChanges {
            return "有本地变更待推送"
        } else if !workspace.hasChanges && workspace.hasRemoteChanges {
            return "有远程变更待拉取"
        } else {
            return "本地和远程都有变更"
        }
    }

    /// 获取同步状态颜色
    private func getSyncStatusColor(_ workspace: SyncWorkspace) -> Color {
        if !workspace.hasChanges && !workspace.hasRemoteChanges {
            return .green
        } else if workspace.hasChanges && !workspace.hasRemoteChanges {
            return .orange
        } else if !workspace.hasChanges && workspace.hasRemoteChanges {
            return .blue
        } else {
            return .purple
        }
    }

    /// 格式化详细时间
    private func formatDetailedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    /// 格式化工作区时间
    private func formatWorkspaceTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        // 检查是否是今天
        if calendar.isDate(date, inSameDayAs: now) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        }

        // 检查是否是昨天
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return "昨天 " + formatter.string(from: date)
        }

        // 检查是否是今年
        if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM-dd HH:mm"
            return formatter.string(from: date)
        }

        // 不同年份，显示完整日期
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    /// 增强的项目描述，为事件类型添加时间范围信息
    private func enhancedItemDescription(_ item: WorkspaceItem) -> String {
        // 如果是番茄事件，尝试从本地数据中获取详细信息
        if item.type == .pomodoroEvent, let event = syncManager.getLocalEvent(by: item.id) {
            let startTime = formatTimeOnly(event.startTime)
            let endTime = formatTimeOnly(event.endTime)
            let duration = formatDuration(event.duration)
            return "\(event.type.displayName) - \(startTime)-\(endTime) (\(duration))"
        }

        // 如果找不到本地事件或不是事件类型，返回原始描述
        return item.description
    }

    /// 格式化时间（只显示时分）
    private func formatTimeOnly(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    /// 格式化时长
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return "\(minutes)分\(seconds)秒"
        } else {
            return "\(seconds)秒"
        }
    }

    enum CustomButtonStyle {
        case bordered
        case destructive
    }

    /// 同步统计项
    private func syncStatItem(_ title: String, count: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .foregroundColor(.secondary)
            Text("\(count)")
                .fontWeight(.medium)
                .foregroundColor(count > 0 ? color : .secondary)
        }
    }

    /// 完整变更详情视图
    private func fullChangesDetailView(changes: SelectedChanges) -> some View {
        VStack(alignment: .leading, spacing: 16) {

            // 标题
            HStack {
                Image(systemName: changes.icon)
                    .foregroundColor(changes.color)
                Text(changes.title)
                    .font(.headline)
                Text("(\(changes.items.count))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Button("关闭") {
                    fullChangesManager.hide()
                }
            }

            Divider()

            // 变更列表（按时间倒序排序）
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(changes.items.sorted { $0.timestamp > $1.timestamp }) { item in
                        HStack(spacing: 12) {
                            // 操作类型标识（左侧）
                            HStack(spacing: 4) {
                                Image(systemName: item.status.icon)
                                    .foregroundColor(item.status.color)
                                    .font(.caption)

                                Text(item.status.displayName)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(item.status.color)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(item.status.color.opacity(0.15))
                            .cornerRadius(6)
                            .frame(width: 60)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.caption)
                                    .lineLimit(2)
                                Text(enhancedItemDescription(item))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }

                            Spacer()

                            Text(formatWorkspaceTime(item.timestamp))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(Color.systemBackground.opacity(0.5))
                        .cornerRadius(6)
                    }
                }
            }
            .frame(maxHeight: 400)
        }
        .padding()
        .frame(width: 500, height: 500)
    }

    /// 同步历史详情视图
    private var syncHistoryDetailView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.purple)
                Text("同步历史记录")
                    .font(.headline)
                Spacer()
                Button("关闭") {
                    showingSyncHistory = false
                }
                .buttonStyle(BorderlessButtonStyle())
            }

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(syncManager.syncHistory, id: \.id) { record in
                        syncHistoryRow(record)
                    }

                    if syncManager.syncHistory.isEmpty {
                        Text("暂无同步记录")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    }
                }
                .padding()
            }
            .frame(maxHeight: 400)
        }
        .padding()
        .frame(width: 500)
        .popover(item: $selectedSyncRecord) { record in
            syncRecordDetailView(record: record)
                .onAppear {
                    print("🔍 Popover显示: 记录ID: \(record.id)")
                }
        }
    }

    /// 同步历史记录行
    @State private var selectedSyncRecord: SyncRecord? = nil

    private func syncHistoryRow(_ record: SyncRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(record.success ? .green : .red)
                    .frame(width: 8, height: 8)
                Text(formatTime(record.timestamp))
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(record.syncMode.displayName)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.2))
                    .cornerRadius(3)
            }

            if record.success {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 12) {
                        Text("✓ 同步成功")
                            .font(.caption)
                            .foregroundColor(.green)
                        Spacer()
                        syncStatItem("上传", count: record.uploadedCount, color: .blue)
                        syncStatItem("下载", count: record.downloadedCount, color: .green)
                        if record.conflictCount > 0 {
                            syncStatItem("冲突", count: record.conflictCount, color: .orange)
                        }
                    }

                    // 显示同步内容摘要
                    if let details = record.syncDetails, details.totalItems > 0 {
                        Text(details.summary)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                    }
                }
            } else {
                Text("✗ \(record.errorMessage ?? "同步失败")")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color.systemBackground.opacity(0.5))
        .cornerRadius(6)
        .onTapGesture {
            print("🖱️ 点击同步记录: ID=\(record.id), success=\(record.success)")
            if let details = record.syncDetails {
                print("📊 同步详情存在: totalItems=\(details.totalItems)")
            } else {
                print("❌ 同步详情为nil")
            }

            if record.success, let details = record.syncDetails, details.totalItems > 0 {
                print("✅ 设置selectedSyncRecord")
                selectedSyncRecord = record
            } else {
                print("❌ 条件不满足，不显示弹窗")
                selectedSyncRecord = nil
            }
        }
    }

    // MARK: - 按钮状态管理

    /// 是否启用增量同步按钮
    private func shouldEnableIncrementalSync() -> Bool {
        // 增量同步可以在有本地变更或远程变更时使用
        guard let workspace = syncManager.syncWorkspace else { return true }
        return workspace.hasChanges || workspace.hasRemoteChanges || true // 总是允许增量同步
    }

    /// 是否显示强制操作按钮
    private func shouldShowForceOperations() -> Bool {
        let hasLocalData = (syncManager.localData?.eventCount ?? 0) > 0
        let hasRemoteData = getServerEventCount() > 0
        return hasLocalData || hasRemoteData
    }

    /// 数据详情弹窗
    private func dataDetailPopover(isLocal: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack {
                Image(systemName: isLocal ? "desktopcomputer" : "cloud")
                    .foregroundColor(isLocal ? .blue : .green)
                Text("\(isLocal ? "本地" : "服务端")数据详情")
                    .font(.headline)
                Spacer()
                Button("关闭") {
                    if isLocal {
                        showingLocalDataDetail = false
                    } else {
                        showingServerDataDetail = false
                    }
                }
                .buttonStyle(BorderlessButtonStyle())
            }

            Divider()

            // 数据内容
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    switch selectedDataType {
                    case .pomodoroEvents:
                        pomodoroEventsDetail(isLocal: isLocal)
                    case .systemEvents:
                        systemEventsDetail(isLocal: isLocal)
                    case .timerSettings:
                        timerSettingsDetail(isLocal: isLocal)
                    }
                }
                .padding()
            }
            .frame(maxHeight: 400)
        }
        .padding()
        .frame(width: 500)
    }

    /// 番茄钟事件详情
    private func pomodoroEventsDetail(isLocal: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("番茄钟事件")
                .font(.subheadline)
                .fontWeight(.medium)

            if isLocal {
                if let localData = syncManager.localData {
                    Text("总数: \(localData.eventCount)")
                        .font(.caption)
                    Text("已完成: \(localData.completedEventCount)")
                        .font(.caption)

                    if !localData.recentEvents.isEmpty {
                        Text("最近事件:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.top, 8)

                        ForEach(localData.recentEvents.prefix(5), id: \.id) { event in
                            HStack {
                                Circle()
                                    .fill(event.type.color)
                                    .frame(width: 6, height: 6)
                                Text(event.title)
                                    .font(.caption2)
                                Spacer()
                                Text(formatTime(event.startTime))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } else {
                    Text("暂无数据")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                // 优先显示完整数据，回退到摘要数据
                if let serverData = syncManager.serverData {
                    Text("总数: \(serverData.eventCount)")
                        .font(.caption)
                    Text("已完成: \(serverData.completedEventCount)")
                        .font(.caption)

                    if !serverData.pomodoroEvents.isEmpty {
                        Text("最近事件:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.top, 8)

                        ForEach(serverData.pomodoroEvents.prefix(5), id: \.uuid) { event in
                            HStack {
                                Circle()
                                    .fill(eventTypeColor(event.eventType))
                                    .frame(width: 6, height: 6)
                                Text(event.title)
                                    .font(.caption2)
                                Spacer()
                                Text(formatServerTime(event.startTime))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } else if let summary = syncManager.serverDataSummary {
                    Text("总数: \(summary.pomodoroEventCount)")
                        .font(.caption)

                    if !summary.recentEvents.isEmpty {
                        Text("最近事件 (预览):")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.top, 8)

                        ForEach(summary.recentEvents.prefix(5), id: \.uuid) { event in
                            HStack {
                                Circle()
                                    .fill(eventTypeColor(event.eventType))
                                    .frame(width: 6, height: 6)
                                Text(event.title)
                                    .font(.caption2)
                                Spacer()
                                Text(formatServerTime(event.startTime))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Button("加载完整数据") {
                            Task {
                                await syncManager.loadFullServerData()
                            }
                        }
                        .font(.caption2)
                        .buttonStyle(BorderlessButtonStyle())
                        .foregroundColor(.accentColor)
                        .padding(.top, 4)
                    }
                } else {
                    Text("暂无数据")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    /// 系统事件详情
    private func systemEventsDetail(isLocal: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("系统事件")
                .font(.subheadline)
                .fontWeight(.medium)

            if isLocal {
                if let localData = syncManager.localData {
                    Text("总数: \(localData.systemEventCount)")
                        .font(.caption)
                } else {
                    Text("暂无数据")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                if let serverData = syncManager.serverData {
                    Text("总数: \(serverData.systemEventCount)")
                        .font(.caption)
                } else if let summary = syncManager.serverDataSummary {
                    Text("总数: \(summary.systemEventCount)")
                        .font(.caption)
                } else {
                    Text("暂无数据")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    /// 计时器设置详情
    private func timerSettingsDetail(isLocal: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("计时器设置")
                .font(.subheadline)
                .fontWeight(.medium)

            if isLocal {
                if let settings = syncManager.localData?.timerSettings {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("番茄钟时长: \(Int(settings.pomodoroTime/60))分钟")
                            .font(.caption)
                        Text("休息时长: \(Int(settings.shortBreakTime/60))分钟")
                            .font(.caption)
                    }
                } else {
                    Text("暂无设置")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                if let settings = syncManager.serverData?.timerSettings {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("番茄钟时长: \(Int(settings.pomodoroTime/60))分钟")
                            .font(.caption)
                        Text("休息时长: \(Int(settings.shortBreakTime/60))分钟")
                            .font(.caption)
                    }
                } else if let summary = syncManager.serverDataSummary {
                    if summary.hasTimerSettings {
                        Text("已配置计时器设置")
                            .font(.caption)
                        Button("查看详情") {
                            Task {
                                await syncManager.loadFullServerData()
                            }
                        }
                        .font(.caption2)
                        .buttonStyle(BorderlessButtonStyle())
                        .foregroundColor(.accentColor)
                    } else {
                        Text("暂无设置")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("暂无设置")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - 缺少的辅助方法

    /// 时间前文本
    private func timeAgoText(from date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)

        if interval < 60 {
            return "刚刚"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)分钟前"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)小时前"
        } else {
            let days = Int(interval / 86400)
            return "\(days)天前"
        }
    }

    /// 格式化时间
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }

    /// 格式化服务端时间
    private func formatServerTime(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        return formatTime(date)
    }

    /// 事件类型颜色
    private func eventTypeColor(_ eventType: String) -> Color {
        switch eventType {
        case "pomodoro":
            return .blue
        case "short_break":
            return .green
        case "long_break":
            return .orange
        default:
            return .gray
        }
    }
}

struct SelectedChanges {
    let title: String
    let items: [WorkspaceItem]
    let color: Color
    let icon: String
}

// MARK: - 同步记录详细视图扩展
extension SyncView {

    /// 同步记录详细视图
    private func syncRecordDetailView(record: SyncRecord) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack {
                Image(systemName: record.success ? "checkmark.circle" : "xmark.circle")
                    .foregroundColor(record.success ? .green : .red)
                Text("同步详情")
                    .font(.headline)
                Spacer()
                Button("关闭") {
                    selectedSyncRecord = nil
                }
                .buttonStyle(BorderlessButtonStyle())
            }

            Divider()

            // 基本信息
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("同步时间:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatTime(record.timestamp))
                        .font(.caption)
                }

                HStack {
                    Text("同步模式:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(record.syncMode.displayName)
                        .font(.caption)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.accentColor.opacity(0.2))
                        .cornerRadius(3)
                }

                HStack {
                    Text("耗时:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f秒", record.duration))
                        .font(.caption)
                }
            }

            if let details = record.syncDetails, details.totalItems > 0 {
                Divider()

                // 同步内容详情
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        // 上传的项目
                        if !details.uploadedItems.isEmpty {
                            syncItemSection(title: "上传项目", items: details.uploadedItems, color: .blue)
                        }

                        // 下载的项目
                        if !details.downloadedItems.isEmpty {
                            syncItemSection(title: "下载项目", items: details.downloadedItems, color: .green)
                        }

                        // 冲突的项目
                        if !details.conflictItems.isEmpty {
                            syncItemSection(title: "冲突项目", items: details.conflictItems, color: .orange)
                        }

                        // 删除的项目
                        if !details.deletedItems.isEmpty {
                            syncItemSection(title: "删除项目", items: details.deletedItems, color: .red)
                        }
                    }
                    .padding()
                }
                .frame(maxHeight: 300)
            }
        }
        .padding()
        .frame(width: 500)
    }

    /// 同步项目分组显示
    private func syncItemSection(title: String, items: [SyncItemDetail], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("(\(items.count))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ForEach(items) { item in
                syncItemRow(item: item, color: color)
            }
        }
    }

    /// 同步项目行
    private func syncItemRow(item: SyncItemDetail, color: Color) -> some View {
        HStack(spacing: 8) {
            // 类型图标
            Image(systemName: item.type.icon)
                .foregroundColor(color)
                .font(.caption)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.caption)
                    .lineLimit(1)
                Text(item.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(item.type.displayName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(formatTime(item.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 8)
        .background(color.opacity(0.1))
        .cornerRadius(4)
    }

    /// 删除记录调试视图
    private var deletionDebugView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "trash.circle")
                    .foregroundColor(.red)
                Text("删除记录调试")
                    .font(.headline)
                Spacer()
                Button("关闭") {
                    showingDeletionDebug = false
                }
                .buttonStyle(.plain)
            }

            let deletedEvents = syncManager.getAllDeletedEventInfos()
            let stats = syncManager.getDeletionStatistics()

            // 统计信息
            VStack(alignment: .leading, spacing: 8) {
                Text("统计信息")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack {
                    Text("总删除记录:")
                    Spacer()
                    Text("\(stats.totalCount)")
                        .fontWeight(.medium)
                }

                HStack {
                    Text("有详细信息:")
                    Spacer()
                    Text("\(stats.withDetails)")
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }

                HStack {
                    Text("仅UUID:")
                    Spacer()
                    Text("\(stats.uuidOnly)")
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                }
            }
            .padding()
            .background(Color.systemBackground)
            .cornerRadius(8)

            // 删除记录列表
            if !deletedEvents.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("删除记录详情")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(deletedEvents, id: \.uuid) { deletedEvent in
                                deletionRecordRow(deletedEvent)
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                }
            } else {
                Text("暂无删除记录")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }

            // 操作按钮
            HStack {
                Button("智能清理虚假记录") {
                    syncManager.clearSpuriousDeletionRecords()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.orange)

                Spacer()

                Button("清除所有删除记录") {
                    syncManager.clearAllDeletionRecords()
                    showingDeletionDebug = false
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }
        }
        .padding()
        .frame(width: 500, height: 600)
    }

    /// 删除记录行
    private func deletionRecordRow(_ deletedEvent: DeletedEventInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(deletedEvent.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Button("清除") {
                    syncManager.clearDeletedEvent(uuid: deletedEvent.uuid)
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
                .font(.caption)
            }

            HStack {
                Text("类型: \(deletedEvent.eventType)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("删除时间: \(formatSyncTime(deletedEvent.deletedAt))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let reason = deletedEvent.reason {
                Text("原因: \(reason)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }

            Text("UUID: \(deletedEvent.uuid)")
                .font(.caption)
                .foregroundColor(.secondary)
                .textSelection(.enabled)
        }
        .padding(8)
        .background(Color.systemBackground)
        .cornerRadius(6)
    }

    /// 删除日志视图
    private var deletionLogView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(.blue)
                Text("删除跟踪日志")
                    .font(.headline)
                Spacer()
                Button("清除日志") {
                    syncManager.clearDeletionTrackingLog()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("关闭") {
                    showingDeletionLog = false
                }
                .buttonStyle(.plain)
            }

            let logs = syncManager.getDeletionTrackingLog()

            if !logs.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(logs.enumerated().reversed()), id: \.offset) { index, log in
                            Text(log)
                                .font(.caption)
                                .foregroundColor(log.contains("⚠️") ? .orange : log.contains("🗑️") ? .red : log.contains("🧹") ? .green : .primary)
                                .textSelection(.enabled)
                                .padding(.vertical, 2)
                        }
                    }
                }
                .frame(maxHeight: 400)
                .background(Color.systemBackground)
                .cornerRadius(8)
            } else {
                Text("暂无日志记录")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .padding()
        .frame(width: 600, height: 500)
    }

    // MARK: - Authentication Views

    private var unauthenticatedView: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "person.circle")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)

                Text("需要用户认证")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("请先完成用户认证以使用同步功能")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("开始认证") {
                showingAuthView = true
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var userInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.accentColor)
                Text("用户信息")
                    .font(.headline)
                Spacer()

                Button("解绑设备") {
                    showingUnbindConfirmation = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundColor(.red)
                .disabled(isUnbinding)

                Button("管理账户") {
                    showingAuthView = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if let user = authManager.currentUser {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("用户名：")
                            .foregroundColor(.secondary)
                        Text(user.name ?? "未设置")
                        Spacer()
                    }

                    HStack {
                        Text("用户ID：")
                            .foregroundColor(.secondary)
                        Text(user.id)
                            .font(.monospaced(.caption)())
                            .textSelection(.enabled)

                        Button(action: {
                            #if canImport(AppKit)
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(user.id, forType: .string)
                            #endif
                        }) {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)

                        Spacer()
                    }

                    if let email = user.email {
                        HStack {
                            Text("邮箱：")
                                .foregroundColor(.secondary)
                            Text(email)
                            Spacer()
                        }
                    }
                }
                .font(.caption)
            }

            // 认证状态指示器
            HStack {
                Circle()
                    .fill(getAuthStatusColor())
                    .frame(width: 8, height: 8)

                Text(getAuthStatusText())
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let expiresAt = authManager.tokenExpiresAt {
                    let isExpired = expiresAt <= Date()
                    Text("• 过期时间：\(formatTokenExpiry(expiresAt))")
                        .font(.caption)
                        .foregroundColor(isExpired ? .red : .secondary)

                    if isExpired {
                        Text("(已过期)")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                Spacer()
            }
        }
        .padding()
        .background(Color.systemBackground)
        .cornerRadius(8)
    }

    // MARK: - Helper Methods



    private func formatTokenExpiry(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        // 检查是否是今天
        if calendar.isDateInToday(date) {
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else {
            // 不是今天，显示完整的日期和时间
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }

    private func getAuthStatusColor() -> Color {
        if let expiresAt = authManager.tokenExpiresAt, expiresAt <= Date() {
            return .orange // Token已过期
        }
        return authManager.isAuthenticated ? .green : .red
    }

    private func getAuthStatusText() -> String {
        if let expiresAt = authManager.tokenExpiresAt, expiresAt <= Date() {
            return "认证已过期"
        }
        return authManager.isAuthenticated ? "已认证" : "未认证"
    }

    /// 执行设备解绑
    private func performDeviceUnbind() async {
        isUnbinding = true

        do {
            let result = try await authManager.unbindDevice()
            print("设备解绑成功: \(result.deviceUUID)")

            // 解绑成功后，UI会自动切换到未认证状态
            // 因为AuthManager会清理认证状态

        } catch {
            unbindError = error.localizedDescription
            print("设备解绑失败: \(error)")
        }

        isUnbinding = false
    }

    /// 处理认证失败，执行自动登出流程
    private func handleAuthenticationFailure() async {
        print("🔐 开始处理认证失败，执行自动登出流程")

        // 1. 清除认证失败标志
        syncManager.authenticationFailureDetected = false
        syncManager.authenticationFailureMessage = ""

        // 2. 执行登出操作，清除本地认证数据
        await authManager.logout()

        // 3. 重置同步状态
        await MainActor.run {
            syncManager.syncStatus = .idle
            syncManager.lastSyncTime = nil
            syncManager.pendingSyncCount = 0
            syncManager.serverData = nil
            syncManager.serverDataSummary = nil
            syncManager.serverIncrementalChanges = nil
            syncManager.syncWorkspace = nil
            syncManager.lastSyncRecord = nil
            syncManager.serverConnectionStatus = "未连接"
            syncManager.lastServerResponseStatus = "未知"
            syncManager.lastServerResponseTime = nil
        }

        print("🔐 自动登出完成，用户界面将切换到未认证状态")

        // 4. 显示提示信息（可选）
        // 由于UI会自动切换到未认证状态，这里不需要额外的提示
    }
}

#Preview {
    SyncView()
        .environmentObject(SyncManager(serverURL: "http://localhost:8080", authManager: AuthManager(serverURL: "http://localhost:8080")))
        .environmentObject(AuthManager(serverURL: "http://localhost:8080"))
        .frame(width: 600, height: 800)
}
