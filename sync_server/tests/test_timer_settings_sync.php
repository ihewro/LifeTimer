<?php
/**
 * 测试计时器设置同步功能
 */

require_once 'config/database.php';
require_once 'includes/functions.php';
require_once 'includes/auth.php';

function testTimerSettingsSync() {
    echo "🧪 开始测试计时器设置同步功能\n\n";
    
    $base_url = 'http://localhost:8000';
    
    // 1. 设备初始化（用户认证）
    echo "1. 设备初始化...\n";
    $device_uuid = sprintf('%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
        mt_rand(0, 0xffff), mt_rand(0, 0xffff),
        mt_rand(0, 0xffff),
        mt_rand(0, 0x0fff) | 0x4000,
        mt_rand(0, 0x3fff) | 0x8000,
        mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
    );
    $init_data = [
        'device_uuid' => $device_uuid,
        'device_name' => 'Test Device',
        'platform' => 'macOS'
    ];

    $result = makeRequest("$base_url/api/auth/device-init", 'POST', $init_data);
    if ($result['http_code'] !== 200 || !$result['response']['success']) {
        echo "❌ 设备初始化失败: " . json_encode($result['response']) . "\n";
        return false;
    }

    $token = $result['response']['data']['session_token'];
    echo "✅ 设备初始化成功，获得token\n\n";
    
    // 2. 测试设置同步
    echo "2. 测试计时器设置同步...\n";
    
    // 创建测试设置数据
    $timerSettings = [
        'pomodoro_time' => 1800,  // 30分钟
        'short_break_time' => 600, // 10分钟
        'long_break_time' => 1200, // 20分钟
        'updated_at' => time() * 1000 // 当前时间的毫秒时间戳
    ];
    
    $sync_data = [
        'last_sync_timestamp' => 0, // 强制覆盖
        'changes' => [
            'pomodoro_events' => [
                'created' => [],
                'updated' => [],
                'deleted' => []
            ],
            'system_events' => [
                'created' => []
            ],
            'timer_settings' => $timerSettings
        ]
    ];
    
    echo "发送设置数据: " . json_encode($timerSettings, JSON_PRETTY_PRINT) . "\n";
    
    $result = makeRequest("$base_url/api/user/sync/incremental", 'POST', $sync_data, $token);
    if ($result['http_code'] !== 200 || !$result['response']['success']) {
        echo "❌ 增量同步失败: " . json_encode($result['response']) . "\n";
        return false;
    }
    
    echo "✅ 设置同步成功\n";
    echo "服务器时间戳: " . $result['response']['data']['server_timestamp'] . "\n\n";
    
    // 3. 验证设置是否正确保存
    echo "3. 验证设置保存...\n";
    
    $result = makeRequest("$base_url/api/user/sync/full", 'GET', null, $token);
    if ($result['http_code'] !== 200 || !$result['response']['success']) {
        echo "❌ 全量同步失败: " . json_encode($result['response']) . "\n";
        return false;
    }
    
    $serverSettings = $result['response']['data']['timer_settings'];
    if (!$serverSettings) {
        echo "❌ 服务器端没有找到计时器设置\n";
        return false;
    }
    
    echo "服务器端设置: " . json_encode($serverSettings, JSON_PRETTY_PRINT) . "\n";
    
    // 验证设置值
    $success = true;
    if ($serverSettings['pomodoro_time'] != $timerSettings['pomodoro_time']) {
        echo "❌ 番茄时间不匹配: 期望 {$timerSettings['pomodoro_time']}, 实际 {$serverSettings['pomodoro_time']}\n";
        $success = false;
    }
    if ($serverSettings['short_break_time'] != $timerSettings['short_break_time']) {
        echo "❌ 短休息时间不匹配: 期望 {$timerSettings['short_break_time']}, 实际 {$serverSettings['short_break_time']}\n";
        $success = false;
    }
    if ($serverSettings['long_break_time'] != $timerSettings['long_break_time']) {
        echo "❌ 长休息时间不匹配: 期望 {$timerSettings['long_break_time']}, 实际 {$serverSettings['long_break_time']}\n";
        $success = false;
    }
    
    if ($success) {
        echo "✅ 设置值验证通过\n\n";
    }
    
    // 4. 测试增量同步获取设置
    echo "4. 测试增量同步获取设置...\n";
    
    // 修改设置
    $updatedSettings = [
        'pomodoro_time' => 2100,  // 35分钟
        'short_break_time' => 450, // 7.5分钟
        'long_break_time' => 1500, // 25分钟
        'updated_at' => (time() + 10) * 1000 // 10秒后的时间戳
    ];
    
    $sync_data['changes']['timer_settings'] = $updatedSettings;
    $sync_data['last_sync_timestamp'] = $result['response']['data']['server_timestamp'];
    
    echo "发送更新的设置: " . json_encode($updatedSettings, JSON_PRETTY_PRINT) . "\n";
    
    $result = makeRequest("$base_url/api/user/sync/incremental", 'POST', $sync_data, $token);
    if ($result['http_code'] !== 200 || !$result['response']['success']) {
        echo "❌ 增量同步更新失败: " . json_encode($result['response']) . "\n";
        return false;
    }
    
    echo "✅ 设置更新同步成功\n";
    
    // 5. 验证增量同步能正确返回设置变更
    echo "5. 验证增量同步返回设置变更...\n";
    
    $lastSyncTimestamp = $result['response']['data']['server_timestamp'] - 20000; // 20秒前
    $sync_data = [
        'last_sync_timestamp' => $lastSyncTimestamp,
        'changes' => [
            'pomodoro_events' => ['created' => [], 'updated' => [], 'deleted' => []],
            'system_events' => ['created' => []]
        ]
    ];
    
    $result = makeRequest("$base_url/api/user/sync/incremental", 'POST', $sync_data, $token);
    if ($result['http_code'] !== 200 || !$result['response']['success']) {
        echo "❌ 增量同步获取变更失败: " . json_encode($result['response']) . "\n";
        return false;
    }
    
    $serverChanges = $result['response']['data']['server_changes'];
    if (!isset($serverChanges['timer_settings']) || !$serverChanges['timer_settings']) {
        echo "❌ 增量同步没有返回设置变更\n";
        return false;
    }
    
    echo "✅ 增量同步正确返回设置变更\n";
    echo "返回的设置: " . json_encode($serverChanges['timer_settings'], JSON_PRETTY_PRINT) . "\n";
    
    echo "\n🎉 所有测试通过！计时器设置同步功能正常工作。\n";
    return true;
}

function makeRequest($url, $method = 'GET', $data = null, $token = null) {
    $ch = curl_init();
    
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_CUSTOMREQUEST, $method);
    
    $headers = ['Content-Type: application/json'];
    if ($token) {
        $headers[] = "Authorization: Bearer $token";
    }
    curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
    
    if ($data && in_array($method, ['POST', 'PUT', 'PATCH'])) {
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
    }
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    return [
        'http_code' => $httpCode,
        'response' => json_decode($response, true)
    ];
}

// 运行测试
testTimerSettingsSync();
?>
