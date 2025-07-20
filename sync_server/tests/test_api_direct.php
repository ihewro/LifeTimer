<?php
/**
 * 直接测试API端点
 */

require_once 'config/database.php';
require_once 'includes/functions.php';
require_once 'includes/auth.php';

echo "=== 直接测试强制覆盖远程API ===\n\n";

try {
    $db = getDB();
    
    // 1. 创建测试用户和设备
    echo "1. 创建测试用户和设备...\n";
    
    $userUuid = generateUserUUID();
    $deviceUuid = generateUserUUID(); // 重用UUID生成函数
    $sessionToken = generateSessionToken();
    
    // 插入用户
    $stmt = $db->prepare('INSERT INTO users (user_uuid, user_name) VALUES (?, ?)');
    $stmt->execute([$userUuid, 'Test User']);
    $userId = $db->lastInsertId();
    
    // 插入设备
    $stmt = $db->prepare('INSERT INTO devices (device_uuid, user_id, device_name, platform) VALUES (?, ?, ?, ?)');
    $stmt->execute([$deviceUuid, $userId, 'Test Device', 'macOS']);
    $deviceId = $db->lastInsertId();
    
    // 创建会话
    $expiresAt = date('Y-m-d H:i:s', time() + 3600);
    $stmt = $db->prepare('INSERT INTO user_sessions (user_id, device_id, session_token, expires_at) VALUES (?, ?, ?, ?)');
    $stmt->execute([$userId, $deviceId, $sessionToken, $expiresAt]);
    
    echo "✅ 测试用户创建成功: $userUuid\n";
    echo "✅ 测试设备创建成功: $deviceUuid\n";
    echo "✅ 会话Token: $sessionToken\n";
    
    // 2. 创建一些初始服务端数据
    echo "\n2. 创建初始服务端数据...\n";
    $currentTime = time() * 1000;
    
    // 插入番茄事件
    $stmt = $db->prepare('
        INSERT INTO pomodoro_events 
        (uuid, user_id, device_id, title, start_time, end_time, event_type, is_completed, created_at, updated_at, last_modified_device_id)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ');
    $stmt->execute([
        'server-event-001',
        $userId,
        $deviceId,
        '服务端番茄事件',
        $currentTime,
        $currentTime + (25 * 60 * 1000),
        'pomodoro',
        1,
        $currentTime,
        $currentTime,
        $deviceId
    ]);
    
    // 插入系统事件（测试JSON处理）
    $stmt = $db->prepare('
        INSERT INTO system_events 
        (uuid, user_id, device_id, event_type, timestamp, data, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ');
    $systemEventData = json_encode(['app' => 'Server App', 'duration' => '300']);
    $stmt->execute([
        'server-system-001',
        $userId,
        $deviceId,
        'app_activated',
        $currentTime,
        $systemEventData,
        $currentTime
    ]);
    
    echo "✅ 初始数据创建成功\n";
    
    // 3. 验证初始数据
    echo "\n3. 验证初始数据...\n";
    $stmt = $db->prepare('SELECT COUNT(*) as count FROM pomodoro_events WHERE user_id = ?');
    $stmt->execute([$userId]);
    $pomodoroCount = $stmt->fetch()['count'];
    
    $stmt = $db->prepare('SELECT COUNT(*) as count FROM system_events WHERE user_id = ?');
    $stmt->execute([$userId]);
    $systemCount = $stmt->fetch()['count'];
    
    echo "番茄事件数量: $pomodoroCount\n";
    echo "系统事件数量: $systemCount\n";
    
    // 4. 模拟强制覆盖远程请求
    echo "\n4. 模拟强制覆盖远程请求...\n";
    
    // 模拟客户端数据
    $newTime = time() * 1000;
    $clientChanges = [
        'pomodoro_events' => [
            'created' => [
                [
                    'uuid' => 'client-event-001',
                    'title' => '客户端番茄事件1',
                    'start_time' => $newTime,
                    'end_time' => $newTime + (25 * 60 * 1000),
                    'event_type' => 'pomodoro',
                    'is_completed' => true,
                    'created_at' => $newTime,
                    'updated_at' => $newTime
                ],
                [
                    'uuid' => 'client-event-002',
                    'title' => '客户端番茄事件2',
                    'start_time' => $newTime + (30 * 60 * 1000),
                    'end_time' => $newTime + (55 * 60 * 1000),
                    'event_type' => 'pomodoro',
                    'is_completed' => true,
                    'created_at' => $newTime,
                    'updated_at' => $newTime
                ]
            ],
            'updated' => [],
            'deleted' => []
        ],
        'system_events' => [
            'created' => [
                [
                    'uuid' => 'client-system-001',
                    'event_type' => 'app_activated',
                    'timestamp' => $newTime,
                    'data' => [
                        'app' => 'Client App',
                        'duration' => '600'
                    ],
                    'created_at' => $newTime
                ]
            ]
        ],
        'timer_settings' => [
            'pomodoro_time' => 1800,
            'short_break_time' => 600,
            'long_break_time' => 1200,
            'updated_at' => $newTime
        ]
    ];
    
    // 模拟用户信息
    $userInfo = [
        'user_id' => $userId,
        'device_id' => $deviceId,
        'user_uuid' => $userUuid,
        'device_uuid' => $deviceUuid
    ];
    
    // 直接调用强制覆盖函数
    $db->beginTransaction();
    
    try {
        // 调用强制覆盖函数
        performForceOverwriteRemote($db, $userId, $deviceId, $clientChanges, $newTime);
        
        $db->commit();
        echo "✅ 强制覆盖远程执行成功\n";
        
    } catch (Exception $e) {
        $db->rollback();
        throw $e;
    }
    
    // 5. 验证覆盖结果
    echo "\n5. 验证覆盖结果...\n";
    
    $stmt = $db->prepare('SELECT COUNT(*) as count FROM pomodoro_events WHERE user_id = ?');
    $stmt->execute([$userId]);
    $newPomodoroCount = $stmt->fetch()['count'];
    
    $stmt = $db->prepare('SELECT COUNT(*) as count FROM system_events WHERE user_id = ?');
    $stmt->execute([$userId]);
    $newSystemCount = $stmt->fetch()['count'];
    
    echo "覆盖后番茄事件数量: $newPomodoroCount (期望: 2)\n";
    echo "覆盖后系统事件数量: $newSystemCount (期望: 1)\n";
    
    // 验证具体数据
    $stmt = $db->prepare('SELECT title FROM pomodoro_events WHERE user_id = ? ORDER BY created_at');
    $stmt->execute([$userId]);
    $events = $stmt->fetchAll();
    
    echo "番茄事件标题:\n";
    foreach ($events as $event) {
        echo "  - " . $event['title'] . "\n";
    }
    
    // 验证系统事件的JSON数据
    $stmt = $db->prepare('SELECT data FROM system_events WHERE user_id = ?');
    $stmt->execute([$userId]);
    $systemEvent = $stmt->fetch();
    
    if ($systemEvent) {
        echo "系统事件data字段: " . $systemEvent['data'] . "\n";
        $decodedData = json_decode($systemEvent['data'], true);
        if ($decodedData && isset($decodedData['app'])) {
            echo "✅ 系统事件JSON解析成功: app = " . $decodedData['app'] . "\n";
        } else {
            echo "❌ 系统事件JSON解析失败\n";
        }
    }
    
    // 验证结果
    $success = ($newPomodoroCount == 2 && $newSystemCount == 1);
    
    if ($success) {
        echo "\n✅ 强制覆盖远程功能测试通过！\n";
    } else {
        echo "\n❌ 强制覆盖远程功能测试失败！\n";
    }
    
    // 6. 清理测试数据
    echo "\n6. 清理测试数据...\n";
    $db->exec("DELETE FROM user_sessions WHERE user_id = $userId");
    $db->exec("DELETE FROM pomodoro_events WHERE user_id = $userId");
    $db->exec("DELETE FROM system_events WHERE user_id = $userId");
    $db->exec("DELETE FROM timer_settings WHERE user_id = $userId");
    $db->exec("DELETE FROM devices WHERE user_id = $userId");
    $db->exec("DELETE FROM users WHERE id = $userId");
    echo "✅ 测试数据清理完成\n";
    
} catch (Exception $e) {
    echo "❌ 测试失败: " . $e->getMessage() . "\n";
    echo "错误位置: " . $e->getFile() . ":" . $e->getLine() . "\n";
}

echo "\n=== 测试完成 ===\n";

// 需要包含的函数定义
function performForceOverwriteRemote($db, $userId, $deviceId, $changes, $timestamp) {
    // 清空用户数据
    clearUserData($db, $userId, $timestamp);
    
    // 重新插入客户端数据
    if (isset($changes['pomodoro_events'])) {
        processUserPomodoroEventChanges($db, $userId, $deviceId, $changes['pomodoro_events'], 0);
    }
    
    if (isset($changes['system_events'])) {
        processUserSystemEventChanges($db, $userId, $deviceId, $changes['system_events']);
    }
    
    if (isset($changes['timer_settings'])) {
        processUserTimerSettingsChanges($db, $userId, $deviceId, $changes['timer_settings'], 0);
    }
    
    logMessage("Force overwrite completed for user: $userId");
}

function clearUserData($db, $userId, $timestamp) {
    // 硬删除所有番茄事件
    $stmt = $db->prepare('DELETE FROM pomodoro_events WHERE user_id = ?');
    $stmt->execute([$userId]);
    
    // 硬删除所有系统事件
    $stmt = $db->prepare('DELETE FROM system_events WHERE user_id = ?');
    $stmt->execute([$userId]);
    
    // 删除计时器设置
    $stmt = $db->prepare('DELETE FROM timer_settings WHERE user_id = ?');
    $stmt->execute([$userId]);
    
    logMessage("Hard deleted all existing data for user: $userId (force overwrite)");
}

function processUserPomodoroEventChanges($db, $userId, $deviceId, $changes, $lastSyncTimestamp) {
    $conflicts = [];
    
    // 处理新创建的事件
    if (isset($changes['created'])) {
        foreach ($changes['created'] as $event) {
            try {
                $stmt = $db->prepare('
                    INSERT INTO pomodoro_events
                    (uuid, user_id, device_id, title, start_time, end_time, event_type, is_completed, created_at, updated_at, last_modified_device_id)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ');
                $stmt->execute([
                    $event['uuid'],
                    $userId,
                    $deviceId,
                    $event['title'],
                    $event['start_time'],
                    $event['end_time'],
                    $event['event_type'],
                    $event['is_completed'] ? 1 : 0,
                    $event['created_at'],
                    $event['updated_at'],
                    $deviceId
                ]);
            } catch (PDOException $e) {
                if ($e->getCode() == 23000) { // UNIQUE constraint failed
                    $conflicts[] = [
                        'type' => 'pomodoro_event',
                        'uuid' => $event['uuid'],
                        'reason' => 'duplicate_uuid'
                    ];
                } else {
                    throw $e;
                }
            }
        }
    }
    
    return $conflicts;
}

function processUserSystemEventChanges($db, $userId, $deviceId, $changes) {
    if (isset($changes['created'])) {
        foreach ($changes['created'] as $event) {
            try {
                $stmt = $db->prepare('
                    INSERT INTO system_events
                    (uuid, user_id, device_id, event_type, timestamp, data, created_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                ');
                $stmt->execute([
                    $event['uuid'],
                    $userId,
                    $deviceId,
                    $event['event_type'],
                    $event['timestamp'],
                    is_array($event['data']) ? json_encode($event['data']) : $event['data'], // 修复的关键点
                    $event['created_at']
                ]);
            } catch (PDOException $e) {
                if ($e->getCode() != 23000) { // 忽略重复UUID错误
                    throw $e;
                }
            }
        }
    }
}

function processUserTimerSettingsChanges($db, $userId, $deviceId, $settings, $lastSyncTimestamp) {
    // 删除现有设置
    $stmt = $db->prepare('DELETE FROM timer_settings WHERE user_id = ?');
    $stmt->execute([$userId]);
    
    // 插入新设置
    $stmt = $db->prepare('
        INSERT INTO timer_settings 
        (user_id, device_id, pomodoro_time, short_break_time, long_break_time, updated_at, is_global)
        VALUES (?, ?, ?, ?, ?, ?, 1)
    ');
    $stmt->execute([
        $userId,
        $deviceId,
        $settings['pomodoro_time'],
        $settings['short_break_time'],
        $settings['long_break_time'],
        $settings['updated_at']
    ]);
}

function logMessage($message, $level = 'INFO') {
    echo "[LOG] $message\n";
}
?>
