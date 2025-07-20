# 应用图标设置功能测试指南

## 功能概述
已成功实现在设置页面中调整软件图标的功能，用户可以：
1. 选择自定义应用图标
2. 重置为默认图标
3. 查看当前使用的图标状态

## 实现的功能

### 1. AppIconManager 管理器
- 位置：`LifeTimer/Managers/AppIconManager.swift`
- 功能：
  - 选择新的应用图标 (`selectIcon()`)
  - 设置应用图标 (`setIcon(from:)`)
  - 重置为默认图标 (`resetToDefault()`)
  - 自动调整图片大小为 512x512
  - 持久化保存用户选择

### 2. 设置页面集成
- 位置：`LifeTimer/Views/SettingsView.swift`
- 在"智能提醒"设置后添加了"应用图标"设置区域
- 显示当前图标状态
- 提供"选择图标"和"重置默认"按钮

### 3. 应用启动时自动恢复
- 在 `LifeTimerApp.swift` 中初始化 AppIconManager
- 应用启动时自动恢复用户之前选择的图标

## 测试步骤

### 1. 启动应用
```bash
open /Users/hewro/Library/Developer/Xcode/DerivedData/LifeTimer-edpyukjptcjkqadxkohdyrvnnpkl/Build/Products/Debug/LifeTimer.app
```

### 2. 进入设置页面
- 点击左侧边栏的"设置"选项
- 滚动到"应用图标"设置区域

### 3. 测试选择自定义图标
- 点击"选择图标"按钮
- 在文件选择对话框中选择一个图片文件（支持 PNG、JPEG、TIFF、BMP）
- 观察 Dock 中的应用图标是否立即更新

### 4. 测试重置默认图标
- 在选择了自定义图标后，点击"重置默认"按钮
- 应用图标应该恢复为默认图标（`/Users/hewro/Desktop/rounded_image2.png`）

### 5. 测试持久化
- 选择一个自定义图标
- 完全退出应用
- 重新启动应用
- 验证自定义图标是否被保持

## 默认图标
- 路径：`/Users/hewro/Desktop/rounded_image2.png`
- 如果默认图标文件不存在，将使用应用包中的原始图标

## 技术细节

### 图标处理
- 自动将选择的图片调整为 512x512 像素
- 使用 `NSApplication.shared.applicationIconImage` 设置图标
- 支持常见的图片格式

### 数据持久化
- 使用 UserDefaults 保存当前图标路径
- 键名：`CurrentAppIconPath`

### 跨平台兼容性
- 使用 `#if canImport(Cocoa)` 确保只在 macOS 上编译相关代码
- iOS 版本提供空实现

## 已知限制
1. 图标更改只影响当前运行的应用实例
2. 系统可能需要几秒钟来更新 Dock 中的图标
3. 某些系统缓存可能需要重启 Dock 才能完全更新

## 故障排除
如果图标没有立即更新：
1. 等待几秒钟让系统处理
2. 重启 Dock：`killall Dock`
3. 重启应用程序
4. 检查选择的图片文件是否有效

## 成功指标
✅ 编译成功  
✅ 应用启动正常  
✅ 设置页面显示应用图标选项  
✅ 可以选择自定义图标  
✅ 可以重置为默认图标  
✅ 图标选择状态持久化保存  
✅ 应用重启后恢复用户选择的图标
