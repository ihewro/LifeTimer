<?php
/**
 * 验证数据迁移结果
 */

$dbPath = 'sync_server/database/sync_database.db';

if (!file_exists($dbPath)) {
    die("❌ 数据库文件不存在: {$dbPath}\n");
}

try {
    $db = new PDO("sqlite:$dbPath");
    $db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    echo "🔍 验证迁移数据...\n\n";
    
    // 1. 统计各类型事件数量
    echo "📊 事件类型统计:\n";
    $stmt = $db->query("SELECT event_type, COUNT(*) as count FROM pomodoro_events GROUP BY event_type ORDER BY count DESC");
    $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    foreach ($results as $result) {
        echo "  - {$result['event_type']}: {$result['count']} 条记录\n";
    }
    
    // 2. 查看番茄时间事件样本
    echo "\n🍅 番茄时间事件样本:\n";
    $stmt = $db->query("
        SELECT title,
               datetime(start_time/1000, 'unixepoch', 'localtime') as start_time,
               datetime(end_time/1000, 'unixepoch', 'localtime') as end_time,
               (end_time - start_time) / 1000 / 60 as duration_minutes
        FROM pomodoro_events
        WHERE event_type = 'pomodoro'
        ORDER BY start_time DESC
        LIMIT 5
    ");
    
    $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
    foreach ($results as $result) {
        echo "  - 任务: {$result['title']}\n";
        echo "    开始: {$result['start_time']}\n";
        echo "    结束: {$result['end_time']}\n";
        echo "    时长: " . round($result['duration_minutes'], 1) . " 分钟\n\n";
    }
    
    // 3. 查看正计时事件样本
    echo "⏱️  正计时事件样本:\n";
    $stmt = $db->query("
        SELECT title,
               datetime(start_time/1000, 'unixepoch', 'localtime') as start_time,
               datetime(end_time/1000, 'unixepoch', 'localtime') as end_time,
               (end_time - start_time) / 1000 / 60 as duration_minutes
        FROM pomodoro_events
        WHERE event_type = 'count_up'
        ORDER BY start_time DESC
        LIMIT 3
    ");
    
    $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
    foreach ($results as $result) {
        echo "  - 任务: {$result['title']}\n";
        echo "    开始: {$result['start_time']}\n";
        echo "    结束: {$result['end_time']}\n";
        echo "    时长: " . round($result['duration_minutes'], 1) . " 分钟\n\n";
    }
    
    // 4. 查看休息事件样本
    echo "🛌 休息事件样本:\n";
    $stmt = $db->query("
        SELECT title,
               datetime(start_time/1000, 'unixepoch', 'localtime') as start_time,
               datetime(end_time/1000, 'unixepoch', 'localtime') as end_time,
               (end_time - start_time) / 1000 / 60 as duration_minutes
        FROM pomodoro_events
        WHERE event_type = 'rest'
        ORDER BY start_time DESC
        LIMIT 3
    ");
    
    $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
    foreach ($results as $result) {
        echo "  - 任务: {$result['title']}\n";
        echo "    开始: {$result['start_time']}\n";
        echo "    结束: {$result['end_time']}\n";
        echo "    时长: " . round($result['duration_minutes'], 1) . " 分钟\n\n";
    }
    
    // 5. 检查数据完整性
    echo "🔍 数据完整性检查:\n";
    
    // 检查是否有空标题
    $stmt = $db->query("SELECT COUNT(*) FROM pomodoro_events WHERE title IS NULL OR title = ''");
    $emptyTitles = $stmt->fetchColumn();
    echo "  - 空标题记录: {$emptyTitles} 条\n";
    
    // 检查时间范围
    $stmt = $db->query("
        SELECT 
            datetime(MIN(start_time)/1000, 'unixepoch', 'localtime') as earliest_start,
            datetime(MAX(end_time)/1000, 'unixepoch', 'localtime') as latest_end
        FROM pomodoro_events
    ");
    $timeRange = $stmt->fetch(PDO::FETCH_ASSOC);
    echo "  - 时间范围: {$timeRange['earliest_start']} 至 {$timeRange['latest_end']}\n";
    
    // 检查异常时长的记录
    $stmt = $db->query("
        SELECT COUNT(*) 
        FROM pomodoro_events 
        WHERE (end_time - start_time) / 1000 / 60 > 120 OR (end_time - start_time) / 1000 / 60 < 0
    ");
    $abnormalDuration = $stmt->fetchColumn();
    echo "  - 异常时长记录 (>120分钟或<0): {$abnormalDuration} 条\n";
    
    echo "\n✅ 数据验证完成！\n";
    
} catch (PDOException $e) {
    echo "❌ 数据库错误: " . $e->getMessage() . "\n";
} catch (Exception $e) {
    echo "❌ 验证失败: " . $e->getMessage() . "\n";
}
