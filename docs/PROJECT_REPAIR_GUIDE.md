# 番茄钟项目修复指南

## 问题描述
项目文件 `PomodoroTimer.xcodeproj` 损坏，无法在 Xcode 中打开，出现解析错误。

## 已执行的修复操作

### 1. 项目文件修复
✅ **已完成** - 重新生成了完整的 `project.pbxproj` 文件
- 添加了所有缺失的 UUID 标识符
- 修复了文件引用和构建配置
- 确保了正确的 Xcode 项目文件格式

### 2. 工作区文件修复
✅ **已完成** - 修复了 `contents.xcworkspacedata` 文件
- 添加了正确的项目引用
- 确保了 XML 格式正确

### 3. 项目结构验证
✅ **已完成** - 验证了所有必要文件存在：
- ✅ PomodoroTimerApp.swift
- ✅ Views/ContentView.swift
- ✅ Views/TimerView.swift
- ✅ Views/CalendarView.swift
- ✅ Views/SettingsView.swift
- ✅ Models/TimerModel.swift
- ✅ Models/EventModel.swift
- ✅ Managers/AudioManager.swift
- ✅ Assets.xcassets
- ✅ PomodoroTimer.entitlements

## 如何打开项目

### 方法 1：使用 Finder
1. 打开 Finder
2. 导航到 `/Users/hewro/Documents/life/`
3. 双击 `PomodoroTimer.xcodeproj` 文件
4. Xcode 应该会自动打开项目

### 方法 2：使用 Xcode
1. 打开 Xcode
2. 选择 "File" > "Open"
3. 导航到项目文件夹并选择 `PomodoroTimer.xcodeproj`
4. 点击 "Open"

### 方法 3：使用终端（如果可用）
```bash
cd /Users/hewro/Documents/life
open PomodoroTimer.xcodeproj
```

## 编译和运行

### 1. 选择目标平台
- **macOS**: 选择 "My Mac" 作为目标
- **iOS**: 选择 iOS 模拟器（如 iPhone 15 Pro）
- **iPadOS**: 选择 iPad 模拟器

### 2. 编译项目
1. 按 `Cmd + B` 或点击 "Product" > "Build"
2. 检查是否有编译错误
3. 如有错误，请参考下面的故障排除部分

### 3. 运行应用
1. 按 `Cmd + R` 或点击运行按钮
2. 应用应该在选定的平台上启动

## 可能遇到的问题和解决方案

### 问题 1：Xcode 版本兼容性
**症状**: 编译错误，提示 Swift 版本不兼容
**解决方案**:
1. 确保使用 Xcode 15.0 或更高版本
2. 在项目设置中检查 Swift 版本设置
3. 如需要，更新 Swift 语法

### 问题 2：缺失开发者账户
**症状**: 代码签名错误
**解决方案**:
1. 在项目设置中将 "Development Team" 设置为你的 Apple ID
2. 或者选择 "Automatically manage signing"

### 问题 3：模拟器问题
**症状**: 应用无法在模拟器中运行
**解决方案**:
1. 重启 Xcode
2. 重置模拟器：Device > Erase All Content and Settings
3. 选择不同的模拟器设备

### 问题 4：权限问题
**症状**: 音频或文件访问权限错误
**解决方案**:
1. 检查 `PomodoroTimer.entitlements` 文件
2. 确保在系统设置中授予了必要权限

## 项目特性

### 核心功能
- 🍅 番茄钟计时器（25分钟工作，5分钟休息）
- 🎵 背景音乐播放
- 📅 日历事件管理
- 📊 统计和数据追踪
- ⚙️ 自定义设置

### 支持平台
- macOS 13.0+
- iOS 16.0+
- iPadOS 16.0+

### 技术栈
- SwiftUI
- Combine
- AVFoundation
- UserDefaults
- JSON 数据持久化

## 获取帮助

如果仍然遇到问题：

1. **检查 Xcode 控制台**: 查看详细的错误信息
2. **清理项目**: Product > Clean Build Folder
3. **重启 Xcode**: 完全退出并重新打开
4. **检查系统要求**: 确保 macOS 和 Xcode 版本兼容

## 文件清单

项目包含以下重要文件：
- `README.md` - 项目说明文档
- `QUICKSTART.md` - 快速开始指南
- `build.sh` - 自动化构建脚本
- `PROJECT_REPAIR_GUIDE.md` - 本修复指南

---

**修复完成时间**: $(date)
**修复状态**: ✅ 项目文件已修复，可以正常打开