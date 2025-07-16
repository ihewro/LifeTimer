# 番茄钟应用开发指导

## 项目概述
这是一个基于 SwiftUI 开发的跨平台番茄钟应用，支持 iOS、iPadOS 和 macOS。应用采用现代化的 MVVM 架构，集成了计时器、音频播放、日历管理和数据同步等功能。

## 核心架构
- **框架**: SwiftUI + Combine
- **架构模式**: MVVM (Model-View-ViewModel)
- **数据管理**: ObservableObject + @Published
- **音频处理**: AVFoundation
- **数据持久化**: UserDefaults + JSON 序列化
- **网络同步**: 自定义 HTTP 客户端

## 主要组件
1. **TimerModel**: 计时器核心逻辑
2. **AudioManager**: 背景音乐管理
3. **EventManager**: 日历事件管理
4. **SyncManager**: 数据同步管理
5. **AuthManager**: 用户认证系统
6. **MenuBarManager**: macOS 菜单栏集成

## 开发原则
- 保持代码简洁和可读性
- 遵循 SwiftUI 最佳实践
- 确保跨平台兼容性
- 优先考虑用户体验
- 维护数据一致性

## 技术栈
- Swift 5.0+
- SwiftUI (iOS 16.0+, macOS 13.0+)
- Combine 框架
- AVFoundation
- Foundation
- Network 框架