<?php
/**
 * 测试数据摘要API的HTTP请求
 */

echo "=== 数据摘要API HTTP测试 ===\n\n";

// 配置
$baseUrl = 'http://localhost:8000'; // 根据实际情况调整
$testDeviceUuid = 'test-device-' . uniqid();
$testUserUuid = 'test-user-' . uniqid();

// 辅助函数
function makeRequest($url, $method = 'GET', $data = null, $headers = []) {
    $ch = curl_init();
    
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_CUSTOMREQUEST, $method);
    curl_setopt($ch, CURLOPT_HTTPHEADER, array_merge([
        'Content-Type: application/json'
    ], $headers));
    
    if ($data) {
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
    }
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    return [
        'code' => $httpCode,
        'body' => $response,
        'data' => json_decode($response, true)
    ];
}

// 步骤1: 设备初始化
echo "1. 设备初始化...\n";
$response = makeRequest("$baseUrl/api/auth/device-init", 'POST', [
    'device_uuid' => $testDeviceUuid,
    'device_name' => 'Test Device',
    'platform' => 'test'
]);

if ($response['code'] !== 200 || !$response['data']['success']) {
    echo "❌ 设备初始化失败: " . $response['body'] .$response['code']."\n";
    exit(1);
}

$deviceToken = $response['data']['data']['device_token'];
echo "✅ 设备初始化成功，获得token\n";

// 步骤2: 设备绑定
echo "\n2. 设备绑定...\n";
$response = makeRequest("$baseUrl/api/auth/device-bind", 'POST', [
    'device_token' => $deviceToken,
    'user_uuid' => $testUserUuid
]);

if ($response['code'] !== 200 || !$response['data']['success']) {
    echo "❌ 设备绑定失败: " . $response['body'] . "\n";
    exit(1);
}

$sessionToken = $response['data']['data']['session_token'];
echo "✅ 设备绑定成功，获得session token\n";

// 步骤3: 测试数据摘要API
echo "\n3. 测试数据摘要API...\n";
$response = makeRequest("$baseUrl/api/user/sync/summary", 'GET', null, [
    'Authorization: Bearer ' . $sessionToken
]);

echo "HTTP状态码: " . $response['code'] . "\n";
echo "响应内容: " . $response['body'] . "\n";

if ($response['code'] === 200 && $response['data']['success']) {
    echo "✅ 数据摘要API调用成功\n";
    
    $summary = $response['data']['data'];
    echo "\n--- 数据摘要内容 ---\n";
    echo "番茄事件数量: " . $summary['summary']['pomodoro_event_count'] . "\n";
    echo "系统事件数量: " . $summary['summary']['system_event_count'] . "\n";
    echo "计时器设置: " . ($summary['summary']['has_timer_settings'] ? '已配置' : '未配置') . "\n";
    echo "服务器时间戳: " . $summary['summary']['server_timestamp'] . "\n";
    echo "最后更新: " . $summary['summary']['last_updated'] . "\n";
    echo "最近事件数量: " . count($summary['recent_events']) . "\n";
    echo "用户UUID: " . $summary['user_info']['user_uuid'] . "\n";
    echo "设备数量: " . $summary['user_info']['device_count'] . "\n";
    
} else {
    echo "❌ 数据摘要API调用失败\n";
    if (isset($response['data']['message'])) {
        echo "错误信息: " . $response['data']['message'] . "\n";
    }
}

// 步骤4: 对比完整同步API
echo "\n4. 对比完整同步API...\n";
$response = makeRequest("$baseUrl/api/user/sync/full", 'GET', null, [
    'Authorization: Bearer ' . $sessionToken
]);

if ($response['code'] === 200 && $response['data']['success']) {
    echo "✅ 完整同步API调用成功\n";
    
    $fullData = $response['data']['data'];
    echo "完整同步 - 番茄事件数量: " . count($fullData['pomodoroEvents']) . "\n";
    echo "完整同步 - 系统事件数量: " . count($fullData['systemEvents']) . "\n";
    echo "完整同步 - 计时器设置: " . ($fullData['timerSettings'] ? '已配置' : '未配置') . "\n";
    
    // 计算数据大小对比
    $summarySize = strlen(json_encode($summary));
    $fullSize = strlen(json_encode($fullData));
    $reduction = round((1 - $summarySize / $fullSize) * 100, 1);
    
    echo "\n--- 性能对比 ---\n";
    echo "摘要数据大小: " . $summarySize . " 字节\n";
    echo "完整数据大小: " . $fullSize . " 字节\n";
    echo "数据减少: " . $reduction . "%\n";
    
} else {
    echo "⚠️  完整同步API调用失败，无法进行对比\n";
}

// 清理：解绑设备
echo "\n5. 清理测试数据...\n";
$response = makeRequest("$baseUrl/api/auth/device-unbind", 'POST', [
    'session_token' => $sessionToken
]);

if ($response['code'] === 200 && $response['data']['success']) {
    echo "✅ 设备解绑成功\n";
} else {
    echo "⚠️  设备解绑失败，可能需要手动清理\n";
}

echo "\n=== 测试完成 ===\n";
?>
