# 快速开始指南

## 🚀 立即开始

### 1. 打开项目
```bash
cd /Users/hewro/Documents/life
open LifeTimer.xcodeproj
```

### 2. 选择目标设备
在 Xcode 中选择运行目标：
- **macOS**: "My Mac"
- **iOS**: "iPhone 15 Simulator" 或其他 iOS 模拟器
- **iPadOS**: "iPad Pro (12.9-inch)" 或其他 iPad 模拟器

### 3. 运行应用
- 按 `Cmd + R` 或点击播放按钮
- 首次运行可能需要几分钟编译时间

## 📱 功能演示

### 计时器使用
1. 启动应用后，默认进入计时器界面
2. 点击左上角的模式选择器，可以切换：
   - 单次番茄（25分钟专注）
   - 纯休息（5分钟休息）
   - 正计时（无限计时）
3. 点击中央的蓝色播放按钮开始计时
4. 可随时暂停、重置或跳过

### 背景音乐设置
1. 切换到「设置」标签页
2. 在「音频设置」部分点击「选择」按钮
3. 选择包含音乐文件的文件夹
4. 返回计时器界面，点击音频控制按钮播放音乐

### 日历管理
1. 切换到「日历」标签页
2. 查看当天的时间轴视图
3. 点击右上角的「+」按钮添加新事件
4. 设置事件标题、时间和类型
¬
## 🛠️ 开发环境

### 系统要求
- macOS 13.0+
- Xcode 15.0+
- iOS 16.0+ / iPadOS 16.0+ (目标设备)

### 项目配置
- **语言**: Swift 5.0
- **框架**: SwiftUI + Combine
- **部署目标**: iOS 16.0, macOS 13.0
- **架构**: Universal (支持 Intel 和 Apple Silicon)

## 🎯 核心特性

### ✅ 已实现功能
- [x] 多种计时模式
- [x] 圆形进度条界面
- [x] 背景音乐播放
- [x] 日历事件管理
- [x] 统计数据显示
- [x] 跨平台支持
- [x] 深色模式适配
- [x] 数据持久化

### 🔄 计划功能
- [ ] 推送通知
- [ ] 小组件支持
- [ ] Apple Watch 应用
- [ ] 云同步功能
- [ ] 数据导出

## 📂 项目结构说明

```
LifeTimer/
├── 📱 PomodoroTimerApp.swift     # 应用入口点
├── 📊 Models/                    # 数据模型层
│   ├── TimerModel.swift          # 计时器逻辑
│   └── EventModel.swift          # 事件数据
├── 🎨 Views/                     # 用户界面层
│   ├── ContentView.swift         # 主界面容器
│   ├── TimerView.swift           # 计时器界面
│   ├── CalendarView.swift        # 日历界面
│   └── SettingsView.swift        # 设置界面
├── 🔧 Managers/                  # 业务逻辑层
│   └── AudioManager.swift        # 音频管理
└── 🎭 Assets.xcassets/           # 资源文件
```

## 🐛 常见问题

### Q: 编译失败怎么办？
A: 
1. 确保 Xcode 版本 ≥ 15.0
2. 清理构建缓存：`Product → Clean Build Folder`
3. 重启 Xcode 和模拟器

### Q: 音乐无法播放？
A:
1. 检查音乐文件格式（支持 MP3、M4A、WAV、AAC、FLAC）
2. 确认文件夹路径正确
3. 检查系统音量设置

### Q: 数据丢失了？
A:
1. 数据存储在 UserDefaults 中
2. 卸载应用会清除所有数据
3. 升级应用通常会保留数据

### Q: 界面显示异常？
A:
1. 检查设备方向设置
2. 尝试切换深色/浅色模式
3. 重启应用

## 📞 获取帮助

- 📖 查看完整文档：`README.md`
- 🐛 报告问题：创建 GitHub Issue
- 💡 功能建议：发送邮件至 feedback@example.com

---

**开始你的专注之旅！🍅**