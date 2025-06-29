//
//  ActivitySettingsView.swift
//  PomodoroTimer
//
//  Created by Assistant on 2024
//

import SwiftUI

/// 活动监控设置视图
struct ActivitySettingsView: View {
    @ObservedObject var activityMonitor: ActivityMonitorManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingClearDataAlert = false
    @State private var showingExportSheet = false
    @State private var exportedData: String = ""
    @State private var selectedDataRetentionDays = 30
    
    private let dataRetentionOptions = [7, 14, 30, 60, 90, 180]
    
    var body: some View {
        NavigationView {
            Form {
                // 监控状态部分
                Section("监控状态") {
                    monitoringStatusView
                    permissionStatusView
                }
                
                // 权限管理部分
                Section("权限管理") {
                    permissionManagementView
                }
                
                // 数据管理部分
                Section("数据管理") {
                    dataManagementView
                }
                
                // 隐私设置部分
                Section("隐私设置") {
                    privacySettingsView
                }
                
                // 关于部分
                Section("关于") {
                    aboutView
                }
            }
            .navigationTitle("活动监控设置")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .alert("清除数据", isPresented: $showingClearDataAlert) {
            Button("取消", role: .cancel) { }
            Button("清除", role: .destructive) {
                activityMonitor.clearHistoryData()
            }
        } message: {
            Text("此操作将永久删除所有活动监控数据，无法恢复。")
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportDataView(data: exportedData)
        }
    }
    
    // MARK: - 监控状态视图
    
    private var monitoringStatusView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(activityMonitor.isMonitoring ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                
                Text(activityMonitor.isMonitoring ? "监控中" : "未监控")
                    .font(.headline)
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { activityMonitor.isMonitoring },
                    set: { _ in activityMonitor.toggleMonitoring() }
                ))
            }
            
            if activityMonitor.isMonitoring {
                Text("当前应用: \(activityMonitor.currentApp.isEmpty ? "无" : activityMonitor.currentApp)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var permissionStatusView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: activityMonitor.hasPermissions ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(activityMonitor.hasPermissions ? .green : .orange)
                
                Text("权限状态")
                    .font(.headline)
                
                Spacer()
                
                Text(activityMonitor.permissionStatusDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !activityMonitor.hasPermissions {
                Text(activityMonitor.permissionAdvice)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    // MARK: - 权限管理视图
    
    private var permissionManagementView: some View {
        VStack(spacing: 12) {
            PermissionRow(
                title: "辅助功能权限",
                description: "用于监控应用切换和浏览器活动",
                isGranted: activityMonitor.hasPermissions,
                action: {
                    if activityMonitor.hasPermissions {
                        activityMonitor.openAccessibilitySettings()
                    } else {
                        activityMonitor.requestPermissions()
                    }
                }
            )
            
            Button("刷新权限状态") {
                activityMonitor.checkPermissions()
            }
            .buttonStyle(.bordered)
        }
    }
    
    // MARK: - 数据管理视图
    
    private var dataManagementView: some View {
        VStack(spacing: 12) {
            // 数据保留设置
            HStack {
                Text("数据保留天数")
                Spacer()
                Picker("数据保留天数", selection: $selectedDataRetentionDays) {
                    ForEach(dataRetentionOptions, id: \.self) { days in
                        Text("\(days) 天").tag(days)
                    }
                }
                .pickerStyle(.menu)
            }
            
            Button("清理旧数据") {
                activityMonitor.clearOldData(olderThanDays: selectedDataRetentionDays)
            }
            .buttonStyle(.bordered)
            
            Divider()
            
            // 导出数据
            Button("导出数据") {
                if let data = activityMonitor.exportData() {
                    exportedData = data
                    showingExportSheet = true
                }
            }
            .buttonStyle(.bordered)
            
            // 清除所有数据
            Button("清除所有数据") {
                showingClearDataAlert = true
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
        }
    }
    
    // MARK: - 隐私设置视图
    
    private var privacySettingsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("隐私保护")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                PrivacyInfoRow(
                    icon: "lock.shield",
                    title: "本地存储",
                    description: "所有数据仅存储在您的设备上"
                )
                
                PrivacyInfoRow(
                    icon: "eye.slash",
                    title: "无网络传输",
                    description: "不会向任何服务器发送您的活动数据"
                )
                
                PrivacyInfoRow(
                    icon: "trash",
                    title: "随时删除",
                    description: "您可以随时清除所有监控数据"
                )
                
                PrivacyInfoRow(
                    icon: "hand.raised",
                    title: "用户控制",
                    description: "您完全控制监控的开启和关闭"
                )
            }
        }
    }
    
    // MARK: - 关于视图
    
    private var aboutView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("功能说明")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                FeatureInfoRow(
                    icon: "app.badge",
                    title: "应用监控",
                    description: "记录应用使用时间和切换频率"
                )
                
                FeatureInfoRow(
                    icon: "globe",
                    title: "网站监控",
                    description: "跟踪浏览器访问的网站和停留时间"
                )
                
                FeatureInfoRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "生产力分析",
                    description: "分析工作效率和时间分配"
                )
                
                FeatureInfoRow(
                    icon: "moon.zzz",
                    title: "系统事件",
                    description: "记录系统睡眠、唤醒等状态变化"
                )
            }
            
            Divider()
            
            Text("版本信息")
                .font(.headline)
            
            Text("PomodoroTimer 系统监控模块")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("版本 1.0.0")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 子视图组件

struct PermissionRow: View {
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(isGranted ? "管理" : "授权") {
                    action()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            HStack {
                Image(systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(isGranted ? .green : .orange)
                
                Text(isGranted ? "已授权" : "需要授权")
                    .font(.caption)
                    .foregroundColor(isGranted ? .green : .orange)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct PrivacyInfoRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct FeatureInfoRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct ExportDataView: View {
    let data: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                Text(data)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
                    .textSelection(.enabled)
            }
            .navigationTitle("导出数据")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("复制") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(data, forType: .string)
                    }
                }
            }
        }
    }
}

#Preview {
    ActivitySettingsView(activityMonitor: ActivityMonitorManager())
}