# NotificationCenter Observer 生命周期问题修复

## 实现时间
2025年7月27日

## 问题分析

### 原始问题
在 `ContentView.swift` 中的 `setupNewWindowNotifications()` 方法存在严重的生命周期管理问题：

```swift
// 问题代码 - 在 ContentView.onAppear 中
private func setupNewWindowNotifications() {
    NotificationCenter.default.addObserver(
        forName: .init("CreateNewMainWindow"),
        object: nil,
        queue: .main
    ) { _ in
        openWindow(id: WindowManager.mainWindowID)
    }
}
```

### 问题现象
1. **重复窗口创建**：关闭窗口后再次打开会创建两个窗口
2. **累积效应**：多次关闭重开后会创建更多窗口
3. **内存泄漏**：observer 从未被移除

### 根本原因
- 每次 `ContentView.onAppear` 被调用时都会注册新的 observer
- 没有对应的 `removeObserver` 调用
- 多个 observer 同时监听同一个通知，导致多次调用 `openWindow`

## 解决方案

### 方案选择：App 级别管理（已采用）

将 observer 管理移到 App 级别，使用专门的 `WindowNotificationManager` 单例类：

#### 1. 创建 WindowNotificationManager

```swift
class WindowNotificationManager {
    static let shared = WindowNotificationManager()
    
    private var newWindowObserver: NSObjectProtocol?
    private var isSetup = false
    
    /// 设置通知监听（只会执行一次）
    func setupNotifications(_ openWindow: @escaping (String) -> Void) {
        guard !isSetup else {
            NSLog("WindowNotificationManager: Notifications already setup, skipping")
            return
        }
        
        newWindowObserver = NotificationCenter.default.addObserver(
            forName: .init("CreateNewMainWindow"),
            object: nil,
            queue: .main
        ) { _ in
            NSLog("WindowNotificationManager: Received CreateNewMainWindow notification")
            openWindow(WindowManager.mainWindowID)
        }
        
        isSetup = true
    }
    
    /// 清理通知监听器
    func cleanup() {
        if let observer = newWindowObserver {
            NotificationCenter.default.removeObserver(observer)
            newWindowObserver = nil
        }
        isSetup = false
    }
}
```

#### 2. 在 App 级别注册

```swift
// LifeTimerApp.swift
private func setupNewWindowNotifications() {
    WindowNotificationManager.shared.setupNotifications { windowId in
        openWindow(id: windowId)
    }
}
```

#### 3. 从 ContentView 移除重复代码

完全移除了 ContentView 中的 observer 注册代码，避免重复注册。

## 技术优势

### 1. 单次注册保证
- 使用 `isSetup` 标志确保 observer 只注册一次
- 防止重复注册导致的多窗口问题

### 2. 生命周期管理
- 在 App 级别管理，生命周期更稳定
- 提供 `cleanup()` 方法用于资源清理

### 3. 调试友好
- 添加详细的日志输出
- 便于追踪 observer 的注册和调用

### 4. 跨平台兼容
- 提供 iOS 版本的空实现
- 确保代码在不同平台间的一致性

## 测试验证

### 测试场景
1. **基本功能**：
   - 点击 Dock 图标创建/显示窗口
   - 点击菜单栏图标创建/显示窗口

2. **重复操作测试**：
   - 关闭窗口后重新打开（应该只创建一个窗口）
   - 多次重复关闭/打开操作
   - 验证不会出现重复窗口

3. **内存测试**：
   - 长时间运行应用
   - 多次窗口操作
   - 验证内存使用稳定

### 预期结果
- ✅ 每次操作只创建一个窗口
- ✅ 不会出现重复窗口问题
- ✅ 内存使用稳定，无泄漏
- ✅ 日志输出清晰，便于调试

## 其他可选方案

### 方案二：ContentView 级别管理（未采用）
在 ContentView 中使用 `@State` 变量和 `onDisappear` 来管理 observer：

```swift
@State private var windowObserver: NSObjectProtocol?

.onAppear {
    if windowObserver == nil {
        setupNewWindowNotifications()
    }
}
.onDisappear {
    if let observer = windowObserver {
        NotificationCenter.default.removeObserver(observer)
        windowObserver = nil
    }
}
```

**未采用原因**：
- ContentView 的生命周期不够稳定
- 在某些情况下 `onDisappear` 可能不被调用
- App 级别管理更可靠

### 方案三：使用 Combine（未采用）
使用 Combine 的 `NotificationCenter.Publisher`：

```swift
private var cancellables = Set<AnyCancellable>()

NotificationCenter.default
    .publisher(for: .init("CreateNewMainWindow"))
    .sink { _ in
        openWindow(id: WindowManager.mainWindowID)
    }
    .store(in: &cancellables)
```

**未采用原因**：
- 增加了额外的依赖
- 对于简单的通知监听来说过于复杂
- 当前方案已经足够简洁有效

## 总结

通过将 NotificationCenter observer 管理移到 App 级别，并使用专门的单例管理器，我们成功解决了：

1. **重复窗口创建问题**
2. **内存泄漏问题**
3. **生命周期管理问题**

这个修复确保了窗口管理的可靠性和一致性，为用户提供了更好的体验。
