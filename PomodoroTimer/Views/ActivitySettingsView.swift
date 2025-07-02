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
    @State private var exportedData: Data? = nil
    @State private var selectedDataRetentionDays = 30
    
    private let dataRetentionOptions = [7, 14, 30, 60, 90, 180]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 监控状态部分
                VStack(alignment: .leading, spacing: 12) {
                    Text("监控状态")
                        .font(.headline)
                        .padding(.horizontal, 20)

                    VStack(spacing: 12) {
                        monitoringStatusView
                        permissionStatusView
                    }
                    .padding(.vertical, 12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .padding(.horizontal, 20)
                }

                // 权限管理部分
                VStack(alignment: .leading, spacing: 12) {
                    Text("权限管理")
                        .font(.headline)
                        .padding(.horizontal, 20)

                    VStack(spacing: 12) {
                        permissionManagementView
                    }
                    .padding(.vertical, 12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .padding(.horizontal, 20)
                }

                // 数据管理部分
                VStack(alignment: .leading, spacing: 12) {
                    Text("数据管理")
                        .font(.headline)
                        .padding(.horizontal, 20)

                    VStack(spacing: 12) {
                        dataManagementView
                    }
                    .padding(.vertical, 12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .padding(.horizontal, 20)
                }

                // 隐私设置部分
                VStack(alignment: .leading, spacing: 12) {
                    Text("隐私设置")
                        .font(.headline)
                        .padding(.horizontal, 20)

                    VStack(spacing: 12) {
                        privacySettingsView
                    }
                    .padding(.vertical, 12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .padding(.horizontal, 20)
                }

                // 关于部分
                VStack(alignment: .leading, spacing: 12) {
                    Text("关于")
                        .font(.headline)
                        .padding(.horizontal, 20)

                    VStack(spacing: 12) {
                        aboutView
                    }
                    .padding(.vertical, 12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 20)
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
            if let data = exportedData, let string = String(data: data, encoding: .utf8) {
                ExportDataView(data: string)
            } else {
                ExportDataView(data: "导出失败")
            }
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
        .padding(.horizontal, 20)
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
        .padding(.horizontal, 20)
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
        .padding(.horizontal, 20)
    }
    
    // MARK: - 数据管理视图
    
    private var dataManagementView: some View {
        VStack(spacing: 12) {
            // 存储信息
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "folder")
                        .foregroundColor(.blue)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("存储位置")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text(activityMonitor.dataStoragePath)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()

                    Button("复制路径") {
                        #if canImport(Cocoa)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(activityMonitor.dataStoragePath, forType: .string)
                        #endif
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(.green)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("文件大小")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text(activityMonitor.dataFileSize)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button("在Finder中显示") {
                        #if canImport(Cocoa)
                        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        NSWorkspace.shared.open(documentsPath)
                        #endif
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding()
            .background(Color.primary.opacity(0.05))
            .cornerRadius(8)

            Divider()

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
        .padding(.horizontal, 20)
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
        .padding(.horizontal, 20)
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
        .padding(.horizontal, 20)
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
        #if canImport(Cocoa)
        .background(Color(NSColor.controlBackgroundColor))
        #else
        .background(Color(.systemGray6))
        #endif
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
                    #if canImport(Cocoa)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(data, forType: .string)
                    #else
                    UIPasteboard.general.string = data
                    #endif
                }
            }
        }
    }
}

#Preview {
    ActivitySettingsView(activityMonitor: ActivityMonitorManager())
}