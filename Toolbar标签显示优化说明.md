# Toolbar 标签显示优化说明

## 🎯 优化目标

将 SettingsView 中的 toolbar item 从只显示图标改为同时显示图标和文本，提升用户体验和界面可读性。

## 🔧 实现的修改

### 1. 替换 Picker 为自定义按钮组

**修改前**：
```swift
ToolbarItem(placement: .principal) {
    Picker("", selection: $selectedTab) {
        Label("计时", systemImage: "timer").tag(0)
        Label("活动", systemImage: "chart.bar").tag(1)
        Label("关于", systemImage: "info.circle").tag(2)
    }
    .pickerStyle(.segmented)
    .frame(maxWidth: 300)
    .frame(width: 210)
}
```

**修改后**：
```swift
ToolbarItem(placement: .principal) {
    HStack(spacing: 0) {
        SettingsTabButton(
            title: "计时",
            icon: "timer",
            isSelected: selectedTab == 0
        ) {
            selectedTab = 0
        }
        
        SettingsTabButton(
            title: "活动",
            icon: "chart.bar",
            isSelected: selectedTab == 1
        ) {
            selectedTab = 1
        }
        
        SettingsTabButton(
            title: "关于",
            icon: "info.circle",
            isSelected: selectedTab == 2
        ) {
            selectedTab = 2
        }
    }
    .background(
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.secondary.opacity(0.1))
    )
}
```

### 2. 优化 SettingsTabButton 组件

**修改前的垂直布局**：
```swift
VStack(spacing: 4) {
    Image(systemName: icon)
        .font(.system(size: 16, weight: .medium))
    Text(title)
        .font(.system(size: 11, weight: .medium))
}
.frame(width: 60, height: 50)
```

**修改后的水平布局**：
```swift
HStack(spacing: 6) {
    Image(systemName: icon)
        .font(.system(size: 14, weight: .medium))
    Text(title)
        .font(.system(size: 13, weight: .medium))
}
.padding(.horizontal, 12)
.padding(.vertical, 6)
```

## ✨ 优化效果

### 🎨 视觉改进

| 方面 | 修改前 | 修改后 |
|------|--------|--------|
| **显示内容** | 仅图标 | 图标 + 文本 |
| **布局方式** | 垂直堆叠 | 水平排列 |
| **尺寸** | 固定 60x50 | 自适应内容 |
| **可读性** | 需要记忆图标含义 | 直观显示功能名称 |

### 🔍 用户体验提升

**修改前的问题**：
- ❌ 用户需要记住每个图标代表的功能
- ❌ 新用户不容易理解图标含义
- ❌ 在小屏幕上图标可能不够清晰

**修改后的优势**：
- ✅ 图标和文字双重信息，更直观
- ✅ 新用户可以快速理解功能
- ✅ 提升界面的专业性和可用性
- ✅ 保持了原有的交互逻辑

### 🎯 设计细节优化

**间距和尺寸**：
- 图标和文字间距：6px
- 按钮内边距：水平12px，垂直6px
- 图标尺寸：14pt（适合与文字搭配）
- 文字尺寸：13pt（保持清晰可读）

**颜色和状态**：
- 选中状态：使用主题色（accentColor）
- 未选中状态：使用次要色（secondary）
- 背景高亮：选中时显示15%透明度的主题色背景
- 整体背景：10%透明度的次要色背景

**交互反馈**：
- 保持原有的点击切换逻辑
- 视觉状态清晰区分选中/未选中
- 平滑的颜色过渡效果

## 🔧 技术实现要点

### 自定义按钮组件
- 使用 `HStack` 实现图标和文字的水平布局
- 通过 `isSelected` 参数控制视觉状态
- 使用 `PlainButtonStyle()` 避免默认按钮样式干扰

### 布局适配
- 使用 `spacing: 0` 让按钮紧密排列
- 通过背景色统一整个按钮组的视觉效果
- 自适应内容宽度，避免固定尺寸限制

### 状态管理
- 保持原有的 `selectedTab` 状态管理逻辑
- 每个按钮独立处理点击事件
- 通过闭包传递选择操作

## 📱 兼容性考虑

- **macOS 原生风格**：符合 macOS 应用的设计规范
- **响应式设计**：自适应不同窗口尺寸
- **可访问性**：文字标签提升可访问性支持
- **主题适配**：自动适应浅色/深色主题

## ✅ 验证结果

- [x] 编译成功，无错误无警告
- [x] 保持原有功能完整性
- [x] 视觉效果符合设计预期
- [x] 交互逻辑正常工作
- [x] 提升用户体验和可用性

这次优化成功地将 toolbar 中的标签从纯图标显示改为图标+文字的组合显示，大大提升了界面的可读性和用户友好性，同时保持了原有的功能和交互逻辑。
