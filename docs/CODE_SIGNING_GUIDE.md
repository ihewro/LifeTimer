# LifeTimer 代码签名配置指南

本文档详细说明了如何为 LifeTimer 应用配置代码签名，以便进行分发。

## 📋 概述

代码签名是 macOS 应用分发的重要环节，它确保：
- 应用的完整性和真实性
- 用户可以安全地运行应用
- 应用可以通过 macOS 的安全检查

## 🔧 签名类型

### 1. 开发签名 (Development)
- 用于开发和测试
- 只能在开发者的设备上运行
- 不需要公证

### 2. 分发签名 (Distribution)
- 用于外部分发
- 需要 Apple Developer Program 会员资格
- 需要公证才能在其他设备上运行

## 🛠️ 配置步骤

### 步骤 1: 获取开发者证书

#### 选项 A: Apple Developer Program（推荐）
1. 注册 [Apple Developer Program](https://developer.apple.com/programs/)
2. 在 Keychain Access 中生成证书签名请求 (CSR)
3. 在 Apple Developer 网站上创建证书
4. 下载并安装证书

#### 选项 B: 自签名证书（仅用于本地分发）
```bash
# 创建自签名证书
security create-keypair -a RSA -s 2048 -f "LifeTimer Developer"
```

### 步骤 2: 配置项目签名设置

在 Xcode 中：
1. 选择项目 → LifeTimer target
2. 进入 "Signing & Capabilities" 标签页
3. 配置以下设置：

```
Team: [选择你的开发团队]
Bundle Identifier: com.yourcompany.LifeTimer
Signing Certificate: [选择合适的证书]
```

### 步骤 3: 更新项目配置

编辑 `LifeTimer.xcodeproj/project.pbxproj`：

```xml
CODE_SIGN_IDENTITY = "Developer ID Application: Your Name (TEAM_ID)";
CODE_SIGN_STYLE = Manual;
DEVELOPMENT_TEAM = YOUR_TEAM_ID;
PRODUCT_BUNDLE_IDENTIFIER = com.yourcompany.LifeTimer;
```

## 📝 权限配置

当前应用需要以下权限（已在 `LifeTimer.entitlements` 中配置）：

```xml
<!-- 文件访问权限 -->
<key>com.apple.security.files.user-selected.read-write</key>
<true/>

<!-- 网络访问权限 -->
<key>com.apple.security.network.client</key>
<true/>

<!-- 音频输入权限 -->
<key>com.apple.security.device.audio-input</key>
<true/>

<!-- Apple Events 权限 -->
<key>com.apple.security.automation.apple-events</key>
<true/>
```

## 🔒 公证流程

对于外部分发，需要进行公证：

### 1. 上传应用进行公证
```bash
# 创建应用的 ZIP 包
ditto -c -k --keepParent "LifeTimer.app" "LifeTimer.zip"

# 上传进行公证
xcrun notarytool submit "LifeTimer.zip" \
    --apple-id "your-apple-id@example.com" \
    --password "app-specific-password" \
    --team-id "YOUR_TEAM_ID" \
    --wait
```

### 2. 装订公证票据
```bash
# 装订公证票据到应用
xcrun stapler staple "LifeTimer.app"

# 验证装订结果
xcrun stapler validate "LifeTimer.app"
```

## 🚀 自动化签名脚本

创建自动化签名脚本 `Scripts/sign.sh`：

```bash
#!/bin/bash

# 配置变量
DEVELOPER_ID="Developer ID Application: Your Name (TEAM_ID)"
APP_PATH="./build/export/LifeTimer.app"

# 签名应用
codesign --force --options runtime --deep --sign "$DEVELOPER_ID" "$APP_PATH"

# 验证签名
codesign --verify --verbose "$APP_PATH"
```

## 🔍 验证签名

### 验证代码签名
```bash
# 验证签名有效性
codesign --verify --verbose LifeTimer.app

# 显示签名信息
codesign --display --verbose=4 LifeTimer.app

# 检查权限
codesign --display --entitlements - LifeTimer.app
```

### 验证公证状态
```bash
# 检查公证状态
spctl --assess --verbose LifeTimer.app

# 检查 Gatekeeper 状态
spctl --assess --type exec LifeTimer.app
```

## ⚠️ 常见问题

### 问题 1: "开发者无法验证" 错误
**解决方案**:
1. 确保应用已正确签名
2. 对于外部分发，确保已完成公证
3. 用户可以在系统偏好设置中手动允许

### 问题 2: 权限被拒绝
**解决方案**:
1. 检查 entitlements 文件配置
2. 确保签名时包含了权限文件
3. 重新签名应用

### 问题 3: 公证失败
**解决方案**:
1. 检查应用是否使用了 Hardened Runtime
2. 确保所有依赖库都已正确签名
3. 检查权限配置是否正确

## 📚 相关资源

- [Apple Developer Documentation](https://developer.apple.com/documentation/security)
- [Code Signing Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/)
- [Notarizing macOS Software](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)

## 🔄 更新签名配置

当需要更新签名配置时：

1. 更新证书（如果过期）
2. 修改项目配置文件
3. 重新构建和签名应用
4. 重新进行公证（如果需要）

---

**注意**: 代码签名配置可能因具体需求而异。请根据实际情况调整配置。
