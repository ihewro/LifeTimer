#!/bin/bash

# 最终修复应用图标脚本
# 执行所有必要的步骤来确保应用图标正确显示

echo "🔧 最终修复应用图标..."
echo ""

# 1. 清理图标缓存
echo "1️⃣ 清理图标缓存..."
sudo rm -rf /Library/Caches/com.apple.iconservices.store
rm -rf ~/Library/Caches/com.apple.iconservices.store

# 2. 重启图标服务
echo "2️⃣ 重启图标服务..."
sudo killall -HUP iconservicesd
sudo killall -HUP iconservicesagent

# 3. 清理 Launch Services 数据库
echo "3️⃣ 清理 Launch Services 数据库..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user

# 4. 重新注册应用
echo "4️⃣ 重新注册应用..."
APP_PATH="/Users/hewro/Library/Developer/Xcode/DerivedData/PomodoroTimer-bmuykvdpmsswvxfxkvszshtiscsy/Build/Products/Debug/PomodoroTimer.app"
if [ -d "$APP_PATH" ]; then
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f -R -trusted "$APP_PATH"
    echo "✅ 应用重新注册完成"
else
    echo "❌ 应用路径不存在，请先构建应用"
fi

# 5. 重启 Dock
echo "5️⃣ 重启 Dock..."
killall Dock

# 6. 等待服务重启
echo "6️⃣ 等待服务重启..."
sleep 3

echo ""
echo "✅ 图标修复完成！"
echo ""
echo "📝 验证步骤："
echo "1. 检查 Dock 中的应用图标是否为番茄图标"
echo "2. 如果仍然不正确，请重启系统"
echo "3. 或者尝试从 Finder 中启动应用"
echo ""

# 7. 启动应用进行最终验证
echo "🚀 启动应用进行验证..."
if [ -d "$APP_PATH" ]; then
    open "$APP_PATH"
    echo "应用已启动，请检查 Dock 图标"
else
    echo "请先构建应用"
fi

echo ""
echo "🎯 如果问题仍然存在，可能的原因："
echo "- macOS 系统缓存需要更长时间更新"
echo "- 需要重启系统以完全清理缓存"
echo "- 应用签名问题（开发版本通常没有问题）"
