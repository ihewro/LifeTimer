#!/bin/bash

echo "=== 调试编译问题 ==="
echo

# 设置项目路径
PROJECT_PATH="/Users/hewro/Documents/life/LifeTimer.xcodeproj"
SOURCE_DIR="/Users/hewro/Documents/life/LifeTimer"

echo "1. 检查项目文件结构..."
ls -la "$SOURCE_DIR"
echo

echo "2. 检查关键源文件..."
for file in "PomodoroTimerApp.swift" "Views/ContentView.swift" "Views/TimerView.swift" "Views/CalendarView.swift" "Views/SettingsView.swift" "Models/TimerModel.swift" "Models/EventModel.swift" "Managers/AudioManager.swift"; do
    if [ -f "$SOURCE_DIR/$file" ]; then
        echo "✅ $file 存在"
    else
        echo "❌ $file 缺失"
    fi
done
echo

echo "3. 尝试清理构建缓存..."
rm -rf ~/Library/Developer/Xcode/DerivedData/LifeTimer-*
echo "构建缓存已清理"
echo

echo "4. 尝试编译项目..."
cd /Users/hewro/Documents/life
xcodebuild -project "$PROJECT_PATH" -scheme LifeTimer -destination "platform=macOS" clean build 2>&1 | head -50
echo

echo "5. 检查语法错误..."
echo "检查 PomodoroTimerApp.swift:"
swiftc -typecheck "$SOURCE_DIR/PomodoroTimerApp.swift" 2>&1 || echo "语法检查失败"
echo

echo "检查 EventModel.swift:"
swiftc -typecheck "$SOURCE_DIR/Models/EventModel.swift" 2>&1 || echo "语法检查失败"
echo

echo "=== 调试完成 ==="
echo "如果仍有问题，请在 Xcode 中打开项目查看详细错误信息。"
echo "命令: open '$PROJECT_PATH'"