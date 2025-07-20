<?php
/**
 * 简单测试强制覆盖远程功能
 */

// 直接测试数组到JSON转换
echo "=== 测试数组到JSON转换 ===\n";

$testData = [
    'app' => 'Test App',
    'duration' => '300'
];

echo "原始数组: " . print_r($testData, true) . "\n";
echo "JSON编码: " . json_encode($testData) . "\n";
echo "是否为数组: " . (is_array($testData) ? 'true' : 'false') . "\n";

// 测试JSON解码
$jsonString = json_encode($testData);
$decodedData = json_decode($jsonString, true);
echo "解码后: " . print_r($decodedData, true) . "\n";

// 测试数据库插入逻辑
echo "\n=== 测试数据库插入逻辑 ===\n";

require_once 'config/database.php';

try {
    $db = getDB();
    
    // 创建测试表（如果不存在）
    $db->exec('CREATE TABLE IF NOT EXISTS test_system_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid VARCHAR(36) NOT NULL,
        event_type VARCHAR(30) NOT NULL,
        timestamp BIGINT NOT NULL,
        data TEXT,
        created_at BIGINT NOT NULL
    )');
    
    // 测试插入数据
    $testEvent = [
        'uuid' => 'test-uuid-001',
        'event_type' => 'app_activated',
        'timestamp' => time() * 1000,
        'data' => [
            'app' => 'Test App',
            'duration' => '300'
        ],
        'created_at' => time() * 1000
    ];
    
    echo "测试事件数据: " . print_r($testEvent, true) . "\n";
    
    // 使用修复后的逻辑
    $stmt = $db->prepare('
        INSERT INTO test_system_events
        (uuid, event_type, timestamp, data, created_at)
        VALUES (?, ?, ?, ?, ?)
    ');
    
    $dataToInsert = is_array($testEvent['data']) ? json_encode($testEvent['data']) : $testEvent['data'];
    echo "要插入的data字段: " . $dataToInsert . "\n";
    
    $stmt->execute([
        $testEvent['uuid'],
        $testEvent['event_type'],
        $testEvent['timestamp'],
        $dataToInsert,
        $testEvent['created_at']
    ]);
    
    echo "✅ 数据插入成功\n";
    
    // 读取数据并验证
    $stmt = $db->prepare('SELECT * FROM test_system_events WHERE uuid = ?');
    $stmt->execute([$testEvent['uuid']]);
    $result = $stmt->fetch();
    
    if ($result) {
        echo "✅ 数据读取成功\n";
        echo "存储的data字段: " . $result['data'] . "\n";
        
        // 解码JSON
        $decodedData = json_decode($result['data'], true);
        if ($decodedData !== null) {
            echo "✅ JSON解码成功: " . print_r($decodedData, true) . "\n";
        } else {
            echo "❌ JSON解码失败\n";
        }
    } else {
        echo "❌ 数据读取失败\n";
    }
    
    // 清理测试数据
    try {
        $db->exec('DELETE FROM test_system_events WHERE uuid = ?');
        $stmt = $db->prepare('DELETE FROM test_system_events WHERE uuid = ?');
        $stmt->execute([$testEvent['uuid']]);
        echo "✅ 测试数据清理成功\n";
    } catch (Exception $cleanupError) {
        echo "⚠️ 测试数据清理失败（不影响功能）: " . $cleanupError->getMessage() . "\n";
    }
    
} catch (Exception $e) {
    echo "❌ 测试失败: " . $e->getMessage() . "\n";
}

echo "\n=== 测试完成 ===\n";
?>
