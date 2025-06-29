# 番茄钟应用 (PomodoroTimer)

一个基于 SwiftUI 开发的跨平台番茄钟应用，支持 iOS、iPadOS 和 macOS。

## 功能特性

### 🍅 核心功能
- **多种计时模式**：单次番茄、纯休息、正计时
- **可自定义时间**：支持设置番茄时间、短休息、长休息时长
- **优雅的界面设计**：圆形进度条、现代化 UI
- **跨平台支持**：一套代码，支持 iPhone、iPad、Mac

### 🎵 音频功能
- **背景音乐播放**：支持选择本地音乐文件夹
- **音乐格式支持**：MP3、M4A、WAV、AAC、FLAC
- **播放控制**：播放/暂停、上一首/下一首、音量调节
- **循环播放**：自动循环播放选中的音乐

### 📅 日历管理
- **日视图**：以时间轴形式显示当天所有事件
- **事件管理**：添加、编辑、删除专注事件
- **事件类型**：番茄时间、短休息、长休息、自定义
- **完成状态**：标记事件完成状态
- **当前时间指示器**：实时显示当前时间位置

### 📊 统计功能
- **今日统计**：完成番茄数、专注时间、平均时长
- **历史记录**：查看过往的专注记录
- **周统计**：本周完成情况概览

## 项目结构

```
PomodoroTimer/
├── PomodoroTimerApp.swift          # 应用入口
├── Models/
│   ├── TimerModel.swift            # 计时器数据模型
│   └── EventModel.swift            # 事件数据模型
├── Views/
│   ├── ContentView.swift           # 主界面
│   ├── TimerView.swift             # 计时器界面
│   ├── CalendarView.swift          # 日历界面
│   └── SettingsView.swift          # 设置界面
├── Managers/
│   └── AudioManager.swift          # 音频管理器
├── Assets.xcassets/                # 资源文件
├── Preview Content/                # 预览资源
└── PomodoroTimer.entitlements      # 应用权限配置
```

## 技术架构

### 开发框架
- **SwiftUI**：现代化的声明式 UI 框架
- **Combine**：响应式编程框架
- **AVFoundation**：音频播放框架
- **Foundation**：基础数据处理

### 设计模式
- **MVVM**：Model-View-ViewModel 架构
- **ObservableObject**：数据绑定和状态管理
- **Environment Objects**：跨视图数据共享

### 数据持久化
- **UserDefaults**：用户设置和偏好存储
- **JSON 编码/解码**：事件数据序列化

## 编译和运行

### 系统要求
- **开发环境**：Xcode 15.0 或更高版本
- **macOS**：macOS 13.0 或更高版本
- **iOS**：iOS 16.0 或更高版本
- **iPadOS**：iPadOS 16.0 或更高版本

### 编译步骤

1. **打开项目**
   ```bash
   cd /Users/hewro/Documents/life
   open PomodoroTimer.xcodeproj
   ```

2. **选择目标平台**
   - 在 Xcode 中选择目标设备（iPhone、iPad 或 Mac）
   - 确保选择了正确的 Scheme

3. **编译运行**
   - 按 `Cmd + R` 编译并运行
   - 或者点击 Xcode 工具栏中的播放按钮

### 命令行编译

```bash
# 编译 macOS 版本
xcodebuild -project PomodoroTimer.xcodeproj -scheme PomodoroTimer -destination 'platform=macOS' build

# 编译 iOS 版本
xcodebuild -project PomodoroTimer.xcodeproj -scheme PomodoroTimer -destination 'platform=iOS Simulator,name=iPhone 15' build

# 编译 iPadOS 版本
xcodebuild -project PomodoroTimer.xcodeproj -scheme PomodoroTimer -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)' build
```

## 使用说明

### 基本使用

1. **启动计时器**
   - 选择计时模式（单次番茄/纯休息/正计时）
   - 点击中央的播放按钮开始计时
   - 可随时暂停或重置计时器

2. **设置背景音乐**
   - 进入设置页面
   - 点击「选择」按钮选择音乐文件夹
   - 在音乐列表中选择要播放的音乐

3. **管理日程**
   - 切换到日历标签页
   - 查看当天的专注事件
   - 点击「+」按钮添加新事件

4. **查看统计**
   - 在设置页面查看今日统计
   - 点击「查看详细统计」了解更多数据

### 高级功能

#### 自定义时间设置
- 番茄时间：1-120 分钟（默认 25 分钟）
- 短休息：1-120 分钟（默认 5 分钟）
- 长休息：1-120 分钟（默认 15 分钟）

#### 音频控制
- 支持的格式：MP3、M4A、WAV、AAC、FLAC
- 音量调节：0-100%
- 自动循环播放
- 播放列表管理

#### 事件管理
- 事件类型：番茄时间、短休息、长休息、自定义
- 时间设置：精确到分钟
- 完成状态：手动标记完成
- 删除功能：支持删除不需要的事件

## 开发指南

### 添加新功能

1. **创建新的 View**
   ```swift
   struct NewFeatureView: View {
       var body: some View {
           // 实现界面
       }
   }
   ```

2. **扩展数据模型**
   ```swift
   class NewDataModel: ObservableObject {
       @Published var property: Type
       // 添加新属性和方法
   }
   ```

3. **集成到主界面**
   - 在 `ContentView` 中添加新的标签页
   - 或在现有界面中添加导航链接

### 自定义主题

应用使用系统颜色，自动支持深色模式。如需自定义主题：

1. 在 `Assets.xcassets` 中添加颜色资源
2. 创建颜色扩展：
   ```swift
   extension Color {
       static let customPrimary = Color("CustomPrimary")
   }
   ```

### 本地化支持

1. 创建 `Localizable.strings` 文件
2. 使用 `NSLocalizedString` 替换硬编码文本
3. 在项目设置中添加支持的语言

## 故障排除

### 常见问题

1. **音频无法播放**
   - 检查文件格式是否支持
   - 确认文件路径是否正确
   - 检查系统音量设置

2. **计时器不准确**
   - 确保应用在前台运行
   - 检查系统时间设置
   - 重启应用重新校准

3. **数据丢失**
   - 数据存储在 UserDefaults 中
   - 卸载应用会清除所有数据
   - 建议定期导出重要数据

### 调试技巧

1. **使用 Xcode 调试器**
   - 设置断点查看变量值
   - 使用 `po` 命令打印对象

2. **日志输出**
   ```swift
   print("Debug info: \(variable)")
   ```

3. **模拟器测试**
   - 测试不同设备尺寸
   - 验证深色模式适配
   - 检查性能表现

## 版本历史

### v1.0.0 (当前版本)
- ✅ 基础计时功能
- ✅ 多种计时模式
- ✅ 背景音乐播放
- ✅ 日历事件管理
- ✅ 统计功能
- ✅ 跨平台支持

### 计划功能
- 🔄 通知提醒
- 🔄 数据导出
- 🔄 云同步
- 🔄 小组件支持
- 🔄 Apple Watch 支持

## 贡献指南

欢迎提交 Issue 和 Pull Request！

1. Fork 项目
2. 创建功能分支
3. 提交更改
4. 推送到分支
5. 创建 Pull Request

## 许可证

本项目采用 MIT 许可证。详见 LICENSE 文件。

## 联系方式

- 邮箱：feedback@example.com
- 项目地址：https://github.com/yourname/PomodoroTimer

---

**享受专注时光！🍅**