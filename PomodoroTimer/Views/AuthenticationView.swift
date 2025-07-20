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
    @StateObject private var syncManager: SyncManager
    @State private var userUUID: String = ""
    @State private var showingUserUUIDInput = false
    @State private var authError: String?
    @State private var serverURL: String = ""
    @State private var showingServerConfig = false
    @Environment(\.dismiss) private var dismiss

    init(authManager: AuthManager, syncManager: SyncManager) {
        self._authManager = StateObject(wrappedValue: authManager)
        self._syncManager = StateObject(wrappedValue: syncManager)
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // 顶部工具栏
            topToolbarSection

            // 标题区域
            headerSection

            // 服务器配置区域
            serverConfigSection

            // 认证状态显示
            authStatusSection

            // 认证操作区域
            if !authManager.isAuthenticated {
                authActionsSection
            } else {
                userInfoSection
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: 500, minHeight: 600) // 确保最小高度，保证关闭按钮可见
        .onAppear {
            loadServerURL()
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
            UserUUIDInputView(authManager: authManager) {
                showingUserUUIDInput = false
            }
        }

    }
    
    // MARK: - View Components

    private var topToolbarSection: some View {
        HStack {
            Spacer()

            Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("关闭")
        }
    }

    private var serverConfigSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "server.rack")
                    .foregroundColor(.blue)
                Text("服务器配置")
                    .font(.headline)
                Spacer()

                Image(systemName: showingServerConfig ? "chevron.up" : "chevron.down")
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle()) // 让整个HStack区域都可以点击
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showingServerConfig.toggle()
                }
            }
            .help("点击展开或收起服务器配置")

            if showingServerConfig {
                VStack(spacing: 8) {
                    HStack {
                        Text("服务器地址:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }

                    HStack {
                        TextField("", text: $serverURL)
                            .textFieldStyle(.roundedBorder)
                            .font(.monospaced(.body)())

                        Button("保存") {
                            saveServerURL()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(serverURL.isEmpty)
                    }

                    Text("请输入同步服务器的完整地址，例如：http://192.168.1.100:8080")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color.systemBackground)
        .cornerRadius(8)
    }

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
    

    
    private var authActionsSection: some View {
        VStack(spacing: 16) {
            // 主要登录选项
            VStack(spacing: 8) {
                Button(action: {
                    Task {
                        await initializeDevice()
                    }
                }) {
                    HStack {
                        Image(systemName: "iphone.and.arrow.forward")
                        Text("使用此设备登录")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(authManager.authStatus == .authenticating)

                Text("首次使用将创建新账户，已注册设备将自动登录")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // 分隔线
            HStack {
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.secondary.opacity(0.3))
                Text("或")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.secondary.opacity(0.3))
            }

            // 绑定选项
            VStack(spacing: 8) {
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

                Text("如果您在其他设备上已有账户，可以输入用户ID进行绑定")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
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
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(userUUID, forType: .string)
                        #endif
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
    
    // MARK: - Actions
    

    
    private func initializeDevice() async {
        do {
            _ = try await authManager.initializeDevice()
        } catch {
            authError = error.localizedDescription
        }
    }
    
    private func bindToUser(_ userUUID: String) async {
        do {
            _ = try await authManager.bindToUser(userUUID: userUUID)
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

    // MARK: - Server Configuration Methods

    private func loadServerURL() {
        // 从 UserDefaults 加载服务器地址
        let savedURL = UserDefaults.standard.string(forKey: "ServerURL") ?? "http://localhost:8080"
        serverURL = savedURL
    }

    private func saveServerURL() {
        // 验证URL格式
        guard !serverURL.isEmpty else { return }

        // 确保URL格式正确
        var urlToSave = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !urlToSave.hasPrefix("http://") && !urlToSave.hasPrefix("https://") {
            urlToSave = "http://" + urlToSave
        }

        // 移除末尾的斜杠
        if urlToSave.hasSuffix("/") {
            urlToSave = String(urlToSave.dropLast())
        }

        // 保存到 UserDefaults
        UserDefaults.standard.set(urlToSave, forKey: "ServerURL")
        serverURL = urlToSave

        // 更新 SyncManager 的服务器地址（这会同时更新 AuthManager）
        syncManager.updateServerURL(urlToSave)

        // 收起配置面板
        showingServerConfig = false

        print("✅ 服务器地址已保存: \(urlToSave)")
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
        .background(Color.systemBackground)
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
    @State private var isBinding: Bool = false
    @State private var bindingError: String?

    let authManager: AuthManager
    let onSuccess: () -> Void

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
                .disabled(isBinding)

            // 错误信息显示
            if let error = bindingError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            HStack {
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .disabled(isBinding)

                Spacer()

                Button(isBinding ? "绑定中..." : "绑定") {
                    Task {
                        await performBinding()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(userUUID.isEmpty || isBinding)
            }

            // 加载指示器
            if isBinding {
                ProgressView()
                    .scaleEffect(0.8)
                    .padding(.top, 8)
            }
        }
        .padding()
        .frame(width: 400)
    }

    private func performBinding() async {
        // 清除之前的错误信息
        bindingError = nil
        isBinding = true

        do {
            _ = try await authManager.bindToUser(userUUID: userUUID)
            // 绑定成功，关闭视图
            await MainActor.run {
                onSuccess()
            }
        } catch {
            // 绑定失败，显示错误信息但保持视图打开
            await MainActor.run {
                bindingError = error.localizedDescription
                isBinding = false
            }
        }
    }
}
