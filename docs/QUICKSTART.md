# LifeTimer 快速开始指南

本指南将帮助您快速上手 LifeTimer 应用的开发、构建和分发。

## 🚀 开发环境设置

### 1. 系统要求
- macOS 13.0 或更高版本
- Xcode 15.0 或更高版本
- Git

### 2. 打开项目
```bash
cd /Users/hewro/Documents/life
open LifeTimer.xcodeproj
```

### 3. 验证环境
```bash
# 检查资源文件
./Scripts/verify_resources.sh full

# 检查构建环境
xcodebuild -version
```

### 4. 选择目标设备
在 Xcode 中选择运行目标：
- **macOS**: "My Mac"
- **iOS**: "iPhone 15 Simulator" 或其他 iOS 模拟器
- **iPadOS**: "iPad Pro (12.9-inch)" 或其他 iPad 模拟器

### 5. 运行应用
- 按 `Cmd + R` 或点击播放按钮
- 首次运行可能需要几分钟编译时间

## 🔧 构建和运行

### 使用 Xcode
1. 在 Xcode 中选择目标设备
2. 按 `Cmd + R` 运行项目

### 使用命令行脚本
```bash
# 构建 macOS 版本
./Scripts/build.sh build-macos

# 构建并运行
./Scripts/build.sh test-macos

# 构建所有平台
./Scripts/build.sh build-all
```

## 📦 打包分发

### 快速打包
```bash
# 完整打包流程（推荐）
./Scripts/package.sh full
```

### 分步打包
```bash
# 1. 归档应用
./Scripts/package.sh archive

# 2. 导出应用
./Scripts/package.sh export

# 3. 创建安装包
./Scripts/package.sh dmg
./Scripts/package.sh zip
```

### 代码签名（可选）
```bash
# 配置签名信息
vim Scripts/sign.sh

# 执行签名和公证
./Scripts/sign.sh full
```

## 📁 构建产物

成功打包后，在 `build/` 目录中您将找到：

```
build/
├── LifeTimer.xcarchive          # Xcode 归档
├── export/LifeTimer.app         # 可执行应用
├── LifeTimer-1.0.dmg           # DMG 安装包
├── LifeTimer-1.0.zip           # ZIP 压缩包
├── RELEASE_NOTES.md            # 发布说明
└── resource_report.txt         # 资源报告
```

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
## 🎯 快速测试

### 1. 功能验证清单
```bash
# 运行应用
./Scripts/build.sh test-macos
```

验证以下功能：
- ✅ 计时器启动/暂停/重置
- ✅ 音乐播放/暂停/切换
- ✅ 事件添加/编辑/删除
- ✅ 设置保存和加载
- ✅ 菜单栏集成
- ✅ 通知显示

### 2. 资源验证
```bash
# 验证应用资源
./Scripts/verify_resources.sh full
```

### 3. 构建验证
```bash
# 验证所有平台构建
./Scripts/build.sh build-all
```

## 🔧 常用脚本

### 构建脚本 (`Scripts/build.sh`)
```bash
./Scripts/build.sh help           # 显示帮助
./Scripts/build.sh build-macos    # 构建 macOS 版本
./Scripts/build.sh clean          # 清理构建缓存
./Scripts/build.sh open           # 在 Xcode 中打开
```

### 打包脚本 (`Scripts/package.sh`)
```bash
./Scripts/package.sh help         # 显示帮助
./Scripts/package.sh full         # 完整打包流程
./Scripts/package.sh dmg          # 仅创建 DMG
./Scripts/package.sh clean        # 清理构建产物
```

### 签名脚本 (`Scripts/sign.sh`)
```bash
./Scripts/sign.sh help            # 显示帮助
./Scripts/sign.sh full            # 完整签名流程
./Scripts/sign.sh verify          # 验证签名
```

### 资源验证脚本 (`Scripts/verify_resources.sh`)
```bash
./Scripts/verify_resources.sh help    # 显示帮助
./Scripts/verify_resources.sh full    # 完整验证
./Scripts/verify_resources.sh icons   # 仅验证图标
```

## 📚 文档资源

### 开发文档
- [README.md](../README.md) - 项目概述
- [DISTRIBUTION_GUIDE.md](./DISTRIBUTION_GUIDE.md) - 分发指南
- [CODE_SIGNING_GUIDE.md](./CODE_SIGNING_GUIDE.md) - 代码签名指南

### 用户文档
- [INSTALLATION_GUIDE.md](./INSTALLATION_GUIDE.md) - 安装指南

## ⚠️ 注意事项

### 开发注意事项
- 确保 Xcode 版本兼容
- 定期验证资源文件完整性
- 测试不同 macOS 版本的兼容性

### 分发注意事项
- 外部分发需要代码签名
- 建议进行公证以提高用户信任
- 提供清晰的安装说明

## 🆘 故障排除

### 构建失败
1. 检查 Xcode 版本
2. 清理构建缓存：`./Scripts/build.sh clean`
3. 重新打开项目

### 资源问题
1. 运行资源验证：`./Scripts/verify_resources.sh full`
2. 检查图标文件完整性
3. 验证权限配置

### 签名问题
1. 检查开发者证书
2. 验证 Team ID 配置
3. 确认网络连接（公证时）

## 📞 获取帮助

- **文档**: 查看 `docs/` 目录中的详细文档
- **脚本帮助**: 运行任何脚本加 `help` 参数
- **问题报告**: 通过 GitHub Issues 报告问题

---

**开始您的 LifeTimer 开发之旅！🍅**
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