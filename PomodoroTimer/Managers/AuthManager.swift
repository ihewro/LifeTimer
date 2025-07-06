//
//  AuthManager.swift
//  PomodoroTimer
//
//  Created by Assistant on 2024
//

import Foundation
import Combine
#if canImport(Cocoa)
import Cocoa
#endif

/// 用户认证管理器
class AuthManager: ObservableObject {
    // MARK: - Published Properties
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: User?
    @Published var sessionToken: String?
    @Published var tokenExpiresAt: Date?
    @Published var authStatus: AuthStatus = .notAuthenticated
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let apiClient: APIClient
    
    // UserDefaults Keys
    private let userUUIDKey = "UserUUID"
    private let sessionTokenKey = "SessionToken"
    private let tokenExpiresAtKey = "TokenExpiresAt"
    private let deviceUUIDKey = "DeviceUUID"
    private let userInfoKey = "UserInfo"
    
    // Device Info
    private let deviceUUID: String
    
    // MARK: - Initialization
    init(serverURL: String) {
        // 获取或生成设备UUID
        if let existingUUID = userDefaults.string(forKey: deviceUUIDKey) {
            self.deviceUUID = existingUUID
        } else {
            self.deviceUUID = UUID().uuidString
            userDefaults.set(self.deviceUUID, forKey: deviceUUIDKey)
        }
        
        self.apiClient = APIClient(baseURL: serverURL)
        
        // 加载存储的认证信息
        loadStoredCredentials()
        
        // 如果有存储的token，验证其有效性
        if hasStoredCredentials() {
            Task {
                await validateStoredToken()
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// 设备首次启动认证
    func initializeDevice() async throws -> AuthResult {
        await MainActor.run {
            authStatus = .authenticating
        }

        do {
            let request = DeviceInitRequest(
                deviceUUID: deviceUUID,
                deviceName: getDeviceName(),
                platform: getPlatform()
            )

            let response = try await apiClient.deviceInit(request)

            let authResult = AuthResult(
                userUUID: response.data.userUUID,
                sessionToken: response.data.sessionToken,
                expiresAt: parseDate(response.data.expiresAt),
                isNewUser: response.data.isNewUser,
                userInfo: response.data.userInfo
            )

            await updateAuthState(with: authResult)
            return authResult

        } catch {
            await MainActor.run {
                authStatus = .error(error.localizedDescription)
            }
            throw error
        }
    }
    
    /// 绑定到现有用户
    func bindToUser(userUUID: String) async throws -> AuthResult {
        guard validateUUID(userUUID) else {
            throw AuthError.invalidUserUUID
        }

        await MainActor.run {
            authStatus = .authenticating
        }

        do {
            let request = DeviceBindRequest(
                userUUID: userUUID,
                deviceUUID: deviceUUID,
                deviceName: getDeviceName(),
                platform: getPlatform()
            )

            let response = try await apiClient.deviceBind(request)

            let authResult = AuthResult(
                userUUID: userUUID,
                sessionToken: response.data.sessionToken,
                expiresAt: parseDate(response.data.expiresAt),
                isNewUser: false,
                userInfo: response.data.userData
            )

            await updateAuthState(with: authResult)
            return authResult

        } catch {
            await MainActor.run {
                authStatus = .error(error.localizedDescription)
            }
            throw error
        }
    }
    
    /// Token刷新
    func refreshToken() async throws {
        guard let currentToken = sessionToken else {
            throw AuthError.noSessionToken
        }
        
        do {
            let response = try await apiClient.refreshToken(token: currentToken)
            
            await MainActor.run {
                self.sessionToken = response.data.sessionToken
                self.tokenExpiresAt = parseDate(response.data.expiresAt)
                saveCredentials()
            }
            
        } catch {
            await logout()
            throw AuthError.tokenRefreshFailed
        }
    }
    
    /// 登出
    func logout() async {
        if let token = sessionToken {
            try? await apiClient.logout(token: token)
        }
        
        await MainActor.run {
            clearAuthState()
        }
    }
    
    /// 检查是否有存储的凭据
    func hasStoredCredentials() -> Bool {
        return userDefaults.string(forKey: sessionTokenKey) != nil &&
               userDefaults.string(forKey: userUUIDKey) != nil
    }
    
    /// 验证存储的token
    func validateStoredToken() async {
        guard let token = sessionToken,
              let expiresAt = tokenExpiresAt else {
            await MainActor.run {
                authStatus = .notAuthenticated
            }
            return
        }
        
        // 检查token是否过期
        if expiresAt <= Date() {
            // Token过期，尝试刷新
            do {
                try await refreshToken()
                await MainActor.run {
                    authStatus = .authenticated
                }
            } catch {
                await MainActor.run {
                    clearAuthState()
                    authStatus = .tokenExpired
                }
            }
        } else {
            await MainActor.run {
                authStatus = .authenticated
            }
        }
    }
    
    // MARK: - Private Methods
    
    @MainActor
    func updateAuthState(with result: AuthResult) {
        self.currentUser = result.userInfo
        self.sessionToken = result.sessionToken
        self.tokenExpiresAt = result.expiresAt
        self.isAuthenticated = true
        self.authStatus = .authenticated

        saveCredentials()
    }
    
    @MainActor
    private func clearAuthState() {
        self.currentUser = nil
        self.sessionToken = nil
        self.tokenExpiresAt = nil
        self.isAuthenticated = false
        self.authStatus = .notAuthenticated
        
        clearStoredCredentials()
    }
    
    private func saveCredentials() {
        userDefaults.set(currentUser?.id, forKey: userUUIDKey)
        userDefaults.set(sessionToken, forKey: sessionTokenKey)
        userDefaults.set(tokenExpiresAt, forKey: tokenExpiresAtKey)
        
        if let userInfo = currentUser,
           let encoded = try? JSONEncoder().encode(userInfo) {
            userDefaults.set(encoded, forKey: userInfoKey)
        }
    }
    
    private func loadStoredCredentials() {
        sessionToken = userDefaults.string(forKey: sessionTokenKey)
        tokenExpiresAt = userDefaults.object(forKey: tokenExpiresAtKey) as? Date
        
        if let encoded = userDefaults.data(forKey: userInfoKey),
           let userInfo = try? JSONDecoder().decode(User.self, from: encoded) {
            currentUser = userInfo
            isAuthenticated = sessionToken != nil
        }
    }
    
    private func clearStoredCredentials() {
        userDefaults.removeObject(forKey: userUUIDKey)
        userDefaults.removeObject(forKey: sessionTokenKey)
        userDefaults.removeObject(forKey: tokenExpiresAtKey)
        userDefaults.removeObject(forKey: userInfoKey)
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
    
    private func validateUUID(_ uuid: String) -> Bool {
        let uuidRegex = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
        return NSPredicate(format: "SELF MATCHES %@", uuidRegex).evaluate(with: uuid)
    }
    
    private func parseDate(_ dateString: String) -> Date {
        let formatter = ISO8601DateFormatter()

        if let date = formatter.date(from: dateString) {
            print("✅ 成功解析时间: \(dateString) -> \(date)")
            return date
        } else {
            print("❌ 时间解析失败: \(dateString)")
            // 尝试其他格式
            let fallbackFormatter = DateFormatter()
            fallbackFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"

            if let fallbackDate = fallbackFormatter.date(from: dateString) {
                print("✅ 使用备用格式解析成功: \(dateString) -> \(fallbackDate)")
                return fallbackDate
            }

            print("❌ 所有格式解析失败，使用当前时间")
            return Date()
        }
    }
}

// MARK: - Supporting Types

/// 认证状态
enum AuthStatus: Equatable {
    case notAuthenticated
    case authenticating
    case authenticated
    case tokenExpired
    case error(String)

    static func == (lhs: AuthStatus, rhs: AuthStatus) -> Bool {
        switch (lhs, rhs) {
        case (.notAuthenticated, .notAuthenticated),
             (.authenticating, .authenticating),
             (.authenticated, .authenticated),
             (.tokenExpired, .tokenExpired):
            return true
        case (.error(let lhsMessage), .error(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}

/// 认证结果
struct AuthResult {
    let userUUID: String
    let sessionToken: String
    let expiresAt: Date
    let isNewUser: Bool
    let userInfo: User?
}

/// 认证错误
enum AuthError: LocalizedError {
    case deviceInitializationFailed
    case userBindingFailed
    case tokenRefreshFailed
    case invalidUserUUID
    case noSessionToken
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .deviceInitializationFailed:
            return "设备初始化失败，请检查网络连接"
        case .userBindingFailed:
            return "绑定用户失败，请检查用户UUID是否正确"
        case .tokenRefreshFailed:
            return "认证过期，请重新登录"
        case .invalidUserUUID:
            return "无效的用户UUID格式"
        case .noSessionToken:
            return "没有有效的会话令牌"
        case .networkError:
            return "网络连接错误"
        }
    }
}

/// 用户信息
struct User: Codable, Identifiable {
    let id: String // user_uuid
    let name: String?
    let email: String?
    let createdAt: String

    private enum CodingKeys: String, CodingKey {
        case id = "user_uuid"
        case name = "user_name"
        case email
        case createdAt = "created_at"
    }
}
