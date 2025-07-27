<?php
/**
 * 测试同步时间戳修复的脚本
 * 
 * 这个脚本模拟你描述的场景：
 * 1. 设备A在20:00产生事件并同步
 * 2. 设备B在19:00产生事件，在20:00之后同步
 * 3. 验证设备A能否正确拉取到设备B的19:00事件
 */

require_once 'config.php';
require_once 'api/sync_user.php';

// 模拟时间戳（毫秒）
$time_19_00 = 1640995200000; // 2022-01-01 19:00:00
$time_20_00 = 1640998800000; // 2022-01-01 20:00:00
$time_20_30 = 1641000600000; // 2022-01-01 20:30:00

echo "=== 同步时间戳修复测试 ===\n";
echo "模拟时间：\n";
echo "19:00 = $time_19_00\n";
echo "20:00 = $time_20_00\n";
echo "20:30 = $time_20_30\n\n";

try {
    $db = getDB();
    
    // 清理测试数据
    echo "1. 清理测试数据...\n";
    $db->exec("DELETE FROM pomodoro_events WHERE title LIKE 'TEST_%'");
    $db->exec("DELETE FROM users WHERE user_uuid LIKE 'test_%'");
    $db->exec("DELETE FROM devices WHERE device_uuid LIKE 'test_%'");
    
    // 创建测试用户和设备
    echo "2. 创建测试用户和设备...\n";
    
    // 用户
    $db->exec("INSERT INTO users (user_uuid, created_at) VALUES ('test_user', " . getCurrentTimestamp() . ")");
    $userResult = $db->query("SELECT id FROM users WHERE user_uuid = 'test_user'")->fetch();
    $userId = $userResult['id'];
    
    // 设备A和设备B
    $db->exec("INSERT INTO devices (device_uuid, user_id, created_at) VALUES ('test_device_a', $userId, " . getCurrentTimestamp() . ")");
    $db->exec("INSERT INTO devices (device_uuid, user_id, created_at) VALUES ('test_device_b', $userId, " . getCurrentTimestamp() . ")");
    
    $deviceAResult = $db->query("SELECT id FROM devices WHERE device_uuid = 'test_device_a'")->fetch();
    $deviceBResult = $db->query("SELECT id FROM devices WHERE device_uuid = 'test_device_b'")->fetch();
    $deviceAId = $deviceAResult['id'];
    $deviceBId = $deviceBResult['id'];
    
    echo "用户ID: $userId\n";
    echo "设备A ID: $deviceAId\n";
    echo "设备B ID: $deviceBId\n\n";
    
    // 步骤1：设备A在20:00产生事件并同步
    echo "3. 设备A在20:00产生事件并同步...\n";
    
    // 模拟设备A的事件（客户端时间戳为20:00）
    $deviceA_changes = [
        'pomodoro_events' => [
            'created' => [
                [
                    'uuid' => 'test_event_a_20_00',
                    'title' => 'TEST_设备A_20点事件',
                    'start_time' => $time_20_00,
                    'end_time' => $time_20_00 + 1500000, // 25分钟后
                    'event_type' => 'pomodoro',
                    'is_completed' => true,
                    'created_at' => $time_20_00,
                    'updated_at' => $time_20_00
                ]
            ],
            'updated' => [],
            'deleted' => []
        ]
    ];
    
    // 处理设备A的变更
    processUserPomodoroEventChanges($db, $userId, $deviceAId, $deviceA_changes['pomodoro_events'], 1);
    
    // 获取服务端时间戳（模拟同步完成后设备A记录的lastSyncTimestamp）
    $deviceA_lastSyncTimestamp = getCurrentTimestamp();
    echo "设备A同步完成，lastSyncTimestamp: $deviceA_lastSyncTimestamp\n\n";
    
    // 步骤2：设备B在19:00产生事件，在20:30同步
    echo "4. 设备B在19:00产生事件，在20:30同步...\n";
    
    // 模拟设备B的事件（客户端时间戳为19:00，但在20:30才同步）
    $deviceB_changes = [
        'pomodoro_events' => [
            'created' => [
                [
                    'uuid' => 'test_event_b_19_00',
                    'title' => 'TEST_设备B_19点事件',
                    'start_time' => $time_19_00,
                    'end_time' => $time_19_00 + 1500000, // 25分钟后
                    'event_type' => 'pomodoro',
                    'is_completed' => true,
                    'created_at' => $time_19_00,
                    'updated_at' => $time_19_00  // 客户端时间戳是19:00
                ]
            ],
            'updated' => [],
            'deleted' => []
        ]
    ];
    
    // 处理设备B的变更（注意：服务端会使用当前时间戳）
    processUserPomodoroEventChanges($db, $userId, $deviceBId, $deviceB_changes['pomodoro_events'], 1);
    
    echo "设备B同步完成\n\n";
    
    // 步骤3：验证设备A能否拉取到设备B的事件
    echo "5. 验证设备A能否拉取到设备B的事件...\n";
    echo "设备A使用lastSyncTimestamp: $deviceA_lastSyncTimestamp 查询服务端变更\n";
    
    // 模拟设备A拉取服务端变更
    $serverChanges = getUserPomodoroEventsAfter($db, $userId, $deviceA_lastSyncTimestamp);
    
    echo "查询结果：\n";
    if (empty($serverChanges)) {
        echo "❌ 没有找到任何变更！这说明存在时间戳问题。\n";
    } else {
        echo "✅ 找到 " . count($serverChanges) . " 个变更：\n";
        foreach ($serverChanges as $event) {
            echo "  - 事件: {$event['title']}\n";
            echo "    UUID: {$event['uuid']}\n";
            echo "    客户端创建时间: " . date('Y-m-d H:i:s', $event['start_time'] / 1000) . "\n";
            echo "    服务端更新时间: " . date('Y-m-d H:i:s', $event['updated_at'] / 1000) . "\n";
            echo "    updated_at: {$event['updated_at']}\n\n";
        }
    }
    
    // 步骤4：显示数据库中的实际数据
    echo "6. 数据库中的实际数据：\n";
    $allEvents = $db->query("
        SELECT uuid, title, start_time, updated_at, last_modified_device_id 
        FROM pomodoro_events 
        WHERE user_id = $userId AND title LIKE 'TEST_%'
        ORDER BY start_time
    ")->fetchAll();
    
    foreach ($allEvents as $event) {
        $deviceName = ($event['last_modified_device_id'] == $deviceAId) ? '设备A' : '设备B';
        echo "  - {$event['title']} ($deviceName)\n";
        echo "    客户端时间: " . date('Y-m-d H:i:s', $event['start_time'] / 1000) . "\n";
        echo "    服务端时间: " . date('Y-m-d H:i:s', $event['updated_at'] / 1000) . "\n";
        echo "    updated_at: {$event['updated_at']}\n\n";
    }
    
} catch (Exception $e) {
    echo "错误: " . $e->getMessage() . "\n";
    echo "堆栈跟踪: " . $e->getTraceAsString() . "\n";
}

echo "=== 测试完成 ===\n";
?>
