#!/bin/bash

# 检查应用图标是否已更新的脚本

echo "=== 检查应用图标更新状态 ==="

# 检查源图标文件
echo "1. 检查源图标文件:"
if [ -f "icons/icon.png" ]; then
    echo "✓ 源图标文件存在: icons/icon.png"
    file icons/icon.png
else
    echo "✗ 源图标文件不存在"
fi

echo ""

# 检查生成的图标文件
echo "2. 检查生成的图标文件:"
ICON_DIR="LifeTimer/Assets.xcassets/AppIcon.appiconset"
if [ -d "$ICON_DIR" ]; then
    echo "✓ 图标目录存在: $ICON_DIR"
    echo "图标文件数量: $(ls -1 $ICON_DIR/*.png 2>/dev/null | wc -l)"
    echo "最新生成时间: $(ls -lt $ICON_DIR/*.png 2>/dev/null | head -1 | awk '{print $6, $7, $8}')"
else
    echo "✗ 图标目录不存在"
fi

echo ""

# 检查构建产物中的图标
echo "3. 检查构建产物中的图标:"
BUILD_APP_PATH="/Users/hewro/Library/Developer/Xcode/DerivedData/LifeTimer-bmuykvdpmsswvxfxkvszshtiscsy/Build/Products/Debug/LifeTimer.app"
if [ -f "$BUILD_APP_PATH/Contents/Resources/AppIcon.icns" ]; then
    echo "✓ 构建产物中的图标文件存在"
    echo "文件大小: $(ls -lh $BUILD_APP_PATH/Contents/Resources/AppIcon.icns | awk '{print $5}')"
    echo "修改时间: $(ls -l $BUILD_APP_PATH/Contents/Resources/AppIcon.icns | awk '{print $6, $7, $8}')"
    file "$BUILD_APP_PATH/Contents/Resources/AppIcon.icns"
else
    echo "✗ 构建产物中的图标文件不存在"
fi

echo ""

# 检查应用程序是否在运行
echo "4. 检查应用程序运行状态:"
if pgrep -f "LifeTimer" > /dev/null; then
    echo "✓ LifeTimer 应用程序正在运行"
    echo "进程信息:"
    ps aux | grep LifeTimer | grep -v grep | head -2
else
    echo "✗ LifeTimer 应用程序未运行"
fi

echo ""

# 检查图标缓存是否已清理
echo "5. 检查图标缓存清理状态:"
if [ ! -d "/Library/Caches/com.apple.iconservices.store" ] || [ $(ls -1 /Library/Caches/com.apple.iconservices.store/ 2>/dev/null | wc -l) -lt 10 ]; then
    echo "✓ 系统图标缓存已清理"
else
    echo "- 系统图标缓存仍存在（正常，会自动重建）"
fi

echo ""
echo "=== 图标更新检查完成 ==="
echo ""
echo "✅ 图标刷新流程已完成！"
echo ""
echo "现在请检查以下位置的图标是否已更新："
echo "1. 🖥️  Dock 中的应用程序图标"
echo "2. 📁 Finder 中的应用程序图标"
echo "3. ⌘⇥ 应用程序切换器 (Cmd+Tab) 中的图标"
echo "4. 🚀 Launchpad 中的图标"
echo ""
echo "如果图标仍然显示为旧图标，请尝试："
echo "• 重启 Dock: killall Dock"
echo "• 重启系统"
echo "• 等待几分钟让系统重建缓存"
