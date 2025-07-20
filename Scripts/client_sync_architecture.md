# 客户端用户账户同步架构设计

## 1. 核心架构变更

### 1.1 认证管理器（新增）
```swift
class AuthManager: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: User?
    @Published var sessionToken: String?
    @Published var tokenExpiresAt: Date?
    
    // 设备首次启动认证
    func initializeDevice() async throws -> AuthResult
    
    // 绑定到现有用户
    func bindToUser(userUUID: String) async throws -> AuthResult
    
    // Token刷新
    func refreshToken() async throws
    
    // 登出
    func logout() async
}
```

### 1.2 SyncManager重构
```swift
class SyncManager: ObservableObject {
    // 移除deviceUUID，改用AuthManager
    private let authManager: AuthManager
    private let apiClient: APIClient
    
    // 认证状态变更处理
    @Published var syncStatus: SyncStatus = .notAuthenticated
    
    // 用户相关信息
    @Published var userInfo: UserInfo?
    @Published var userDevices: [UserDevice] = []
    
    init(authManager: AuthManager) {
        self.authManager = authManager
        self.apiClient = APIClient(authManager: authManager)
        
        // 监听认证状态变更
        setupAuthObserver()
    }
}
```

## 2. 数据模型调整

### 2.1 用户相关模型
```swift
struct User: Codable, Identifiable {
    let id: String // user_uuid
    let name: String?
    let email: String?
    let createdAt: Date
    let deviceCount: Int
}

struct UserDevice: Codable, Identifiable {
    let id: String // device_uuid
    let name: String
    let platform: String
    let lastSyncTimestamp: Int64
    let isCurrent: Bool
}

struct AuthResult: Codable {
    let userUUID: String
    let sessionToken: String
    let expiresAt: Date
    let isNewUser: Bool
    let userInfo: User?
}
```

### 2.2 API请求模型调整
```swift
// 移除所有deviceUUID参数，改用Authorization header
struct IncrementalSyncRequest: Codable {
    // 移除：let deviceUUID: String
    let lastSyncTimestamp: Int64
    let changes: SyncChanges
}

// API客户端自动添加认证头
class APIClient {
    private let authManager: AuthManager
    
    private func addAuthHeaders(to request: inout URLRequest) {
        if let token = authManager.sessionToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }
}
```

## 3. 认证流程实现

### 3.1 首次启动流程
```swift
// AppDelegate或主视图中
func initializeApp() async {
    do {
        if authManager.hasStoredCredentials() {
            // 尝试使用存储的token
            try await authManager.validateStoredToken()
        } else {
            // 首次启动，初始化设备
            try await authManager.initializeDevice()
        }
        
        // 认证成功后启动同步
        await syncManager.performInitialSync()
    } catch {
        // 处理认证失败
        showAuthenticationError(error)
    }
}
```

### 3.2 跨设备绑定流程
```swift
// 用户界面中输入用户UUID进行绑定
func bindToExistingUser(userUUID: String) async {
    do {
        let result = try await authManager.bindToUser(userUUID: userUUID)
        
        // 绑定成功，执行数据同步
        await syncManager.performFullSync()
        
        // 更新UI状态
        showBindingSuccess(result.userInfo)
    } catch {
        showBindingError(error)
    }
}
```

## 4. 同步逻辑调整

### 4.1 同步状态枚举
```swift
enum SyncStatus {
    case notAuthenticated
    case authenticating
    case authenticated
    case syncing
    case success
    case error(String)
    case tokenExpired
}
```

### 4.2 自动token刷新
```swift
extension APIClient {
    func performRequest<T>(_ request: URLRequest) async throws -> T {
        var mutableRequest = request
        addAuthHeaders(to: &mutableRequest)
        
        do {
            return try await executeRequest(mutableRequest)
        } catch APIError.unauthorized {
            // Token过期，尝试刷新
            try await authManager.refreshToken()
            addAuthHeaders(to: &mutableRequest)
            return try await executeRequest(mutableRequest)
        }
    }
}
```

## 5. 用户界面调整

### 5.1 认证界面
```swift
struct AuthenticationView: View {
    @StateObject private var authManager = AuthManager()
    @State private var userUUID: String = ""
    @State private var showingUserUUIDInput = false
    
    var body: some View {
        VStack(spacing: 20) {
            if authManager.isAuthenticated {
                // 已认证，显示用户信息
                UserProfileView(user: authManager.currentUser)
            } else {
                // 未认证，显示认证选项
                VStack {
                    Button("作为新用户开始") {
                        Task {
                            try await authManager.initializeDevice()
                        }
                    }
                    
                    Button("绑定到现有账户") {
                        showingUserUUIDInput = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingUserUUIDInput) {
            UserUUIDInputView { uuid in
                Task {
                    try await authManager.bindToUser(userUUID: uuid)
                }
            }
        }
    }
}
```

### 5.2 同步界面调整
```swift
struct SyncView: View {
    @StateObject private var syncManager: SyncManager
    @StateObject private var authManager: AuthManager
    
    var body: some View {
        VStack {
            // 用户信息区域
            if let user = authManager.currentUser {
                UserInfoSection(user: user)
            }
            
            // 设备管理区域
            DeviceManagementSection(devices: syncManager.userDevices)
            
            // 同步状态和操作
            SyncStatusSection(syncManager: syncManager)
            
            // 数据预览
            DataPreviewSection(syncManager: syncManager)
        }
    }
}
```

## 6. 数据持久化调整

### 6.1 认证信息存储
```swift
extension AuthManager {
    private let userUUIDKey = "UserUUID"
    private let sessionTokenKey = "SessionToken"
    private let tokenExpiresAtKey = "TokenExpiresAt"
    
    func saveCredentials() {
        userDefaults.set(currentUser?.id, forKey: userUUIDKey)
        userDefaults.set(sessionToken, forKey: sessionTokenKey)
        userDefaults.set(tokenExpiresAt, forKey: tokenExpiresAtKey)
    }
    
    func loadStoredCredentials() {
        // 从UserDefaults加载认证信息
    }
    
    func clearStoredCredentials() {
        userDefaults.removeObject(forKey: userUUIDKey)
        userDefaults.removeObject(forKey: sessionTokenKey)
        userDefaults.removeObject(forKey: tokenExpiresAtKey)
    }
}
```

### 6.2 同步时间戳调整
```swift
// 移除基于设备的同步时间戳，改为基于用户
extension SyncManager {
    private var lastSyncTimestampKey: String {
        guard let userUUID = authManager.currentUser?.id else {
            return "LastSyncTimestamp_Unknown"
        }
        return "LastSyncTimestamp_\(userUUID)"
    }
}
```

## 7. 错误处理和用户体验

### 7.1 认证错误处理
```swift
enum AuthError: LocalizedError {
    case deviceInitializationFailed
    case userBindingFailed
    case tokenRefreshFailed
    case invalidUserUUID
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
        case .networkError:
            return "网络连接错误"
        }
    }
}
```

### 7.2 用户引导
```swift
// 首次使用引导
struct OnboardingView: View {
    var body: some View {
        VStack {
            Text("欢迎使用番茄钟")
            Text("您的数据将自动同步到云端，并可在多个设备间共享")
            
            VStack {
                Text("您的用户ID：")
                Text(authManager.currentUser?.id ?? "")
                    .font(.monospaced(.body)())
                    .textSelection(.enabled)
                
                Text("请保存此ID，用于在其他设备上同步数据")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
```
