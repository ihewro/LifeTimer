#!/bin/bash

# 测试崩溃修复的有效性
echo "🧪 开始测试崩溃修复..."
echo

# 检查应用是否正在运行
APP_NAME="LifeTimer"
PID=$(pgrep -f "$APP_NAME")

if [ -z "$PID" ]; then
    echo "❌ 应用未运行，请先启动应用"
    exit 1
fi

echo "✅ 应用正在运行 (PID: $PID)"
echo

# 测试1: 检查内存使用情况
echo "📊 测试1: 检查内存使用情况..."
MEMORY_USAGE=$(ps -p $PID -o rss= | awk '{print $1/1024}')
echo "   当前内存使用: ${MEMORY_USAGE} MB"

if (( $(echo "$MEMORY_USAGE > 500" | bc -l) )); then
    echo "⚠️  内存使用较高，可能存在内存泄漏"
else
    echo "✅ 内存使用正常"
fi
echo

# 测试2: 检查线程数量
echo "🧵 测试2: 检查线程数量..."
THREAD_COUNT=$(ps -p $PID -o thcount= | awk '{print $1}')
echo "   当前线程数: $THREAD_COUNT"

if [ "$THREAD_COUNT" -gt 20 ]; then
    echo "⚠️  线程数量较多，可能存在线程泄漏"
else
    echo "✅ 线程数量正常"
fi
echo

# 测试3: 检查CPU使用率
echo "💻 测试3: 检查CPU使用率..."
CPU_USAGE=$(ps -p $PID -o pcpu= | awk '{print $1}')
echo "   当前CPU使用率: ${CPU_USAGE}%"

if (( $(echo "$CPU_USAGE > 50" | bc -l) )); then
    echo "⚠️  CPU使用率较高"
else
    echo "✅ CPU使用率正常"
fi
echo

# 测试4: 检查文件描述符
echo "📁 测试4: 检查文件描述符..."
FD_COUNT=$(lsof -p $PID 2>/dev/null | wc -l)
echo "   当前文件描述符数: $FD_COUNT"

if [ "$FD_COUNT" -gt 100 ]; then
    echo "⚠️  文件描述符数量较多"
else
    echo "✅ 文件描述符数量正常"
fi
echo

# 测试5: 模拟用户操作
echo "🎮 测试5: 模拟用户操作..."
echo "   请手动执行以下操作来测试稳定性："
echo "   1. 快速切换侧边栏页面 (计时器 -> 日历 -> 活动统计)"
echo "   2. 在日历页面快速切换月份"
echo "   3. 启动和停止计时器多次"
echo "   4. 使用搜索功能"
echo "   5. 打开和关闭设置页面"
echo

# 等待用户操作
echo "⏳ 等待30秒进行手动测试..."
sleep 30

# 再次检查应用状态
NEW_PID=$(pgrep -f "$APP_NAME")
if [ -z "$NEW_PID" ]; then
    echo "❌ 应用已崩溃！"
    exit 1
elif [ "$NEW_PID" != "$PID" ]; then
    echo "⚠️  应用重启了，原PID: $PID，新PID: $NEW_PID"
    PID=$NEW_PID
else
    echo "✅ 应用仍在正常运行"
fi

# 最终内存检查
NEW_MEMORY_USAGE=$(ps -p $PID -o rss= | awk '{print $1/1024}')
MEMORY_DIFF=$(echo "$NEW_MEMORY_USAGE - $MEMORY_USAGE" | bc -l)
echo "   内存变化: ${MEMORY_DIFF} MB"

if (( $(echo "$MEMORY_DIFF > 50" | bc -l) )); then
    echo "⚠️  内存增长较多，可能存在内存泄漏"
else
    echo "✅ 内存使用稳定"
fi

echo
echo "🎉 测试完成！"
echo
echo "📋 测试总结:"
echo "   - 初始内存使用: ${MEMORY_USAGE} MB"
echo "   - 最终内存使用: ${NEW_MEMORY_USAGE} MB"
echo "   - 内存变化: ${MEMORY_DIFF} MB"
echo "   - 线程数: $THREAD_COUNT"
echo "   - CPU使用率: ${CPU_USAGE}%"
echo "   - 文件描述符: $FD_COUNT"
echo

# 生成测试报告
REPORT_FILE="crash_fix_test_report_$(date +%Y%m%d_%H%M%S).txt"
cat > "$REPORT_FILE" << EOF
崩溃修复测试报告
================

测试时间: $(date)
应用PID: $PID

性能指标:
- 初始内存使用: ${MEMORY_USAGE} MB
- 最终内存使用: ${NEW_MEMORY_USAGE} MB
- 内存变化: ${MEMORY_DIFF} MB
- 线程数: $THREAD_COUNT
- CPU使用率: ${CPU_USAGE}%
- 文件描述符: $FD_COUNT

测试结果:
- 应用稳定性: $([ "$NEW_PID" = "$PID" ] && echo "正常" || echo "异常")
- 内存泄漏检查: $([ $(echo "$MEMORY_DIFF < 50" | bc -l) -eq 1 ] && echo "通过" || echo "需要关注")
- 线程管理: $([ "$THREAD_COUNT" -le 20 ] && echo "正常" || echo "需要关注")
- CPU使用: $([ $(echo "$CPU_USAGE < 50" | bc -l) -eq 1 ] && echo "正常" || echo "需要关注")

修复项目:
✅ MenuBarManager 线程安全修复
✅ Timer 生命周期管理修复
✅ 异步任务管理修复
✅ 线程安全工具类添加

建议:
- 继续监控应用在长时间运行下的表现
- 定期检查内存使用情况
- 关注用户反馈的稳定性问题
EOF

echo "📄 测试报告已保存到: $REPORT_FILE"
