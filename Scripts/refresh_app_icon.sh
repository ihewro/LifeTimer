#!/bin/bash

# 刷新应用程序图标的脚本
# 解决 macOS 图标缓存问题

echo "=== 刷新应用程序图标 ==="

# 1. 停止正在运行的应用程序
echo "1. 停止正在运行的 LifeTimer..."
pkill -f "LifeTimer" 2>/dev/null
sleep 2

# 2. 清理 Xcode 构建缓存
echo "2. 清理 Xcode 构建缓存..."
if [ -d "/Users/hewro/Library/Developer/Xcode/DerivedData/LifeTimer-bmuykvdpmsswvxfxkvszshtiscsy" ]; then
    rm -rf "/Users/hewro/Library/Developer/Xcode/DerivedData/LifeTimer-bmuykvdpmsswvxfxkvszshtiscsy"
    echo "✓ 已清理 Xcode DerivedData"
else
    echo "- DerivedData 目录不存在"
fi

# 3. 重新构建应用程序
echo "3. 重新构建应用程序..."
xcodebuild -project LifeTimer.xcodeproj -scheme LifeTimer -configuration Debug clean build > /tmp/xcode_build.log 2>&1

if [ $? -eq 0 ]; then
    echo "✓ 应用程序构建成功"
else
    echo "✗ 应用程序构建失败，查看日志："
    tail -20 /tmp/xcode_build.log
    exit 1
fi

# 4. 清除系统图标缓存
echo "4. 清除系统图标缓存..."

# 清除 Launch Services 数据库
echo "- 重建 Launch Services 数据库..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user

# 清除图标缓存
echo "- 清除图标缓存..."
sudo rm -rfv /Library/Caches/com.apple.iconservices.store 2>/dev/null
rm -rfv ~/Library/Caches/com.apple.iconservices.store 2>/dev/null

# 重启 Dock 和 Finder
echo "- 重启 Dock..."
killall Dock

echo "- 重启 Finder..."
killall Finder

# 5. 等待系统服务重启
echo "5. 等待系统服务重启..."
sleep 3

# 6. 重新注册应用程序
echo "6. 重新注册应用程序..."
BUILD_APP_PATH="/Users/hewro/Library/Developer/Xcode/DerivedData/LifeTimer-bmuykvdpmsswvxfxkvszshtiscsy/Build/Products/Debug/LifeTimer.app"

if [ -d "$BUILD_APP_PATH" ]; then
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f -R -trusted "$BUILD_APP_PATH"
    echo "✓ 应用程序已重新注册"
else
    echo "✗ 找不到构建的应用程序"
    exit 1
fi

# 7. 验证图标文件
echo "7. 验证图标文件..."
if [ -f "$BUILD_APP_PATH/Contents/Resources/AppIcon.icns" ]; then
    echo "✓ 图标文件存在"
    echo "文件大小: $(ls -lh $BUILD_APP_PATH/Contents/Resources/AppIcon.icns | awk '{print $5}')"
    echo "修改时间: $(ls -l $BUILD_APP_PATH/Contents/Resources/AppIcon.icns | awk '{print $6, $7, $8}')"
else
    echo "✗ 图标文件不存在"
    exit 1
fi

echo ""
echo "=== 图标刷新完成 ==="
echo ""
echo "现在请尝试以下操作："
echo "1. 打开应用程序: open '$BUILD_APP_PATH'"
echo "2. 检查 Dock 中的图标"
echo "3. 检查 Finder 中的图标"
echo "4. 检查应用程序切换器 (Cmd+Tab) 中的图标"
echo ""
echo "如果图标仍然没有更新，请重启系统。"
