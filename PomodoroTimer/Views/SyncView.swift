//
//  SyncView.swift
//  PomodoroTimer
//
//  Created by Assistant on 2024
//

import SwiftUI

struct SyncView: View {
    @EnvironmentObject var syncManager: SyncManager
    @State private var pendingSyncItems: [PendingSyncItem] = []
    @State private var showingPendingData = false
    @State private var serverURL = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // 标题
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("数据同步")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal)
            
            ScrollView {
                VStack(spacing: 24) {
                    // 服务器配置区域
                    serverConfigurationSection
                    
                    Divider()
                    
                    // 同步状态区域
                    syncStatusSection
                    
                    Divider()
                    
                    // Git风格的同步状态概览
                    syncStatusOverviewSection

                    Divider()

                    // 工作区状态（类似git status）
                    workspaceStatusSection

                    Divider()

                    // 远程状态
                    remoteStatusSection

                    Divider()

                    // Git风格的同步操作
                    gitStyleSyncActionsSection
                }
                .padding()
            }
        }
        .onAppear {
            serverURL = syncManager.serverURL
            loadPendingSyncData()
            // 自动加载本地数据预览
            syncManager.loadLocalDataPreview()
            // 自动加载服务端数据预览（但不在同步过程中）
            if !syncManager.isSyncing {
                Task {
                    await syncManager.loadServerDataPreview()
                    await syncManager.generateSyncWorkspace()
                }
            }
        }
        .onChange(of: syncManager.pendingSyncCount) { _ in
            loadPendingSyncData()
        }
    }
    
    // MARK: - 服务器配置区域
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
    
    // MARK: - 同步状态区域
    private var syncStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
                Text("同步状态")
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 8) {
                // 当前状态
                HStack {
                    Text("当前状态:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    statusIndicator
                }
                
                // 最后同步时间
                HStack {
                    Text("最后同步:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(lastSyncTimeText)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                
                // 待同步数据数量
                HStack {
                    Text("待同步数据:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(syncManager.pendingSyncCount) 条")
                        .font(.subheadline)
                        .foregroundColor(syncManager.pendingSyncCount > 0 ? .orange : .primary)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    // MARK: - 待同步数据区域
    private var pendingSyncDataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(action: {
                    withAnimation {
                        showingPendingData.toggle()
                    }
                }) {
                    HStack {
                        Image(systemName: showingPendingData ? "chevron.down" : "chevron.right")
                            .font(.caption)
                        Image(systemName: "list.bullet")
                            .foregroundColor(.secondary)
                        Text("待同步数据列表")
                            .font(.headline)
                        Spacer()
                        Text("(\(syncManager.pendingSyncCount))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            if showingPendingData {
                if pendingSyncItems.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle")
                                .font(.title2)
                                .foregroundColor(.green)
                            Text("没有待同步的数据")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(pendingSyncItems) { item in
                            pendingSyncItemRow(item)
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    // MARK: - 同步操作区域
    private var syncActionsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.secondary)
                Text("同步操作")
                    .font(.headline)
                Spacer()
            }
            
            HStack(spacing: 12) {
                Button("全量同步") {
                    Task {
                        await syncManager.performFullSync()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(syncManager.isSyncing || syncManager.serverURL.isEmpty)
                
                Button("增量同步") {
                    Task {
                        await syncManager.performIncrementalSync()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(syncManager.isSyncing || syncManager.serverURL.isEmpty)
                
                Spacer()
                
                if syncManager.isSyncing {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("同步中...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
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
    
    // MARK: - 辅助视图
    private var statusIndicator: some View {
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
    
    private func pendingSyncItemRow(_ item: PendingSyncItem) -> some View {
        HStack {
            Image(systemName: item.type.iconName)
                .foregroundColor(.accentColor)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(item.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(timeAgoText(from: item.timestamp))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color(NSColor.separatorColor).opacity(0.3))
        .cornerRadius(6)
    }
    
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
    
    // MARK: - 本地数据预览区域
    private var localDataPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "desktopcomputer")
                    .foregroundColor(.secondary)
                Text("本地数据")
                    .font(.headline)
                Spacer()

                Button(action: {
                    syncManager.loadLocalDataPreview()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("刷新")
                            .font(.caption)
                    }
                }
                .buttonStyle(BorderlessButtonStyle())
            }

            if let localData = syncManager.localData {
                localDataContent(localData)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("暂无本地数据")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("点击刷新按钮获取本地数据预览")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private func localDataContent(_ localData: LocalDataPreview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 数据统计
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(localData.eventCount)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text("总事件数")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(localData.completedEventCount)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                    Text("已完成")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(formatDuration(localData.totalPomodoroTime))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    Text("专注时长")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // 计时器设置
            if let timerSettings = localData.timerSettings {
                VStack(alignment: .leading, spacing: 4) {
                    Text("计时器设置")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        Text("番茄钟: \(Int(timerSettings.pomodoroTime/60))分钟")
                            .font(.caption2)
                        Text("短休息: \(Int(timerSettings.shortBreakTime/60))分钟")
                            .font(.caption2)
                        Text("长休息: \(Int(timerSettings.longBreakTime/60))分钟")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
            }

            // 最近事件
            if !localData.recentEvents.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("最近事件")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(localData.recentEvents.prefix(3), id: \.id) { event in
                        HStack {
                            Circle()
                                .fill(localEventTypeColor(event.type))
                                .frame(width: 6, height: 6)

                            Text(event.title)
                                .font(.caption2)
                                .lineLimit(1)

                            Spacer()

                            Text(formatLocalEventTime(event.startTime))
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            if event.isCompleted {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            }

            // 最后更新时间
            HStack {
                Spacer()
                Text("更新于 \(timeAgoText(from: localData.lastUpdated))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func localEventTypeColor(_ eventType: PomodoroEvent.EventType) -> Color {
        switch eventType {
        case .pomodoro:
            return .blue
        case .shortBreak:
            return .green
        case .longBreak:
            return .orange
        case .custom:
            return .gray
        }
    }

    private func formatLocalEventTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }

    // MARK: - 服务端数据预览区域
    private var serverDataPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "cloud")
                    .foregroundColor(.secondary)
                Text("服务端数据")
                    .font(.headline)
                Spacer()

                Button(action: {
                    // 只在非同步状态下刷新服务端数据
                    if !syncManager.isSyncing {
                        Task {
                            await syncManager.loadServerDataPreview()
                        }
                    }
                }) {
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

            if syncManager.isLoadingServerData {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("正在获取服务端数据...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            } else if let serverData = syncManager.serverData {
                serverDataContent(serverData)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("暂无服务端数据")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("点击刷新按钮获取服务端数据预览")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private func serverDataContent(_ serverData: ServerDataPreview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 数据统计
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(serverData.eventCount)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text("总事件数")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(serverData.completedEventCount)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                    Text("已完成")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(formatDuration(serverData.totalPomodoroTime))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    Text("专注时长")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // 计时器设置
            if let timerSettings = serverData.timerSettings {
                VStack(alignment: .leading, spacing: 4) {
                    Text("计时器设置")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        Text("番茄钟: \(Int(timerSettings.pomodoroTime/60))分钟")
                            .font(.caption2)
                        Text("短休息: \(Int(timerSettings.shortBreakTime/60))分钟")
                            .font(.caption2)
                        Text("长休息: \(Int(timerSettings.longBreakTime/60))分钟")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
            }

            // 最近事件
            if !serverData.recentEvents.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("最近事件")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(serverData.recentEvents.prefix(3), id: \.uuid) { event in
                        HStack {
                            Circle()
                                .fill(eventTypeColor(event.eventType))
                                .frame(width: 6, height: 6)

                            Text(event.title)
                                .font(.caption2)
                                .lineLimit(1)

                            Spacer()

                            Text(formatEventTime(event.startTime))
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            if event.isCompleted {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            }

            // 最后更新时间
            HStack {
                Spacer()
                Text("更新于 \(timeAgoText(from: serverData.lastUpdated))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h\(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

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

    private func formatEventTime(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }

    private func loadPendingSyncData() {
        Task {
            let items = await syncManager.getPendingSyncData()
            DispatchQueue.main.async {
                self.pendingSyncItems = items
            }
        }
    }

    // MARK: - Git风格界面组件

    /// 同步状态概览
    private var syncStatusOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.triangle.branch")
                    .foregroundColor(.secondary)
                Text("同步状态概览")
                    .font(.headline)
                Spacer()
            }

            if let workspace = syncManager.syncWorkspace {
                HStack(spacing: 20) {
                    // 本地状态
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("本地:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(syncManager.localData?.eventCount ?? 0)个番茄钟")
                                .font(.caption)
                                .fontWeight(.medium)

                            Text("\(syncManager.localData?.systemEventCount ?? 0)个活动记录")
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            if let timerSettings = syncManager.localData?.timerSettings {
                                Text("设置: \(timerSettings.pomodoroTime)min")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }

                        if workspace.hasChanges {
                            Text("(\(workspace.totalLocalChanges)个未同步)")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }

                    // 同步状态指示器
                    VStack {
                        Image(systemName: workspace.hasChanges || workspace.hasRemoteChanges ? "arrow.left.arrow.right" : "checkmark.circle")
                            .foregroundColor(workspace.hasChanges || workspace.hasRemoteChanges ? .orange : .green)
                            .font(.title2)

                        // 数据差异指示
                        if let localData = syncManager.localData, let serverData = syncManager.serverData {
                            let eventDiff = localData.eventCount - serverData.eventCount
                            let systemEventDiff = localData.systemEventCount - serverData.systemEventCount

                            if eventDiff != 0 || systemEventDiff != 0 {
                                VStack(spacing: 1) {
                                    if eventDiff != 0 {
                                        Text("\(eventDiff > 0 ? "+" : "")\(eventDiff)")
                                            .font(.caption2)
                                            .foregroundColor(eventDiff > 0 ? .orange : .blue)
                                    }
                                    if systemEventDiff != 0 {
                                        Text("活动\(systemEventDiff > 0 ? "+" : "")\(systemEventDiff)")
                                            .font(.caption2)
                                            .foregroundColor(systemEventDiff > 0 ? .orange : .blue)
                                    }
                                }
                            }
                        }
                    }

                    // 远程状态
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack {
                            Spacer()
                            Text("远程:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(syncManager.serverData?.eventCount ?? 0)个番茄钟")
                                .font(.caption)
                                .fontWeight(.medium)

                            Text("\(syncManager.serverData?.systemEventCount ?? 0)个活动记录")
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            if let timerSettings = syncManager.serverData?.timerSettings {
                                Text("设置: \(timerSettings.pomodoroTime)min")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }

                        if workspace.hasRemoteChanges {
                            Text("(\(workspace.totalRemoteChanges)个新增)")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                }

                // 最后同步时间
                if let lastSyncTime = workspace.lastSyncTime {
                    HStack {
                        Text("最后同步:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(timeAgoText(from: lastSyncTime))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    Text("尚未同步")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            } else {
                Text("正在加载同步状态...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    /// 工作区状态（类似git status）
    private var workspaceStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "folder")
                    .foregroundColor(.secondary)
                Text("工作区状态")
                    .font(.headline)
                Spacer()

                Button(action: {
                    Task {
                        await syncManager.generateSyncWorkspace()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("刷新")
                            .font(.caption)
                    }
                }
                .buttonStyle(BorderlessButtonStyle())
            }

            if let workspace = syncManager.syncWorkspace {
                workspaceContent(workspace)
            } else {
                Text("正在分析工作区状态...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private func workspaceContent(_ workspace: SyncWorkspace) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 已暂存的变更
            if !workspace.staged.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("已暂存 (\(workspace.staged.count)个)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }

                    ForEach(workspace.staged.prefix(3)) { item in
                        workspaceItemRow(item)
                    }

                    if workspace.staged.count > 3 {
                        Text("... 还有 \(workspace.staged.count - 3) 个项目")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.leading, 16)
                    }
                }
            }

            // 未暂存的变更
            if !workspace.unstaged.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                        Text("未暂存 (\(workspace.unstaged.count)个)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    }

                    ForEach(workspace.unstaged.prefix(3)) { item in
                        workspaceItemRow(item)
                    }
                }
            }

            // 冲突
            if !workspace.conflicts.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        Text("冲突 (\(workspace.conflicts.count)个)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                    }

                    ForEach(workspace.conflicts) { item in
                        workspaceItemRow(item)
                    }
                }
            }

            // 无变更状态
            if !workspace.hasChanges && !workspace.hasConflicts {
                HStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.green)
                    Text("工作区干净，没有需要提交的变更")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func workspaceItemRow(_ item: WorkspaceItem) -> some View {
        HStack(spacing: 8) {
            Image(systemName: item.status.icon)
                .foregroundColor(Color(item.status.color))
                .font(.caption2)

            Image(systemName: item.type.icon)
                .foregroundColor(.secondary)
                .font(.caption2)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.caption2)
                    .lineLimit(1)

                Text("\(item.status.displayName) - \(item.description)")
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

    private func formatWorkspaceTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    // MARK: - 按钮状态管理

    /// 是否启用拉取按钮
    private func shouldEnablePullButton() -> Bool {
        guard let workspace = syncManager.syncWorkspace else { return false }

        // 仅当有远程变更且没有本地变更时启用拉取
        return workspace.hasRemoteChanges && !workspace.hasChanges
    }

    /// 是否启用推送按钮
    private func shouldEnablePushButton() -> Bool {
        guard let workspace = syncManager.syncWorkspace else { return false }

        // 仅当有本地变更且没有远程变更时启用推送
        return workspace.hasChanges && !workspace.hasRemoteChanges
    }

    /// 是否启用智能同步按钮
    private func shouldEnableSmartSyncButton() -> Bool {
        guard let workspace = syncManager.syncWorkspace else { return false }

        // 当本地和远程都有变更时启用智能同步
        return workspace.hasChanges && workspace.hasRemoteChanges
    }

    /// 获取当前同步状态的描述
    private func getSyncStatusDescription() -> String {
        guard let workspace = syncManager.syncWorkspace else {
            return "正在分析同步状态..."
        }

        if !workspace.hasChanges && !workspace.hasRemoteChanges {
            return "✅ 本地和远程数据已同步"
        } else if workspace.hasChanges && !workspace.hasRemoteChanges {
            return "💡 使用「推送」将本地变更上传到服务器"
        } else if !workspace.hasChanges && workspace.hasRemoteChanges {
            return "💡 使用「拉取」获取服务器上的新变更"
        } else {
            return "💡 使用「智能同步」来合并本地和远程变更"
        }
    }

    /// 获取同步状态描述的颜色
    private func getSyncStatusColor() -> Color {
        guard let workspace = syncManager.syncWorkspace else {
            return .secondary
        }

        if !workspace.hasChanges && !workspace.hasRemoteChanges {
            return .green  // 已同步
        } else if workspace.hasChanges && !workspace.hasRemoteChanges {
            return .orange  // 需要推送
        } else if !workspace.hasChanges && workspace.hasRemoteChanges {
            return .blue   // 需要拉取
        } else {
            return .purple  // 需要智能同步
        }
    }

    /// 是否显示强制操作按钮
    private func shouldShowForceOperations() -> Bool {
        // 只有在有本地数据或远程数据时才显示强制操作
        let hasLocalData = (syncManager.localData?.eventCount ?? 0) > 0
        let hasRemoteData = (syncManager.serverData?.eventCount ?? 0) > 0

        return hasLocalData || hasRemoteData
    }

    /// 远程状态
    private var remoteStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "cloud")
                    .foregroundColor(.secondary)
                Text("远程状态")
                    .font(.headline)
                Spacer()
            }

            if let workspace = syncManager.syncWorkspace {
                if workspace.hasRemoteChanges {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 8, height: 8)
                            Text("远程新增 (\(workspace.remoteChanges.count)个)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                        }

                        ForEach(workspace.remoteChanges.prefix(3)) { item in
                            workspaceItemRow(item)
                        }

                        if workspace.remoteChanges.count > 3 {
                            Text("... 还有 \(workspace.remoteChanges.count - 3) 个项目")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.leading, 16)
                        }
                    }
                } else {
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.green)
                        Text("远程没有新的变更")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("正在检查远程状态...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    /// Git风格的同步操作
    private var gitStyleSyncActionsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.secondary)
                Text("同步操作")
                    .font(.headline)
                Spacer()
            }

            // 主要操作
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    // 拉取
                    Button(action: {
                        Task {
                            await syncManager.performSync(mode: .pullOnly)
                        }
                    }) {
                        HStack {
                            Image(systemName: SyncMode.pullOnly.icon)
                            Text(SyncMode.pullOnly.displayName)
                        }
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .disabled(syncManager.isSyncing || syncManager.serverURL.isEmpty || !shouldEnablePullButton())

                    // 推送
                    Button(action: {
                        Task {
                            await syncManager.performSync(mode: .pushOnly)
                        }
                    }) {
                        HStack {
                            Image(systemName: SyncMode.pushOnly.icon)
                            Text(SyncMode.pushOnly.displayName)
                        }
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .disabled(syncManager.isSyncing || syncManager.serverURL.isEmpty || !shouldEnablePushButton())

                    // 智能同步
                    Button(action: {
                        Task {
                            await syncManager.performSync(mode: .smartMerge)
                        }
                    }) {
                        HStack {
                            Image(systemName: SyncMode.smartMerge.icon)
                            Text(SyncMode.smartMerge.displayName)
                        }
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .background(shouldEnableSmartSyncButton() ? Color.accentColor : Color.clear)
                    .foregroundColor(shouldEnableSmartSyncButton() ? .white : .primary)
                    .cornerRadius(6)
                    .disabled(syncManager.isSyncing || syncManager.serverURL.isEmpty || !shouldEnableSmartSyncButton())
                }

                // 危险操作（仅在有数据时显示）
                if shouldShowForceOperations() {
                    HStack(spacing: 12) {
                        // 强制覆盖本地
                        Button(action: {
                            Task {
                                await syncManager.performSync(mode: .forceOverwriteLocal)
                            }
                        }) {
                            HStack {
                                Image(systemName: SyncMode.forceOverwriteLocal.icon)
                                Text(SyncMode.forceOverwriteLocal.displayName)
                            }
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .foregroundColor(.red)
                        .disabled(syncManager.isSyncing || syncManager.serverURL.isEmpty)

                        // 强制覆盖远程
                        Button(action: {
                            Task {
                                await syncManager.performSync(mode: .forceOverwriteRemote)
                            }
                        }) {
                            HStack {
                                Image(systemName: SyncMode.forceOverwriteRemote.icon)
                                Text(SyncMode.forceOverwriteRemote.displayName)
                            }
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .foregroundColor(.red)
                        .disabled(syncManager.isSyncing || syncManager.serverURL.isEmpty)

                        Spacer()
                    }
                }
            }

            // 操作说明
            VStack(alignment: .leading, spacing: 4) {
                Text(getSyncStatusDescription())
                    .font(.caption2)
                    .foregroundColor(getSyncStatusColor())
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
}

#Preview {
    SyncView()
        .environmentObject(SyncManager(serverURL: "http://localhost:8080"))
        .frame(width: 600, height: 800)
}
