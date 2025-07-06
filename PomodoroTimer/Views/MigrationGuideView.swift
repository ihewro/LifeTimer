//
//  MigrationGuideView.swift
//  PomodoroTimer
//
//  Created by Assistant on 2024
//

import SwiftUI

/// 数据迁移引导界面
struct MigrationGuideView: View {
    @StateObject private var migrationManager: MigrationManager
    @Environment(\.dismiss) private var dismiss
    @State private var targetUserUUID: String = ""
    @State private var showingManualInput = false
    
    init(migrationManager: MigrationManager) {
        self._migrationManager = StateObject(wrappedValue: migrationManager)
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // 标题区域
            headerSection
            
            // 迁移状态显示
            migrationStatusSection
            
            // 迁移选项
            if migrationManager.migrationStatus == .required {
                migrationOptionsSection
            }
            
            // 进度显示
            if migrationManager.migrationStatus == .inProgress {
                progressSection
            }
            
            // 完成状态
            if migrationManager.migrationStatus == .completed {
                completionSection
            }
            
            // 错误状态
            if case .failed(let error) = migrationManager.migrationStatus {
                errorSection(error)
            }
            
            Spacer()
            
            // 底部按钮
            bottomButtonsSection
        }
        .padding()
        .frame(width: 500, height: 600)
        .sheet(isPresented: $showingManualInput) {
            ManualMigrationInputView { userUUID in
                Task {
                    await migrationManager.performManualMigration(targetUserUUID: userUUID)
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("数据迁移向导")
                .font(.title)
                .fontWeight(.semibold)
            
            Text("将您的数据从设备隔离模式迁移到用户账户模式")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var migrationStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                Text("迁移状态")
                    .font(.headline)
                Spacer()
            }
            
            Text(migrationManager.migrationStatus.displayMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(statusColor.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var migrationOptionsSection: some View {
        VStack(spacing: 16) {
            Text("选择迁移方式")
                .font(.headline)
            
            VStack(spacing: 12) {
                // 自动迁移选项
                MigrationOptionCard(
                    icon: "wand.and.stars",
                    title: "自动迁移",
                    description: "系统将自动为您创建新的用户账户并迁移所有数据",
                    isRecommended: true
                ) {
                    Task {
                        await migrationManager.performAutoMigration()
                    }
                }
                
                // 手动迁移选项
                MigrationOptionCard(
                    icon: "person.badge.plus",
                    title: "迁移到现有账户",
                    description: "如果您已有用户账户，可以将数据迁移到该账户"
                ) {
                    showingManualInput = true
                }
                
                // 跳过迁移选项
                MigrationOptionCard(
                    icon: "xmark.circle",
                    title: "跳过迁移",
                    description: "暂时跳过迁移，继续使用旧版本功能（不推荐）",
                    isDestructive: true
                ) {
                    migrationManager.skipMigration()
                }
            }
        }
    }
    
    private var progressSection: some View {
        VStack(spacing: 16) {
            Text("正在迁移数据...")
                .font(.headline)
            
            VStack(spacing: 8) {
                ProgressView(value: migrationManager.migrationProgress)
                    .progressViewStyle(LinearProgressViewStyle())
                
                Text(migrationManager.migrationMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private var completionSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.green)
            
            Text("迁移完成！")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.green)
            
            Text(migrationManager.migrationMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text("您现在可以在多个设备间同步数据了")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func errorSection(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.red)
            
            Text("迁移失败")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.red)
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("重试") {
                Task {
                    await migrationManager.performAutoMigration()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var bottomButtonsSection: some View {
        HStack {
            if migrationManager.migrationStatus == .completed || migrationManager.migrationStatus == .skipped {
                Button("完成") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            } else if migrationManager.migrationStatus != .inProgress {
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Computed Properties
    
    private var statusIcon: String {
        switch migrationManager.migrationStatus {
        case .required:
            return "exclamationmark.circle"
        case .inProgress:
            return "arrow.triangle.2.circlepath"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        case .skipped:
            return "minus.circle"
        case .notRequired:
            return "checkmark.circle"
        }
    }
    
    private var statusColor: Color {
        switch migrationManager.migrationStatus {
        case .required:
            return .orange
        case .inProgress:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        case .skipped:
            return .secondary
        case .notRequired:
            return .green
        }
    }
}

// MARK: - Supporting Views

struct MigrationOptionCard: View {
    let icon: String
    let title: String
    let description: String
    var isRecommended: Bool = false
    var isDestructive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isDestructive ? .red : .accentColor)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if isRecommended {
                            Text("推荐")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                        
                        Spacer()
                    }
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isRecommended ? Color.green : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ManualMigrationInputView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var userUUID: String = ""
    let onSubmit: (String) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("迁移到现有账户")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("请输入您要迁移到的用户UUID")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            TextField("用户UUID", text: $userUUID)
                .textFieldStyle(.roundedBorder)
                .font(.monospaced(.body)())
            
            Text("注意：迁移后，您的数据将与目标账户合并")
                .font(.caption)
                .foregroundColor(.orange)
                .multilineTextAlignment(.center)
            
            HStack {
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("开始迁移") {
                    onSubmit(userUUID)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(userUUID.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }
}
