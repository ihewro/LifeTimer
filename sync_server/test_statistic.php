<?php
// 测试统计API
require_once 'config/database.php';

// 创建测试数据
function createTestData() {
    $db = getDB();
    
    // 清理现有测试数据
    $db->exec("DELETE FROM pomodoro_events WHERE title LIKE 'Test Event%'");
    
    // 创建测试设备
    $device_uuid = 'test-device-' . uniqid();
    $stmt = $db->prepare("INSERT OR REPLACE INTO devices (device_uuid, device_name, platform) VALUES (?, ?, ?)");
    $stmt->execute([$device_uuid, 'Test Device', 'macOS']);
    
    // 获取本周日期
    $monday = new DateTime();
    $monday->modify('monday this week');
    
    // 创建测试事件数据
    $testEvents = [
        // 周一: 2小时番茄时间 + 1小时正计时
        ['day' => 0, 'type' => '番茄时间', 'duration' => 120], // 2小时
        ['day' => 0, 'type' => '正计时', 'duration' => 60],   // 1小时
        
        // 周二: 3小时番茄时间
        ['day' => 1, 'type' => '番茄时间', 'duration' => 180], // 3小时
        
        // 周三: 1.5小时番茄时间 + 30分钟正计时
        ['day' => 2, 'type' => '番茄时间', 'duration' => 90],  // 1.5小时
        ['day' => 2, 'type' => '正计时', 'duration' => 30],   // 30分钟
        
        // 周四: 4小时番茄时间
        ['day' => 3, 'type' => '番茄时间', 'duration' => 240], // 4小时
        
        // 周五: 2.5小时番茄时间
        ['day' => 4, 'type' => '番茄时间', 'duration' => 150], // 2.5小时
        
        // 周六: 1小时正计时
        ['day' => 5, 'type' => '正计时', 'duration' => 60],   // 1小时
        
        // 周日: 0分钟（无事件）
    ];
    
    foreach ($testEvents as $event) {
        $eventDate = clone $monday;
        $eventDate->modify("+{$event['day']} days");
        $eventDate->setTime(9, 0, 0); // 设置为上午9点开始
        
        $startTime = $eventDate->getTimestamp() * 1000; // 转换为毫秒
        $endTime = $startTime + ($event['duration'] * 60 * 1000); // 加上持续时间
        
        $uuid = 'test-event-' . uniqid();
        $currentTime = time() * 1000;
        
        $stmt = $db->prepare("
            INSERT INTO pomodoro_events 
            (uuid, device_uuid, title, start_time, end_time, event_type, is_completed, created_at, updated_at) 
            VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?)
        ");
        
        $stmt->execute([
            $uuid,
            $device_uuid,
            'Test Event - ' . $event['type'],
            $startTime,
            $endTime,
            $event['type'],
            $currentTime,
            $currentTime
        ]);
    }
    
    echo "测试数据创建完成！\n";
    echo "设备UUID: $device_uuid\n";
    
    return $device_uuid;
}

// 测试API调用
function testAPI($debug = false) {
    $url = 'http://localhost:8000/get_week_statistic';
    if ($debug) {
        $url .= '?debug=1';
    }

    $context = stream_context_create([
        'http' => [
            'method' => 'GET',
            'header' => 'Content-Type: application/json'
        ]
    ]);

    $response = file_get_contents($url, false, $context);

    if ($response === false) {
        echo "API调用失败\n";
        return;
    }

    $data = json_decode($response, true);

    echo "API响应:\n";
    echo json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) . "\n";
}

// 运行测试
echo "=== 统计API测试 ===\n\n";

echo "1. 创建测试数据...\n";
$deviceUuid = createTestData();

echo "\n2. 测试API调用（正常模式）...\n";
testAPI(false);

echo "\n3. 测试API调用（Debug模式）...\n";
testAPI(true);

echo "\n=== 测试完成 ===\n";
?>
