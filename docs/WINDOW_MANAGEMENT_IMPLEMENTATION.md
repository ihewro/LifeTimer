# macOS SwiftUI 窗口管理最佳实践实现

## 实现时间
2025年7月27日

## 问题描述
在 macOS SwiftUI 应用中，当处理 `applicationShouldHandleReopen` 事件时，需要实现以下功能：

1. **主窗口识别和激活**：当应用有多个窗口时（包括主窗口和智能提醒窗口等辅助窗口），需要准确识别并激活或创建主窗口，而不是其他类型的窗口。

2. **替换当前的 Cmd+N 模拟方式**：当前代码使用 `NSEvent.keyEvent` 模拟 Cmd+N 按键的方式存在兼容性问题，在最新版本的 macOS 中会导致创建两个窗口且布局异常。

3. **使用 macOS SwiftUI 最佳实践**：需要采用更可靠的 SwiftUI 窗口管理方法，确保在不同 macOS 版本间的兼容性，避免重复窗口创建和布局问题。

4. **NotificationCenter Observer 生命周期问题**：原始实现在 ContentView 的 onAppear 中注册 observer，但没有在适当时机注销，导致：
   - 每次窗口重新显示时都会注册新的 observer
   - 多个 observer 同时监听同一通知，造成重复窗口创建
   - 内存泄漏和不可预测的行为

## 解决方案

### 1. 创建专用的 WindowManager 类

**文件**: `LifeTimer/Managers/WindowManager.swift`

**功能**:
- 统一管理主窗口的显示和创建逻辑
- 正确区分主窗口和辅助窗口（如智能提醒窗口）
- 使用 SwiftUI 的 `@Environment(\.openWindow)` 环境值创建新窗口
- 提供多种备用方案确保窗口创建的可靠性

**主要方法**:
- `showOrCreateMainWindow()`: 显示或创建主窗口的入口方法
- `findMainWindows()`: 查找所有主窗口（包括隐藏和最小化的）
- `showExistingMainWindow()`: 尝试显示现有的主窗口
- `createNewMainWindow()`: 创建新的主窗口

### 1.1 创建 WindowNotificationManager 类

**功能**:
- 解决 NotificationCenter observer 生命周期管理问题
- 确保通知监听器只注册一次，避免重复窗口创建
- 提供统一的通知清理机制

**主要方法**:
- `setupNotifications()`: 设置通知监听（只会执行一次）
- `cleanup()`: 清理通知监听器

### 2. 更新 App 结构

**修改**: `LifeTimer/LifeTimerApp.swift`

**变更**:
- 为 `WindowGroup` 添加了明确的标题和 ID：`WindowGroup("LifeTimer", id: "main")`
- 更新 `AppDelegate.applicationShouldHandleReopen` 方法使用 `WindowManager`
- 删除了旧的 Cmd+N 键盘事件模拟代码

### 3. 更新 ContentView 支持 openWindow

**修改**: `LifeTimer/Views/ContentView.swift`

**变更**:
- 添加 `@Environment(\.openWindow)` 环境值
- 添加 `setupNewWindowNotifications()` 方法监听窗口创建通知
- 通过通知系统连接 WindowManager 和 SwiftUI 的 openWindow 功能

### 4. 简化 MenuBarManager

**修改**: `LifeTimer/Managers/MenuBarManager.swift`

**变更**:
- 删除了复杂的窗口查找和创建逻辑
- 简化 `statusItemClicked()` 方法，直接使用 `WindowManager`
- 删除了所有旧的窗口管理辅助方法

## 技术特点

### 1. 符合 SwiftUI 最佳实践
- 使用 `@Environment(\.openWindow)` 而不是底层的 NSEvent 模拟
- 通过 WindowGroup ID 进行精确的窗口管理
- 利用 SwiftUI 的声明式窗口管理系统

### 2. 可靠的窗口识别
- 通过多重条件过滤准确识别主窗口：
  - `window.canBecomeMain` - 可以成为主窗口
  - 排除智能提醒窗口
  - 检查 AppKit 窗口类型

### 3. 多层备用方案
- 优先使用 SwiftUI 的 openWindow 环境值
- 备用方案包括 windowController.newWindowForTab 和菜单系统
- 确保在各种情况下都能成功创建窗口

### 4. 跨版本兼容性
- 避免了 NSEvent.keyEvent 在新版 macOS 中的兼容性问题
- 使用标准的 SwiftUI 窗口管理 API
- 提供了 iOS 平台的空实现确保跨平台兼容

## 使用方法

### 从 Dock 图标或菜单栏点击
```swift
// AppDelegate 中自动处理
func applicationShouldHandleReopen(_ app: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    let windowManager = WindowManager.shared
    if !windowManager.hasVisibleMainWindow {
        windowManager.showOrCreateMainWindow()
    }
    return true
}
```

### 从菜单栏管理器
```swift
@objc private func statusItemClicked() {
    NSApp.activate(ignoringOtherApps: true)
    let windowManager = WindowManager.shared
    windowManager.showOrCreateMainWindow()
}
```

## 优势

1. **消除了重复窗口问题**：不再使用可能导致多个窗口创建的键盘事件模拟
2. **提高了可靠性**：使用 SwiftUI 原生的窗口管理系统
3. **改善了用户体验**：窗口显示更加一致和可预测
4. **增强了可维护性**：集中的窗口管理逻辑，易于调试和修改
5. **确保了兼容性**：在不同 macOS 版本间表现一致

## 测试建议

1. **基本功能测试**：
   - 点击 Dock 图标时显示/创建主窗口
   - 点击菜单栏图标时显示/创建主窗口
   - 关闭窗口后重新打开

2. **边界情况测试**：
   - 窗口最小化后的恢复
   - 多个窗口存在时的正确识别
   - 智能提醒窗口存在时的主窗口管理

3. **兼容性测试**：
   - 在不同 macOS 版本上测试
   - 验证不会创建重复窗口
   - 确认窗口布局正常
