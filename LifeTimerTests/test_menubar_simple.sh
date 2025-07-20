#!/bin/bash

echo "🔍 测试菜单栏功能..."

# 检查应用是否在运行
if pgrep -f "PomodoroTimer" > /dev/null; then
    echo "✅ PomodoroTimer 应用正在运行"
    
    # 检查最近的日志中是否有菜单栏相关活动
    echo "📊 检查最近的菜单栏活动..."
    
    # 查看最近30秒的日志
    recent_logs=$(log show --predicate 'process == "PomodoroTimer"' --last 30s 2>/dev/null | grep -E "(trackMouse|sendAction|StatusBar)" | wc -l)
    
    if [ "$recent_logs" -gt 0 ]; then
        echo "✅ 检测到 $recent_logs 个菜单栏相关事件"
        echo "🎯 菜单栏功能正在工作！"
    else
        echo "ℹ️  最近30秒内没有检测到菜单栏活动"
        echo "💡 请尝试点击菜单栏中的计时器图标"
    fi
    
    # 检查菜单栏创建日志
    creation_log=$(log show --predicate 'process == "PomodoroTimer" AND eventMessage CONTAINS "Menu bar status item created successfully"' --last 5m 2>/dev/null | wc -l)
    
    if [ "$creation_log" -gt 0 ]; then
        echo "✅ 菜单栏状态项创建成功"
    else
        echo "⚠️  未找到菜单栏创建日志"
    fi
    
else
    echo "❌ PomodoroTimer 应用未运行"
    echo "💡 请先启动应用"
fi

echo ""
echo "📋 测试说明："
echo "1. 如果看到 '菜单栏功能正在工作'，说明点击功能正常"
echo "2. 在系统菜单栏右侧应该能看到计时器图标和时间"
echo "3. 点击该图标应该能激活应用窗口"
echo "4. 不需要任何特殊权限！"
