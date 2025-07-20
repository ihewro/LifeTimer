#!/bin/bash

# 应用图标设置功能演示脚本

echo "🎨 应用图标设置功能演示"
echo "=========================="
echo ""

# 检查应用是否已构建
APP_PATH="/Users/hewro/Library/Developer/Xcode/DerivedData/LifeTimer-edpyukjptcjkqadxkohdyrvnnpkl/Build/Products/Debug/LifeTimer.app"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ 应用未找到，请先构建应用"
    echo "运行: xcodebuild -project LifeTimer.xcodeproj -scheme LifeTimer -destination \"platform=macOS\" build"
    exit 1
fi

echo "✅ 应用已构建: $APP_PATH"
echo ""

# 检查默认图标文件
DEFAULT_ICON="/Users/hewro/Desktop/rounded_image2.png"
if [ -f "$DEFAULT_ICON" ]; then
    echo "✅ 默认图标文件存在: $DEFAULT_ICON"
    echo "文件大小: $(ls -lh "$DEFAULT_ICON" | awk '{print $5}')"
else
    echo "⚠️  默认图标文件不存在: $DEFAULT_ICON"
    echo "应用将使用内置图标作为默认图标"
fi
echo ""

# 启动应用
echo "🚀 启动应用..."
open "$APP_PATH"

# 等待应用启动
sleep 3

echo "📋 使用说明："
echo "1. 应用已启动，请查看 Dock 中的应用图标"
echo "2. 在应用中点击左侧边栏的'设置'选项"
echo "3. 滚动到'应用图标'设置区域"
echo "4. 点击'选择图标'按钮测试自定义图标功能"
echo "5. 选择一个图片文件（PNG、JPEG、TIFF、BMP）"
echo "6. 观察 Dock 中的图标是否立即更新"
echo "7. 点击'重置默认'按钮恢复默认图标"
echo ""

echo "🔍 功能特点："
echo "• 支持常见图片格式（PNG、JPEG、TIFF、BMP）"
echo "• 自动调整图片大小为 512x512 像素"
echo "• 实时更新 Dock 中的应用图标"
echo "• 持久化保存用户选择"
echo "• 应用重启后自动恢复用户选择的图标"
echo "• 显示当前使用的图标文件名"
echo ""

echo "✨ 测试建议："
echo "1. 尝试选择不同格式的图片文件"
echo "2. 测试大尺寸和小尺寸的图片"
echo "3. 验证重启应用后图标是否保持"
echo "4. 检查设置页面中的状态显示是否正确"
echo ""

echo "🎯 演示完成！请在应用中测试应用图标设置功能。"
