//
//  AuthenticationView.swift
//  PomodoroTimer
//
//  Created by Assistant on 2024
//

import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

/// 用户认证界面
struct AuthenticationView: View {
    @StateObject private var authManager: AuthManager
    @StateObject private var migrationManager: MigrationManager
    @State private var userUUID: String = ""
    @State private var showingUserUUIDInput = false
    @State private var showingMigrationAlert = false
    @State private var authError: String?
    
    init(authManager: AuthManager, migrationManager: MigrationManager) {
        self._authManager = StateObject(wrappedValue: authManager)
        self._migrationManager = StateObject(wrappedValue: migrationManager)
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // 标题区域
            headerSection
            
            // 认证状态显示
            authStatusSection
            
            // 迁移状态显示
            if migrationManager.migrationStatus == .required {
                migrationSection
            }
            
            // 认证操作区域
            if !authManager.isAuthenticated {
                authActionsSection
            } else {
                userInfoSection
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: 500)
        .onAppear {
            checkInitialState()
        }
        .alert("认证错误", isPresented: .constant(authError != nil)) {
            Button("确定") {
                authError = nil
            }
        } message: {
            if let error = authError {
                Text(error)
            }
        }
        .sheet(isPresented: $showingUserUUIDInput) {
            UserUUIDInputView { uuid in
                Task {
                    await bindToUser(uuid)
                }
            }
        }
        .alert("数据迁移", isPresented: $showingMigrationAlert) {
            Button("自动迁移") {
                Task {
                    await migrationManager.performAutoMigration()
                }
            }
            Button("手动迁移") {
                showingUserUUIDInput = true
            }
            Button("跳过", role: .destructive) {
                migrationManager.skipMigration()
            }
        } message: {
            Text("检测到旧版本数据，是否要迁移到新的用户账户系统？")
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
            
            Text("用户认证")
                .font(.title)
                .fontWeight(.semibold)
            
            Text("您的数据将自动同步到云端，并可在多个设备间共享")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var authStatusSection: some View {
        Group {
            switch authManager.authStatus {
            case .notAuthenticated:
                StatusCard(
                    icon: "person.slash",
                    title: "未认证",
                    message: "请选择认证方式",
                    color: .orange
                )
                
            case .authenticating:
                StatusCard(
                    icon: "arrow.triangle.2.circlepath",
                    title: "认证中...",
                    message: "正在验证身份",
                    color: .blue,
                    isAnimated: true
                )
                
            case .authenticated:
                StatusCard(
                    icon: "checkmark.circle.fill",
                    title: "已认证",
                    message: "认证成功",
                    color: .green
                )
                
            case .tokenExpired:
                StatusCard(
                    icon: "clock.badge.exclamationmark",
                    title: "认证过期",
                    message: "请重新认证",
                    color: .red
                )
                
            case .error(let error):
                StatusCard(
                    icon: "exclamationmark.triangle.fill",
                    title: "认证失败",
                    message: error,
                    color: .red
                )
            }
        }
    }
    
    private var migrationSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundColor(.blue)
                Text("数据迁移")
                    .font(.headline)
                Spacer()
            }
            
            switch migrationManager.migrationStatus {
            case .required:
                VStack(alignment: .leading, spacing: 8) {
                    Text("检测到旧版本数据需要迁移")
                        .font(.subheadline)
                    
                    HStack {
                        Button("自动迁移") {
                            Task {
                                await migrationManager.performAutoMigration()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("手动迁移") {
                            showingUserUUIDInput = true
                        }
                        .buttonStyle(.bordered)
                        
                        Button("跳过") {
                            migrationManager.skipMigration()
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.secondary)
                    }
                }
                
            case .inProgress:
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text(migrationManager.migrationMessage)
                            .font(.subheadline)
                    }
                    
                    ProgressView(value: migrationManager.migrationProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                }
                
            case .completed:
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("迁移完成")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
                
            case .failed(let error):
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("迁移失败")
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                    
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("重试") {
                        Task {
                            await migrationManager.performAutoMigration()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                
            default:
                EmptyView()
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private var authActionsSection: some View {
        VStack(spacing: 16) {
            Button(action: {
                Task {
                    await initializeAsNewUser()
                }
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("作为新用户开始")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(authManager.authStatus == .authenticating)
            
            Button(action: {
                showingUserUUIDInput = true
            }) {
                HStack {
                    Image(systemName: "link.circle.fill")
                    Text("绑定到现有账户")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(authManager.authStatus == .authenticating)
            
            if authManager.authStatus == .tokenExpired {
                Button(action: {
                    Task {
                        await refreshToken()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise.circle.fill")
                        Text("刷新认证")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private var userInfoSection: some View {
        VStack(spacing: 16) {
            if let user = authManager.currentUser {
                UserInfoCard(user: user)
            }
            
            HStack {
                Button("登出") {
                    Task {
                        await authManager.logout()
                    }
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                if let userUUID = authManager.currentUser?.id {
                    Button("复制用户ID") {
                        #if canImport(AppKit)
                        NSPasteboard.general.setString(userUUID, forType: .string)
                        #endif
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func checkInitialState() {
        // 检查是否需要迁移
        if migrationManager.migrationStatus == .required {
            showingMigrationAlert = true
        }
    }
    
    private func initializeAsNewUser() async {
        do {
            _ = try await authManager.initializeDevice()
        } catch {
            authError = error.localizedDescription
        }
    }
    
    private func bindToUser(_ userUUID: String) async {
        do {
            _ = try await authManager.bindToUser(userUUID: userUUID)
            showingUserUUIDInput = false
        } catch {
            authError = error.localizedDescription
        }
    }
    
    private func refreshToken() async {
        do {
            try await authManager.refreshToken()
        } catch {
            authError = error.localizedDescription
        }
    }
}

// MARK: - Supporting Views

struct StatusCard: View {
    let icon: String
    let title: String
    let message: String
    let color: Color
    var isAnimated: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .rotationEffect(.degrees(isAnimated ? 360 : 0))
                .animation(isAnimated ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isAnimated)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(color)
                
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct UserInfoCard: View {
    let user: User
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.name ?? "用户")
                        .font(.headline)
                    
                    Text("用户ID：\(user.id)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
                
                Spacer()
            }
            
            if let email = user.email {
                Text("邮箱：\(email)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("创建时间：\(formatDate(user.createdAt))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

struct UserUUIDInputView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var userUUID: String = ""
    let onSubmit: (String) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("绑定到现有账户")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("请输入您的用户UUID")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            TextField("用户UUID", text: $userUUID)
                .textFieldStyle(.roundedBorder)
                .font(.monospaced(.body)())
            
            HStack {
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("绑定") {
                    onSubmit(userUUID)
                }
                .buttonStyle(.borderedProminent)
                .disabled(userUUID.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }
}
