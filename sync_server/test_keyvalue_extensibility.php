<?php
/**
 * 测试key-value格式的扩展性
 * 验证新的timer_settings表结构能够支持未来新增配置项
 */

require_once 'config/database.php';
require_once 'includes/functions.php';
require_once 'includes/auth.php';

function testKeyValueExtensibility() {
    echo "🧪 测试key-value格式的扩展性\n\n";
    
    $base_url = 'http://localhost:8000';
    
    // 1. 设备初始化
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
    echo "✅ 设备初始化成功\n\n";
    
    // 2. 测试基础设置同步
    echo "2. 测试基础设置同步...\n";
    $basicSettings = [
        'pomodoro_time' => 1500,
        'short_break_time' => 300,
        'long_break_time' => 900,
        'updated_at' => time() * 1000
    ];
    
    $sync_data = [
        'last_sync_timestamp' => 0,
        'changes' => [
            'pomodoro_events' => ['created' => [], 'updated' => [], 'deleted' => []],
            'system_events' => ['created' => []],
            'timer_settings' => $basicSettings
        ]
    ];
    
    $result = makeRequest("$base_url/api/user/sync/incremental", 'POST', $sync_data, $token);
    if ($result['http_code'] !== 200 || !$result['response']['success']) {
        echo "❌ 基础设置同步失败: " . json_encode($result['response']) . "\n";
        return false;
    }
    echo "✅ 基础设置同步成功\n\n";
    
    // 3. 直接在数据库中添加新的配置项（模拟未来扩展）
    echo "3. 测试扩展性 - 添加新配置项...\n";
    $db = getDB();
    
    // 获取用户ID
    $stmt = $db->prepare('SELECT id FROM users ORDER BY created_at DESC LIMIT 1');
    $stmt->execute();
    $user = $stmt->fetch();
    $userId = $user['id'];
    
    // 添加新的配置项
    $newSettings = [
        'auto_start_break' => 'true',
        'notification_sound' => 'bell',
        'theme_color' => '#007AFF',
        'daily_goal' => '8'
    ];
    
    $stmt = $db->prepare('
        INSERT INTO timer_settings (user_id, device_id, setting_key, setting_value, updated_at, is_global)
        VALUES (?, NULL, ?, ?, ?, 1)
    ');
    
    $timestamp = time() * 1000;
    foreach ($newSettings as $key => $value) {
        $stmt->execute([$userId, $key, $value, $timestamp]);
    }
    
    echo "✅ 新配置项添加成功\n\n";
    
    // 4. 验证数据库中的所有配置项
    echo "4. 验证数据库中的配置项...\n";
    $stmt = $db->prepare('
        SELECT setting_key, setting_value 
        FROM timer_settings 
        WHERE user_id = ? AND is_global = 1 
        ORDER BY setting_key
    ');
    $stmt->execute([$userId]);
    $allSettings = $stmt->fetchAll();
    
    echo "数据库中的所有配置项:\n";
    foreach ($allSettings as $setting) {
        echo "  - {$setting['setting_key']}: {$setting['setting_value']}\n";
    }
    
    // 验证配置项数量
    $expectedCount = count($basicSettings) - 1 + count($newSettings); // -1 因为updated_at不是配置项
    if (count($allSettings) === $expectedCount) {
        echo "✅ 配置项数量正确: " . count($allSettings) . "\n\n";
    } else {
        echo "❌ 配置项数量不正确: 期望 $expectedCount, 实际 " . count($allSettings) . "\n\n";
        return false;
    }
    
    // 5. 测试API是否能正确处理扩展的配置
    echo "5. 测试API对扩展配置的处理...\n";
    $result = makeRequest("$base_url/api/user/sync/full", 'GET', null, $token);
    if ($result['http_code'] !== 200 || !$result['response']['success']) {
        echo "❌ 全量同步失败: " . json_encode($result['response']) . "\n";
        return false;
    }
    
    $serverSettings = $result['response']['data']['timer_settings'];
    if ($serverSettings) {
        echo "API返回的设置（只包含基础设置）:\n";
        echo "  - pomodoro_time: {$serverSettings['pomodoro_time']}\n";
        echo "  - short_break_time: {$serverSettings['short_break_time']}\n";
        echo "  - long_break_time: {$serverSettings['long_break_time']}\n";
        echo "✅ API正确处理基础设置\n\n";
    } else {
        echo "❌ API未返回设置数据\n\n";
        return false;
    }
    
    echo "🎉 key-value扩展性测试通过！\n";
    echo "✓ 数据库支持任意新配置项\n";
    echo "✓ 现有API保持兼容性\n";
    echo "✓ 为未来扩展做好准备\n\n";
    
    return true;
}

function makeRequest($url, $method = 'GET', $data = null, $token = null) {
    $ch = curl_init();
    
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_CUSTOMREQUEST, $method);
    curl_setopt($ch, CURLOPT_TIMEOUT, 30);
    
    $headers = ['Content-Type: application/json'];
    if ($token) {
        $headers[] = "Authorization: Bearer $token";
    }
    curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
    
    if ($data && in_array($method, ['POST', 'PUT', 'PATCH'])) {
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
    }
    
    $response = curl_exec($ch);
    $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    return [
        'http_code' => $http_code,
        'response' => json_decode($response, true)
    ];
}

// 运行测试
testKeyValueExtensibility();
?>
