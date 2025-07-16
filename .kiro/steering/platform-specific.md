# 平台特定开发指导

## macOS 特性
- 菜单栏集成：使用 NSStatusBar 创建菜单栏应用
- 窗口管理：支持最小化到菜单栏，防止意外退出
- 键盘快捷键：实现全局快捷键支持
- 通知中心：使用 UserNotifications 框架

```swift
#if os(macOS)
import Cocoa

class MenuBarManager: ObservableObject {
    private var statusItem: NSStatusItem?
    
    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        // 配置菜单栏项目
    }
}
#endif
```

## iOS/iPadOS 特性
- 生命周期管理：处理应用进入后台和前台
- 多任务支持：iPad 分屏和滑动覆盖
- 触摸手势：支持滑动、捏合等手势
- 设备方向：适配横屏和竖屏

```swift
#if os(iOS)
import UIKit

// 处理应用生命周期
.onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
    // 应用进入前台时的处理
}
#endif
```

## 跨平台兼容性
- 使用编译条件区分平台代码
- 抽象平台特定功能到协议
- 统一的数据模型和业务逻辑
- 适配不同的输入方式（鼠标/触摸）

## 权限管理
```swift
// 音频播放权限
import AVFoundation

func requestAudioPermission() {
    AVAudioSession.sharedInstance().requestRecordPermission { granted in
        // 处理权限结果
    }
}

// 通知权限
import UserNotifications

func requestNotificationPermission() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
        // 处理权限结果
    }
}
```

## 性能优化
- macOS：优化内存使用，支持长时间运行
- iOS：优化电池消耗，处理内存警告
- 通用：使用 lazy loading 和数据缓存