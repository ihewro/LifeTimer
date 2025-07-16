# 架构模式指导

## MVVM 架构实现

### Model 层
- 纯数据结构，实现 `Codable` 协议用于序列化
- 包含业务逻辑验证方法
- 不依赖 UI 框架
- 示例：`TimerEvent`, `PomodoroSession`

### ViewModel 层
- 继承 `ObservableObject` 协议
- 使用 `@Published` 属性包装器标记状态变化
- 处理用户交互逻辑
- 管理 Model 数据的生命周期
- 示例：`TimerModel`, `EventManager`

### View 层
- 纯 SwiftUI 声明式 UI
- 通过 `@EnvironmentObject` 访问共享状态
- 最小化业务逻辑，专注于 UI 呈现
- 使用 Binding 进行双向数据绑定

## 依赖注入模式
```swift
// 在 App 入口统一创建和注入依赖
@StateObject private var timerModel = TimerModel()
@StateObject private var audioManager = AudioManager()

// 通过 environmentObject 传递给子视图
ContentView()
    .environmentObject(timerModel)
    .environmentObject(audioManager)
```

## 状态管理原则
- 单一数据源 (Single Source of Truth)
- 状态提升到最近的共同父组件
- 使用 `@State` 管理本地状态
- 使用 `@StateObject` 创建数据模型实例
- 使用 `@ObservedObject` 接收外部传入的数据模型

## 数据流向
1. 用户交互 → View
2. View → ViewModel (通过方法调用)
3. ViewModel → Model (更新数据)
4. Model → ViewModel (通过 @Published 通知)
5. ViewModel → View (自动 UI 更新)

## 模块化设计
- 按功能划分模块：Timer、Audio、Calendar、Sync
- 每个模块包含：Model、ViewModel、View
- 模块间通过协议进行通信
- 避免循环依赖