#!/bin/bash

# 检查应用图标脚本
# 验证应用图标是否正确配置和显示

APP_PATH="/Users/hewro/Library/Developer/Xcode/DerivedData/PomodoroTimer-bmuykvdpmsswvxfxkvszshtiscsy/Build/Products/Debug/PomodoroTimer.app"

echo "🔍 检查应用图标配置..."
echo ""

# 检查应用包是否存在
if [ ! -d "$APP_PATH" ]; then
    echo "❌ 应用包不存在: $APP_PATH"
    echo "请先构建应用"
    exit 1
fi

echo "✅ 应用包存在: $APP_PATH"

# 检查 Info.plist 中的图标配置
echo ""
echo "📋 Info.plist 图标配置:"
plutil -p "$APP_PATH/Contents/Info.plist" | grep -E "(CFBundleIcon|Icon)" || echo "未找到图标配置"

# 检查 Resources 目录中的图标文件
echo ""
echo "📁 Resources 目录中的图标文件:"
ls -la "$APP_PATH/Contents/Resources/" | grep -E "\.(icns|png)$" || echo "未找到图标文件"

# 检查 AppIcon.icns 文件详情
ICNS_FILE="$APP_PATH/Contents/Resources/AppIcon.icns"
if [ -f "$ICNS_FILE" ]; then
    echo ""
    echo "🖼️  AppIcon.icns 文件信息:"
    echo "文件大小: $(ls -lh "$ICNS_FILE" | awk '{print $5}')"
    echo "修改时间: $(ls -l "$ICNS_FILE" | awk '{print $6, $7, $8}')"
    
    # 使用 sips 查看图标信息
    echo ""
    echo "📐 图标文件详细信息:"
    sips -g all "$ICNS_FILE" 2>/dev/null | head -10
else
    echo "❌ AppIcon.icns 文件不存在"
fi

# 检查原始图标文件
echo ""
echo "🎨 原始图标文件:"
ICON_DIR="PomodoroTimer/Assets.xcassets/AppIcon.appiconset"
if [ -d "$ICON_DIR" ]; then
    echo "图标文件数量: $(ls "$ICON_DIR"/*.png 2>/dev/null | wc -l)"
    echo "最大图标尺寸: $(ls "$ICON_DIR"/*1024*.png 2>/dev/null | head -1)"
else
    echo "❌ 图标源文件目录不存在"
fi

echo ""
echo "🚀 启动应用以查看 Dock 图标..."
echo "请检查 Dock 栏中的应用图标是否显示为番茄图标"

# 启动应用
open "$APP_PATH"

echo ""
echo "✅ 图标检查完成！"
echo ""
echo "如果 Dock 中仍显示默认图标，请尝试："
echo "1. 完全退出应用"
echo "2. 清理构建缓存: xcodebuild clean"
echo "3. 重新构建应用"
echo "4. 重启 Dock: killall Dock"
