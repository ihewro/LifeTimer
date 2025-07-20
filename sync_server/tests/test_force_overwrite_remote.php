<?php
/**
 * 测试强制覆盖远程功能
 */

require_once 'config/database.php';
require_once 'includes/functions.php';
require_once 'includes/auth.php';

// 测试配置
$serverUrl = 'http://localhost:8080';
$testUserName = 'test_force_overwrite_' . time();
$testDeviceName = 'Test Device';
$testPlatform = 'macOS';

echo "=== 强制覆盖远程功能测试 ===\n\n";

// 1. 创建测试用户和设备
echo "1. 创建测试用户和设备...\n";
$registerResponse = makeRequest("$serverUrl/api/auth/register", 'POST', [
    'user_name' => $testUserName,
    'device_name' => $testDeviceName,
    'platform' => $testPlatform
]);

if (!$registerResponse['success']) {
    echo "❌ 用户注册失败: " . $registerResponse['message'] . "\n";
    exit(1);
}

$userInfo = $registerResponse['data'];
$sessionToken = $userInfo['session_token'];
echo "✅ 用户注册成功: {$userInfo['user_uuid']}\n";

// 2. 创建一些服务端数据
echo "\n2. 创建服务端数据...\n";
$currentTime = time() * 1000;

$serverData = [
    'last_sync_timestamp' => 0,
    'changes' => [
        'pomodoro_events' => [
            'created' => [
                [
                    'uuid' => 'server-event-001',
                    'title' => '服务端番茄事件1',
                    'start_time' => $currentTime,
                    'end_time' => $currentTime + (25 * 60 * 1000),
                    'event_type' => 'pomodoro',
                    'is_completed' => true,
                    'created_at' => $currentTime,
                    'updated_at' => $currentTime
                ]
            ],
            'updated' => [],
            'deleted' => []
        ],
        'system_events' => [
            'created' => [
                [
                    'uuid' => 'server-system-001',
                    'event_type' => 'app_activated',
                    'timestamp' => $currentTime,
                    'data' => [
                        'app' => 'Test App',
                        'duration' => '300'
                    ],
                    'created_at' => $currentTime
                ]
            ]
        ],
        'timer_settings' => [
            'pomodoro_time' => 1500,
            'short_break_time' => 300,
            'long_break_time' => 900,
            'updated_at' => $currentTime
        ]
    ]
];

$syncResponse = makeRequest("$serverUrl/api/user/sync/incremental", 'POST', $serverData, [
    'Authorization: Bearer ' . $sessionToken
]);

if (!$syncResponse['success']) {
    echo "❌ 创建服务端数据失败: " . $syncResponse['message'] . "\n";
    exit(1);
}

echo "✅ 服务端数据创建成功\n";

// 3. 验证服务端数据
echo "\n3. 验证服务端数据...\n";
$fullSyncResponse = makeRequest("$serverUrl/api/user/sync/full", 'GET', null, [
    'Authorization: Bearer ' . $sessionToken
]);

if (!$fullSyncResponse['success']) {
    echo "❌ 获取服务端数据失败: " . $fullSyncResponse['message'] . "\n";
    exit(1);
}

$serverData = $fullSyncResponse['data'];
echo "✅ 服务端数据验证成功\n";
echo "   番茄事件数量: " . count($serverData['pomodoro_events']) . "\n";
echo "   系统事件数量: " . count($serverData['system_events']) . "\n";
echo "   计时器设置: " . ($serverData['timer_settings'] ? '已设置' : '未设置') . "\n";

// 4. 测试强制覆盖远程
echo "\n4. 测试强制覆盖远程...\n";
$newTime = time() * 1000;

$forceOverwriteData = [
    'last_sync_timestamp' => 0, // 使用0表示强制覆盖
    'changes' => [
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
            'pomodoro_time' => 1800, // 30分钟
            'short_break_time' => 600, // 10分钟
            'long_break_time' => 1200, // 20分钟
            'updated_at' => $newTime
        ]
    ]
];

$overwriteResponse = makeRequest("$serverUrl/api/user/sync/incremental", 'POST', $forceOverwriteData, [
    'Authorization: Bearer ' . $sessionToken
]);

if (!$overwriteResponse['success']) {
    echo "❌ 强制覆盖远程失败: " . $overwriteResponse['message'] . "\n";
    if (isset($overwriteResponse['raw_response'])) {
        echo "原始响应: " . $overwriteResponse['raw_response'] . "\n";
    }
    exit(1);
}

echo "✅ 强制覆盖远程成功\n";

// 5. 验证覆盖结果
echo "\n5. 验证覆盖结果...\n";
$verifyResponse = makeRequest("$serverUrl/api/user/sync/full", 'GET', null, [
    'Authorization: Bearer ' . $sessionToken
]);

if (!$verifyResponse['success']) {
    echo "❌ 验证覆盖结果失败: " . $verifyResponse['message'] . "\n";
    exit(1);
}

$newServerData = $verifyResponse['data'];
echo "✅ 覆盖结果验证成功\n";
echo "   番茄事件数量: " . count($newServerData['pomodoro_events']) . "\n";
echo "   系统事件数量: " . count($newServerData['system_events']) . "\n";
echo "   计时器设置: " . ($newServerData['timer_settings'] ? '已设置' : '未设置') . "\n";

// 检查数据是否被正确替换
$success = true;

// 检查番茄事件
if (count($newServerData['pomodoro_events']) !== 2) {
    echo "❌ 番茄事件数量不正确，期望2个，实际" . count($newServerData['pomodoro_events']) . "个\n";
    $success = false;
} else {
    $eventTitles = array_column($newServerData['pomodoro_events'], 'title');
    if (!in_array('客户端番茄事件1', $eventTitles) || !in_array('客户端番茄事件2', $eventTitles)) {
        echo "❌ 番茄事件内容不正确\n";
        $success = false;
    }
}

// 检查系统事件
if (count($newServerData['system_events']) !== 1) {
    echo "❌ 系统事件数量不正确，期望1个，实际" . count($newServerData['system_events']) . "个\n";
    $success = false;
} else {
    $systemEvent = $newServerData['system_events'][0];
    if ($systemEvent['data']['app'] !== 'Client App') {
        echo "❌ 系统事件内容不正确\n";
        $success = false;
    }
}

// 检查计时器设置
if ($newServerData['timer_settings']['pomodoro_time'] !== 1800) {
    echo "❌ 计时器设置不正确\n";
    $success = false;
}

if ($success) {
    echo "✅ 所有验证通过，强制覆盖远程功能正常工作\n";
} else {
    echo "❌ 验证失败，强制覆盖远程功能存在问题\n";
}

echo "\n=== 测试完成 ===\n";

// 辅助函数
function makeRequest($url, $method = 'GET', $data = null, $headers = []) {
    $ch = curl_init();
    
    curl_setopt_array($ch, [
        CURLOPT_URL => $url,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_CUSTOMREQUEST => $method,
        CURLOPT_HTTPHEADER => array_merge([
            'Content-Type: application/json'
        ], $headers),
        CURLOPT_TIMEOUT => 30
    ]);
    
    if ($data && in_array($method, ['POST', 'PUT', 'PATCH'])) {
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
    }
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $error = curl_error($ch);
    curl_close($ch);
    
    if ($error) {
        return ['success' => false, 'message' => $error, 'http_code' => 0];
    }
    
    $decoded = json_decode($response, true);
    if (json_last_error() !== JSON_ERROR_NONE) {
        return [
            'success' => false, 
            'message' => 'Invalid JSON response', 
            'http_code' => $httpCode,
            'raw_response' => $response
        ];
    }
    
    return array_merge($decoded, ['http_code' => $httpCode]);
}
?>
