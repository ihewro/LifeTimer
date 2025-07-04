<?php
/**
 * API测试脚本
 * 用于测试同步服务的各个接口
 */

// 测试配置
$base_url = 'http://localhost:8080'; // 修改为你的服务器地址
$test_device_uuid = '550e8400-e29b-41d4-a716-446655440000';

echo "=== 番茄钟同步服务API测试 ===\n\n";

// 测试函数
function makeRequest($url, $method = 'GET', $data = null) {
    $ch = curl_init();
    
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HEADER, false);
    curl_setopt($ch, CURLOPT_TIMEOUT, 30);
    
    if ($method === 'POST') {
        curl_setopt($ch, CURLOPT_POST, true);
        if ($data) {
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
            curl_setopt($ch, CURLOPT_HTTPHEADER, [
                'Content-Type: application/json',
                'Content-Length: ' . strlen(json_encode($data))
            ]);
        }
    }
    
    $response = curl_exec($ch);
    $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $error = curl_error($ch);
    
    curl_close($ch);
    
    if ($error) {
        return ['error' => $error, 'http_code' => $http_code];
    }
    
    return [
        'http_code' => $http_code,
        'response' => json_decode($response, true),
        'raw_response' => $response
    ];
}

// 1. 测试健康检查
echo "1. 测试健康检查...\n";
$result = makeRequest("$base_url/api/health");
if ($result['http_code'] === 200 && $result['response']['success']) {
    echo "✅ 健康检查通过\n";
    echo "   服务器时间: " . date('Y-m-d H:i:s', $result['response']['timestamp'] / 1000) . "\n";
} else {
    echo "❌ 健康检查失败\n";
    echo "   HTTP Code: " . $result['http_code'] . "\n";
    echo "   Response: " . ($result['raw_response'] ?? $result['error']) . "\n";
    exit(1);
}
echo "\n";

// 2. 测试设备注册
echo "2. 测试设备注册...\n";
$device_data = [
    'device_uuid' => $test_device_uuid,
    'device_name' => 'Test MacBook Pro',
    'platform' => 'macOS'
];

$result = makeRequest("$base_url/api/device/register", 'POST', $device_data);
if ($result['http_code'] === 200 && $result['response']['success']) {
    echo "✅ 设备注册成功\n";
    echo "   设备UUID: " . $result['response']['data']['device_uuid'] . "\n";
    echo "   状态: " . $result['response']['data']['status'] . "\n";
    echo "   最后同步时间: " . $result['response']['data']['last_sync_timestamp'] . "\n";
} else {
    echo "❌ 设备注册失败\n";
    echo "   HTTP Code: " . $result['http_code'] . "\n";
    echo "   Response: " . ($result['raw_response'] ?? $result['error']) . "\n";
}
echo "\n";

// 3. 测试全量同步
echo "3. 测试全量同步...\n";
$result = makeRequest("$base_url/api/sync/full?device_uuid=$test_device_uuid");
if ($result['http_code'] === 200 && $result['response']['success']) {
    echo "✅ 全量同步成功\n";
    $data = $result['response']['data'];
    echo "   番茄事件数量: " . count($data['pomodoro_events']) . "\n";
    echo "   系统事件数量: " . count($data['system_events']) . "\n";
    echo "   计时器设置: " . ($data['timer_settings'] ? '已设置' : '未设置') . "\n";
    echo "   服务器时间戳: " . $data['server_timestamp'] . "\n";
} else {
    echo "❌ 全量同步失败\n";
    echo "   HTTP Code: " . $result['http_code'] . "\n";
    echo "   Response: " . ($result['raw_response'] ?? $result['error']) . "\n";
}
echo "\n";

// 4. 测试增量同步（创建一些测试数据）
echo "4. 测试增量同步...\n";
$current_timestamp = time() * 1000;
$sync_data = [
    'device_uuid' => $test_device_uuid,
    'last_sync_timestamp' => 0,
    'changes' => [
        'pomodoro_events' => [
            'created' => [
                [
                    'uuid' => '123e4567-e89b-12d3-a456-426614174000',
                    'title' => '测试番茄时间',
                    'start_time' => $current_timestamp,
                    'end_time' => $current_timestamp + (25 * 60 * 1000), // 25分钟后
                    'event_type' => 'pomodoro',
                    'is_completed' => true,
                    'created_at' => $current_timestamp,
                    'updated_at' => $current_timestamp
                ]
            ],
            'updated' => [],
            'deleted' => []
        ],
        'system_events' => [
            'created' => [
                [
                    'uuid' => '123e4567-e89b-12d3-a456-426614174001',
                    'event_type' => 'app_activated',
                    'timestamp' => $current_timestamp,
                    'data' => ['app' => 'PomodoroTimer'],
                    'created_at' => $current_timestamp
                ]
            ]
        ],
        'timer_settings' => [
            'pomodoro_time' => 1500,
            'short_break_time' => 300,
            'long_break_time' => 900,
            'updated_at' => $current_timestamp
        ]
    ]
];

$result = makeRequest("$base_url/api/sync/incremental", 'POST', $sync_data);
if ($result['http_code'] === 200 && $result['response']['success']) {
    echo "✅ 增量同步成功\n";
    $data = $result['response']['data'];
    echo "   冲突数量: " . count($data['conflicts']) . "\n";
    echo "   服务器变更 - 番茄事件: " . count($data['server_changes']['pomodoro_events']) . "\n";
    echo "   服务器变更 - 系统事件: " . count($data['server_changes']['system_events']) . "\n";
    echo "   服务器时间戳: " . $data['server_timestamp'] . "\n";
    
    if (!empty($data['conflicts'])) {
        echo "   冲突详情:\n";
        foreach ($data['conflicts'] as $conflict) {
            echo "     - 类型: {$conflict['type']}, UUID: {$conflict['uuid']}, 原因: {$conflict['reason']}\n";
        }
    }
} else {
    echo "❌ 增量同步失败\n";
    echo "   HTTP Code: " . $result['http_code'] . "\n";
    echo "   Response: " . ($result['raw_response'] ?? $result['error']) . "\n";
}
echo "\n";

// 5. 再次测试全量同步，验证数据是否保存
echo "5. 验证数据保存（再次全量同步）...\n";
$result = makeRequest("$base_url/api/sync/full?device_uuid=$test_device_uuid");
if ($result['http_code'] === 200 && $result['response']['success']) {
    echo "✅ 数据验证成功\n";
    $data = $result['response']['data'];
    echo "   番茄事件数量: " . count($data['pomodoro_events']) . "\n";
    echo "   系统事件数量: " . count($data['system_events']) . "\n";
    echo "   计时器设置: " . ($data['timer_settings'] ? '已设置' : '未设置') . "\n";
    
    if (!empty($data['pomodoro_events'])) {
        echo "   最新番茄事件: " . $data['pomodoro_events'][0]['title'] . "\n";
    }
    
    if ($data['timer_settings']) {
        $settings = $data['timer_settings'];
        echo "   番茄时间: " . ($settings['pomodoro_time'] / 60) . "分钟\n";
        echo "   短休息: " . ($settings['short_break_time'] / 60) . "分钟\n";
        echo "   长休息: " . ($settings['long_break_time'] / 60) . "分钟\n";
    }
} else {
    echo "❌ 数据验证失败\n";
    echo "   HTTP Code: " . $result['http_code'] . "\n";
    echo "   Response: " . ($result['raw_response'] ?? $result['error']) . "\n";
}
echo "\n";

// 6. 测试错误处理
echo "6. 测试错误处理...\n";

// 测试无效的设备UUID
$result = makeRequest("$base_url/api/sync/full?device_uuid=invalid-uuid");
if ($result['http_code'] === 400) {
    echo "✅ 无效UUID错误处理正确\n";
} else {
    echo "❌ 无效UUID错误处理失败\n";
}

// 测试不存在的设备
$result = makeRequest("$base_url/api/sync/full?device_uuid=550e8400-e29b-41d4-a716-446655440999");
if ($result['http_code'] === 400) {
    echo "✅ 不存在设备错误处理正确\n";
} else {
    echo "❌ 不存在设备错误处理失败\n";
}

echo "\n=== 测试完成 ===\n";
echo "如果所有测试都通过，说明同步服务运行正常！\n";
?>
