#!/bin/bash

# 快速检查图标显示状态的脚本

echo "🔍 快速图标检查工具"
echo "===================="

# 检查应用程序是否在运行
if pgrep -f "PomodoroTimer" > /dev/null; then
    echo "✅ PomodoroTimer 正在运行"
else
    echo "❌ PomodoroTimer 未运行，正在启动..."
    open '/Users/hewro/Library/Developer/Xcode/DerivedData/PomodoroTimer-bmuykvdpmsswvxfxkvszshtiscsy/Build/Products/Debug/PomodoroTimer.app'
    sleep 3
fi

echo ""
echo "📋 请手动检查以下位置的图标："
echo ""
echo "1. 🖥️  Dock 栏"
echo "   - 查看底部 Dock 栏中的 PomodoroTimer 图标"
echo "   - 应该显示新的图标样式"
echo ""
echo "2. 📁 Finder"
echo "   - 打开 Finder"
echo "   - 导航到应用程序文件夹"
echo "   - 查看 PomodoroTimer.app 的图标"
echo ""
echo "3. ⌘⇥ 应用程序切换器"
echo "   - 按住 Cmd+Tab 键"
echo "   - 查看 PomodoroTimer 的图标"
echo ""
echo "4. 🚀 Launchpad"
echo "   - 按 F4 键或点击 Launchpad"
echo "   - 查找 PomodoroTimer 图标"
echo ""

# 提供一些故障排除选项
echo "🛠️  如果图标仍然是旧的，请尝试："
echo ""
echo "选项 1: 重启 Dock"
read -p "是否要重启 Dock？(y/n): " restart_dock
if [[ $restart_dock =~ ^[Yy]$ ]]; then
    echo "正在重启 Dock..."
    killall Dock
    echo "✅ Dock 已重启"
fi

echo ""
echo "选项 2: 重新注册应用程序"
read -p "是否要重新注册应用程序？(y/n): " reregister_app
if [[ $reregister_app =~ ^[Yy]$ ]]; then
    echo "正在重新注册应用程序..."
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f -R -trusted '/Users/hewro/Library/Developer/Xcode/DerivedData/PomodoroTimer-bmuykvdpmsswvxfxkvszshtiscsy/Build/Products/Debug/PomodoroTimer.app'
    echo "✅ 应用程序已重新注册"
fi

echo ""
echo "选项 3: 清理更多缓存"
read -p "是否要清理更多系统缓存？(y/n): " clear_more_cache
if [[ $clear_more_cache =~ ^[Yy]$ ]]; then
    echo "正在清理更多缓存..."
    # 清理用户图标缓存
    rm -rf ~/Library/Caches/com.apple.iconservices.store 2>/dev/null
    # 清理 Launch Services 缓存
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user
    echo "✅ 缓存已清理"
fi

echo ""
echo "📝 注意事项："
echo "• macOS 可能需要几分钟来更新所有位置的图标"
echo "• 如果问题持续存在，重启系统通常能解决所有图标缓存问题"
echo "• 某些第三方应用可能会缓存图标更长时间"
echo ""
echo "🎉 图标更新流程完成！"
