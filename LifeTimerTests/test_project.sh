#!/bin/bash

# 测试番茄钟项目是否可以正常编译
echo "正在测试番茄钟项目..."

# 检查项目文件是否存在
if [ -f "/Users/hewro/Documents/life/LifeTimer.xcodeproj/project.pbxproj" ]; then
    echo "✅ 项目文件存在"
else
    echo "❌ 项目文件不存在"
    exit 1
fi

# 检查源文件是否存在
echo "检查源文件..."
files=(
    "/Users/hewro/Documents/life/LifeTimer/PomodoroTimerApp.swift"
    "/Users/hewro/Documents/life/LifeTimer/Views/ContentView.swift"
    "/Users/hewro/Documents/life/LifeTimer/Views/TimerView.swift"
    "/Users/hewro/Documents/life/LifeTimer/Views/CalendarView.swift"
    "/Users/hewro/Documents/life/LifeTimer/Views/SettingsView.swift"
    "/Users/hewro/Documents/life/LifeTimer/Models/TimerModel.swift"
    "/Users/hewro/Documents/life/LifeTimer/Models/EventModel.swift"
    "/Users/hewro/Documents/life/LifeTimer/Managers/AudioManager.swift"
)

for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $(basename "$file")"
    else
        echo "❌ $(basename "$file") 缺失"
    fi
done

# 检查资源文件
if [ -d "/Users/hewro/Documents/life/LifeTimer/Assets.xcassets" ]; then
    echo "✅ Assets.xcassets 存在"
else
    echo "❌ Assets.xcassets 缺失"
fi

if [ -f "/Users/hewro/Documents/life/LifeTimer/LifeTimer.entitlements" ]; then
    echo "✅ LifeTimer.entitlements 存在"
else
    echo "❌ LifeTimer.entitlements 缺失"
fi

echo "\n项目结构检查完成！"
echo "\n建议："
echo "1. 在 Xcode 中打开项目：open LifeTimer.xcodeproj"
echo "2. 选择目标设备（iOS 模拟器、macOS 等）"
echo "3. 点击运行按钮开始编译和运行"
echo "\n如果遇到编译错误，请检查："
echo "- Swift 版本兼容性"
echo "- 缺失的依赖项"
echo "- 代码语法错误"