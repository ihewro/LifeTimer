# UI 设计指导原则

## 设计系统
- 遵循 Apple Human Interface Guidelines
- 支持浅色和深色模式
- 使用系统字体和颜色
- 保持跨平台一致性

## 布局原则
- 使用 SwiftUI 原生布局容器：VStack、HStack、ZStack
- 优先使用 Spacer() 而非固定间距
- 响应式设计，适配不同屏幕尺寸
- 合理使用 padding 和 margin

## 颜色规范
```swift
// 使用系统颜色确保深色模式兼容
.foregroundColor(.primary)
.backgroundColor(.systemBackground)
.accentColor(.blue)

// 自定义颜色需要在 Assets.xcassets 中定义
Color("CustomPrimary")
```

## 字体规范
- 标题：`.largeTitle`, `.title`, `.title2`
- 正文：`.body`, `.callout`
- 辅助文本：`.caption`, `.caption2`
- 使用动态字体支持辅助功能

## 动画指导
- 使用 SwiftUI 内置动画：`.animation(.easeInOut)`
- 保持动画时长适中（0.2-0.5秒）
- 为状态变化添加过渡动画
- 避免过度动画影响性能

## 交互设计
- 按钮点击提供视觉反馈
- 使用适当的点击区域大小（最小44pt）
- 支持键盘导航和 VoiceOver
- 提供加载状态指示器

## 组件复用
- 创建可复用的 View 组件
- 使用 ViewModifier 封装通用样式
- 参数化组件以提高灵活性