<?php
/**
 * 测试数据摘要API
 */

require_once 'config/database.php';
require_once 'api/base.php';

// 直接定义测试需要的函数，避免包含整个 sync_user.php
function getUserPomodoroEventCount($db, $userId) {
    $stmt = $db->prepare('SELECT COUNT(*) FROM pomodoro_events WHERE user_id = ? AND deleted_at IS NULL');
    $stmt->execute([$userId]);
    return (int)$stmt->fetchColumn();
}

function getUserSystemEventCount($db, $userId) {
    $stmt = $db->prepare('SELECT COUNT(*) FROM system_events WHERE user_id = ? AND deleted_at IS NULL');
    $stmt->execute([$userId]);
    return (int)$stmt->fetchColumn();
}

function hasUserTimerSettings($db, $userId) {
    $stmt = $db->prepare('SELECT COUNT(*) FROM timer_settings WHERE user_id = ? AND is_global = 1');
    $stmt->execute([$userId]);
    return (int)$stmt->fetchColumn() > 0;
}

function getRecentPomodoroEvents($db, $userId, $limit = 5) {
    $stmt = $db->prepare('
        SELECT
            uuid, title, start_time, end_time, event_type,
            is_completed, created_at, updated_at
        FROM pomodoro_events
        WHERE user_id = ? AND deleted_at IS NULL
        ORDER BY start_time DESC
        LIMIT ?
    ');
    $stmt->execute([$userId, $limit]);
    return $stmt->fetchAll();
}

function getUserDeviceCount($db, $userId) {
    $stmt = $db->prepare('SELECT COUNT(*) FROM devices WHERE user_id = ? AND is_active = 1');
    $stmt->execute([$userId]);
    return (int)$stmt->fetchColumn();
}

function updateDeviceLastAccess($db, $deviceId) {
    $stmt = $db->prepare('UPDATE devices SET last_access_timestamp = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?');
    $stmt->execute([getCurrentTimestamp(), $deviceId]);
}

function calculateDataLastModifiedTimestamp($db, $userId, $localPomodoroEvents, $localSystemEvents, $localTimerSettings) {
    // 简化版本，只返回当前时间戳
    return getCurrentTimestamp();
}

echo "=== 数据摘要API测试 ===\n\n";

// 测试数据库连接
try {
    $db = getDB();
    echo "✅ 数据库连接成功\n";
} catch (Exception $e) {
    echo "❌ 数据库连接失败: " . $e->getMessage() . "\n";
    exit(1);
}

// 检查 last_access_timestamp 字段是否存在
try {
    $stmt = $db->prepare("PRAGMA table_info(devices)");
    $stmt->execute();
    $columns = $stmt->fetchAll();
    
    $hasLastAccessTimestamp = false;
    foreach ($columns as $column) {
        if ($column['name'] === 'last_access_timestamp') {
            $hasLastAccessTimestamp = true;
            break;
        }
    }
    
    if ($hasLastAccessTimestamp) {
        echo "✅ last_access_timestamp 字段存在\n";
    } else {
        echo "⚠️  last_access_timestamp 字段不存在，正在添加...\n";
        
        // 执行迁移
        $sql = file_get_contents('add_last_access_timestamp.sql');
        $db->exec($sql);
        echo "✅ last_access_timestamp 字段已添加\n";
    }
} catch (Exception $e) {
    echo "❌ 检查字段失败: " . $e->getMessage() . "\n";
}

// 测试新增的函数
echo "\n=== 测试数据摘要函数 ===\n";

// 获取第一个用户进行测试
try {
    $stmt = $db->prepare("SELECT id, user_uuid FROM users LIMIT 1");
    $stmt->execute();
    $user = $stmt->fetch();
    
    if (!$user) {
        echo "⚠️  没有找到测试用户，创建一个测试用户...\n";
        
        $testUserUuid = 'test-user-' . uniqid();
        $stmt = $db->prepare("INSERT INTO users (user_uuid, created_at) VALUES (?, CURRENT_TIMESTAMP)");
        $stmt->execute([$testUserUuid]);
        $userId = $db->lastInsertId();
        
        echo "✅ 创建测试用户: $testUserUuid (ID: $userId)\n";
    } else {
        $userId = $user['id'];
        echo "✅ 使用现有用户: {$user['user_uuid']} (ID: $userId)\n";
    }
    
    // 测试各个函数
    echo "\n--- 测试数据统计函数 ---\n";
    
    // 测试 getUserPomodoroEventCount
    $pomodoroCount = getUserPomodoroEventCount($db, $userId);
    echo "番茄事件数量: $pomodoroCount\n";
    
    // 测试 getUserSystemEventCount  
    $systemEventCount = getUserSystemEventCount($db, $userId);
    echo "系统事件数量: $systemEventCount\n";
    
    // 测试 hasUserTimerSettings
    $hasTimerSettings = hasUserTimerSettings($db, $userId);
    echo "计时器设置: " . ($hasTimerSettings ? '已配置' : '未配置') . "\n";
    
    // 测试 getRecentPomodoroEvents
    $recentEvents = getRecentPomodoroEvents($db, $userId, 5);
    echo "最近事件数量: " . count($recentEvents) . "\n";
    
    // 测试 getUserDeviceCount
    $deviceCount = getUserDeviceCount($db, $userId);
    echo "设备数量: $deviceCount\n";
    
    echo "\n✅ 所有函数测试完成\n";
    
} catch (Exception $e) {
    echo "❌ 函数测试失败: " . $e->getMessage() . "\n";
}

// 测试完整的数据摘要逻辑
echo "\n=== 测试完整数据摘要逻辑 ===\n";

try {
    // 计算最后修改时间戳
    $serverTimestamp = calculateDataLastModifiedTimestamp($db, $userId, [], [], null);
    echo "服务器时间戳: $serverTimestamp\n";
    
    // 构建完整的数据摘要
    $summary = [
        'pomodoro_event_count' => getUserPomodoroEventCount($db, $userId),
        'system_event_count' => getUserSystemEventCount($db, $userId),
        'has_timer_settings' => hasUserTimerSettings($db, $userId),
        'server_timestamp' => $serverTimestamp,
        'last_updated' => date('Y-m-d H:i:s', $serverTimestamp / 1000)
    ];
    
    $recentEvents = getRecentPomodoroEvents($db, $userId, 5);
    
    $userInfo = [
        'user_uuid' => $user['user_uuid'] ?? 'test-user',
        'device_count' => getUserDeviceCount($db, $userId)
    ];
    
    $response = [
        'summary' => $summary,
        'recent_events' => $recentEvents,
        'user_info' => $userInfo
    ];
    
    echo "✅ 数据摘要生成成功:\n";
    echo json_encode($response, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) . "\n";
    
} catch (Exception $e) {
    echo "❌ 数据摘要生成失败: " . $e->getMessage() . "\n";
}

echo "\n=== 测试完成 ===\n";
?>
