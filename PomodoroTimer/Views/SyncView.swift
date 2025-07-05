//
//  SyncView.swift
//  PomodoroTimer
//
//  Created by Assistant on 2024
//

import SwiftUI

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
    @StateObject private var fullChangesManager = FullChangesManager()
    @State private var serverURL = ""
    @State private var debugMode = true // Debug模式默认开启
    @State private var showingLocalDataDetail = false
    @State private var showingServerDataDetail = false
    @State private var showingSyncHistory = false
    @State private var selectedDataType: DataType = .pomodoroEvents

    enum DataType: String, CaseIterable {
        case pomodoroEvents = "番茄钟事件"
        case systemEvents = "系统事件"
        case timerSettings = "计时器设置"
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            titleBar

            ScrollView {
                VStack(spacing: 20) {
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
        }
        .onAppear {
            serverURL = syncManager.serverURL
            syncManager.loadLocalDataPreview()
            if !syncManager.isSyncing {
                Task {
                    await syncManager.loadServerDataPreview()
                    await syncManager.generateSyncWorkspace()
                }
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
    }

    // MARK: - UI组件

    /// 标题栏
    private var titleBar: some View {
        HStack {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.title2)
                .foregroundColor(.accentColor)
            Text("数据同步")
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            // Debug模式切换
            Toggle("Debug", isOn: $debugMode)
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                .controlSize(.small)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }

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
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
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
        .background(Color(NSColor.controlBackgroundColor))
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
        .background(Color(NSColor.controlBackgroundColor))
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
                serverCount: syncManager.serverData?.eventCount ?? 0
            )

            dataComparisonRow(
                title: "系统事件",
                localCount: syncManager.localData?.systemEventCount ?? 0,
                serverCount: syncManager.serverData?.systemEventCount ?? 0
            )

            dataComparisonRow(
                title: "计时器设置",
                localCount: syncManager.localData?.timerSettings != nil ? 1 : 0,
                serverCount: syncManager.serverData?.timerSettings != nil ? 1 : 0
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

            // 服务端数据 - 可点击
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

            // 状态指示器
            Group {
                if localCount == serverCount {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else if localCount > serverCount {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(.blue)
                } else {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(.orange)
                }
            }
            .font(.subheadline)
            .frame(width: 60, alignment: .center)
        }
        .padding(.vertical, 4)
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

    /// 同步状态图例
    private var syncStatusLegend: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            Text("状态说明:")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

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
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
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
        .background(Color(NSColor.controlBackgroundColor))
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
        .background(Color(NSColor.separatorColor).opacity(0.1))
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
            } else if let serverData = syncManager.serverData {
                VStack(alignment: .leading, spacing: 8) {
                    dataCountRow(
                        title: "番茄钟事件",
                        count: serverData.eventCount,
                        isClickable: debugMode,
                        action: { showServerDataDetail(.pomodoroEvents) }
                    )

                    dataCountRow(
                        title: "系统事件",
                        count: serverData.systemEventCount,
                        isClickable: debugMode,
                        action: { showServerDataDetail(.systemEvents) }
                    )

                    dataCountRow(
                        title: "计时器设置",
                        count: serverData.timerSettings != nil ? 1 : 0,
                        isClickable: debugMode,
                        action: { showServerDataDetail(.timerSettings) }
                    )
                }
            } else {
                Text("暂无数据")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(NSColor.separatorColor).opacity(0.1))
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
                    if workspace.hasChanges {
                        differenceSection(
                            title: "本地变更",
                            items: workspace.staged + workspace.unstaged,
                            color: .orange,
                            icon: "arrow.up.circle"
                        )
                    }

                    // 远程变更
                    if workspace.hasRemoteChanges {
                        differenceSection(
                            title: "远程变更",
                            items: workspace.remoteChanges,
                            color: .blue,
                            icon: "arrow.down.circle"
                        )
                    }

                    // 冲突
                    if workspace.hasConflicts {
                        differenceSection(
                            title: "冲突项目",
                            items: workspace.conflicts,
                            color: .red,
                            icon: "exclamationmark.triangle"
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
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
                HStack(spacing: 12) {
                    // 仅拉取
                    syncActionButton(
                        mode: .pullOnly,
                        enabled: shouldEnablePullButton(),
                        style: .bordered
                    )

                    // 仅推送
                    syncActionButton(
                        mode: .pushOnly,
                        enabled: shouldEnablePushButton(),
                        style: .bordered
                    )
                }

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
        .background(Color(NSColor.controlBackgroundColor))
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

                if let workspace = syncManager.syncWorkspace {
                    debugInfoRow("本地变更数", "\(workspace.totalLocalChanges)")
                    debugInfoRow("远程变更数", "\(workspace.totalRemoteChanges)")
                    debugInfoRow("冲突数", "\(workspace.conflicts.count)")
                }

                if let lastSync = syncManager.lastSyncTime {
                    debugInfoRow("最后同步时间戳", "\(Int64(lastSync.timeIntervalSince1970 * 1000))")
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - 辅助视图和方法

    /// 同步状态指示器
    private var syncStatusIndicator: some View {
        HStack {
            switch syncManager.syncStatus {
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
                HStack {
                    Image(systemName: item.status.icon)
                        .foregroundColor(Color(item.status.color))
                        .font(.caption2)

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

    // MARK: - 辅助方法

    /// 刷新所有数据
    private func refreshAllData() {
        syncManager.loadLocalDataPreview()
        if !syncManager.isSyncing {
            Task {
                await syncManager.loadServerDataPreview()
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
        guard let localData = syncManager.localData,
              let serverData = syncManager.serverData else {
            return "questionmark.circle"
        }

        if localData.eventCount == serverData.eventCount &&
           localData.systemEventCount == serverData.systemEventCount {
            return "checkmark.circle"
        } else {
            return "arrow.left.arrow.right"
        }
    }

    /// 获取对比颜色
    private func getComparisonColor() -> Color {
        guard let localData = syncManager.localData,
              let serverData = syncManager.serverData else {
            return .secondary
        }

        if localData.eventCount == serverData.eventCount &&
           localData.systemEventCount == serverData.systemEventCount {
            return .green
        } else {
            return .orange
        }
    }

    /// 获取对比文本
    private func getComparisonText() -> String {
        guard let localData = syncManager.localData,
              let serverData = syncManager.serverData else {
            return "数据加载中"
        }

        if localData.eventCount == serverData.eventCount &&
           localData.systemEventCount == serverData.systemEventCount {
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
                        HStack {
                            Image(systemName: item.status.icon)
                                .foregroundColor(Color(item.status.color))
                                .font(.caption)
                                .frame(width: 16)

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

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(item.status.displayName)
                                    .font(.caption2)
                                    .foregroundColor(Color(item.status.color))
                                Text(formatWorkspaceTime(item.timestamp))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
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
    }

    /// 同步历史记录行
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
            } else {
                Text("✗ \(record.errorMessage ?? "同步失败")")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(6)
    }

    // MARK: - 按钮状态管理

    /// 是否启用拉取按钮
    private func shouldEnablePullButton() -> Bool {
        guard let workspace = syncManager.syncWorkspace else { return false }
        return workspace.hasRemoteChanges && !workspace.hasChanges
    }

    /// 是否启用推送按钮
    private func shouldEnablePushButton() -> Bool {
        guard let workspace = syncManager.syncWorkspace else { return false }
        return workspace.hasChanges && !workspace.hasRemoteChanges
    }

    /// 是否显示强制操作按钮
    private func shouldShowForceOperations() -> Bool {
        let hasLocalData = (syncManager.localData?.eventCount ?? 0) > 0
        let hasRemoteData = (syncManager.serverData?.eventCount ?? 0) > 0
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
                if let serverData = syncManager.serverData {
                    Text("总数: \(serverData.eventCount)")
                        .font(.caption)
                    Text("已完成: \(serverData.completedEventCount)")
                        .font(.caption)

                    if !serverData.recentEvents.isEmpty {
                        Text("最近事件:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.top, 8)

                        ForEach(serverData.recentEvents.prefix(5), id: \.uuid) { event in
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

#Preview {
    SyncView()
        .environmentObject(SyncManager(serverURL: "http://localhost:8080"))
        .frame(width: 600, height: 800)
}
