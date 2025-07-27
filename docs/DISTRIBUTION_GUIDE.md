# LifeTimer 应用分发指南

本文档详细说明了如何构建、打包和分发 LifeTimer 应用。

## 📋 概述

LifeTimer 是一个基于 SwiftUI 开发的跨平台番茄钟应用，支持 macOS、iOS 和 iPadOS。本指南将帮助您完成从源码到可分发应用的完整流程。

## 🔧 系统要求

### 开发环境
- **macOS**: 13.0 或更高版本
- **Xcode**: 15.0 或更高版本
- **命令行工具**: Xcode Command Line Tools

### 目标平台
- **macOS**: 13.0 或更高版本
- **iOS**: 16.0 或更高版本
- **iPadOS**: 16.0 或更高版本

## 🚀 快速开始

### 1. 克隆项目
```bash
git clone <repository-url>
cd LifeTimer
```

### 2. 验证环境
```bash
# 检查 Xcode 是否安装
xcodebuild -version

# 验证项目资源
./Scripts/verify_resources.sh full
```

### 3. 构建应用
```bash
# 构建 macOS 版本
./Scripts/build.sh build-macos

# 或构建所有平台
./Scripts/build.sh build-all
```

### 4. 打包分发
```bash
# 完整打包流程
./Scripts/package.sh full
```

## 📦 打包流程详解

### 步骤 1: 准备构建环境

使用内置脚本验证环境：
```bash
./Scripts/verify_resources.sh full
```

这将检查：
- ✅ 应用图标完整性
- ✅ 图标尺寸正确性
- ✅ 图标格式有效性
- ✅ 其他资源文件

### 步骤 2: 构建应用

#### 选项 A: 使用构建脚本
```bash
# 构建 macOS 版本
./Scripts/build.sh build-macos

# 构建并测试
./Scripts/build.sh test-macos
```

#### 选项 B: 使用 Xcode
1. 打开 `LifeTimer.xcodeproj`
2. 选择目标平台
3. 按 `Cmd + B` 构建

### 步骤 3: 归档和导出

#### 使用打包脚本（推荐）
```bash
# 完整打包流程
./Scripts/package.sh full

# 或分步执行
./Scripts/package.sh archive    # 归档
./Scripts/package.sh export     # 导出
./Scripts/package.sh dmg        # 创建 DMG
./Scripts/package.sh zip        # 创建 ZIP
```

#### 手动操作
1. 在 Xcode 中选择 Product → Archive
2. 在 Organizer 中选择 Distribute App
3. 选择导出方式（Developer ID 或 Mac App Store）

### 步骤 4: 代码签名（可选）

如果需要分发给外部用户：

```bash
# 配置签名脚本中的证书信息
vim Scripts/sign.sh

# 执行签名
./Scripts/sign.sh full
```

## 📁 构建产物

成功打包后，您将在 `build/` 目录中找到：

```
build/
├── LifeTimer.xcarchive          # Xcode 归档文件
├── export/
│   └── LifeTimer.app           # 导出的应用
├── LifeTimer-1.0.dmg           # DMG 安装包
├── LifeTimer-1.0.zip           # ZIP 压缩包
├── RELEASE_NOTES.md            # 发布说明
└── resource_report.txt         # 资源验证报告
```

## 🔒 代码签名配置

### 开发者证书

1. **注册 Apple Developer Program**
   - 访问 [Apple Developer](https://developer.apple.com)
   - 注册开发者账户（$99/年）

2. **创建证书**
   - 在 Keychain Access 中生成 CSR
   - 在开发者网站创建 Developer ID Application 证书
   - 下载并安装证书

3. **配置项目**
   ```bash
   # 编辑签名脚本
   vim Scripts/sign.sh
   
   # 设置以下变量：
   DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAM_ID)"
   APPLE_ID="your-apple-id@example.com"
   APP_SPECIFIC_PASSWORD="your-app-specific-password"
   TEAM_ID="YOUR_TEAM_ID"
   ```

### 公证流程

对于外部分发，需要进行公证：

```bash
# 自动公证（包含在签名脚本中）
./Scripts/sign.sh full

# 手动公证
xcrun notarytool submit LifeTimer.zip \
    --apple-id "your-apple-id@example.com" \
    --password "app-specific-password" \
    --team-id "YOUR_TEAM_ID" \
    --wait
```

## 📋 分发清单

在分发前，请确保完成以下检查：

### ✅ 构建检查
- [ ] 应用成功构建
- [ ] 所有目标平台测试通过
- [ ] 资源文件验证通过
- [ ] 版本号正确设置

### ✅ 签名检查
- [ ] 代码签名有效
- [ ] 公证完成（如需要）
- [ ] Gatekeeper 验证通过

### ✅ 功能检查
- [ ] 核心功能正常
- [ ] 权限请求正常
- [ ] 菜单栏集成正常
- [ ] 音频播放正常

### ✅ 分发包检查
- [ ] DMG 安装包正常
- [ ] ZIP 压缩包完整
- [ ] 发布说明准确
- [ ] 安装说明清晰

## 🚀 分发方式

### 1. 直接分发
- 通过网站提供下载链接
- 发送给特定用户
- 内部测试分发

### 2. Mac App Store
- 需要 Mac App Store 证书
- 遵循 App Store 审核指南
- 使用 App Store Connect 上传

### 3. 第三方平台
- GitHub Releases
- 其他软件分发平台

## ⚠️ 注意事项

### 安全提示
- 始终使用有效的开发者证书
- 对外部分发的应用进行公证
- 定期更新证书

### 兼容性
- 测试不同 macOS 版本的兼容性
- 验证 Intel 和 Apple Silicon 兼容性
- 确保权限配置正确

### 用户体验
- 提供清晰的安装说明
- 包含系统要求信息
- 准备常见问题解答

## 🔧 故障排除

### 构建失败
1. 检查 Xcode 版本
2. 清理构建缓存：`./Scripts/build.sh clean`
3. 验证项目配置

### 签名失败
1. 检查证书有效性
2. 验证 Team ID 配置
3. 确认权限文件正确

### 公证失败
1. 检查网络连接
2. 验证 Apple ID 和密码
3. 确认应用使用 Hardened Runtime

## 📞 技术支持

如果在分发过程中遇到问题：

1. 查看构建日志
2. 检查系统要求
3. 参考 Apple 开发者文档
4. 联系技术支持

---

**祝您分发顺利！🚀**
