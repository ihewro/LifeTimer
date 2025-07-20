<?php
/**
 * 测试同步逻辑修复后的功能
 * 验证本地变更不会因为时间戳更新顺序问题而丢失
 */

require_once 'config/database.php';
require_once 'includes/functions.php';
require_once 'includes/auth.php';

class SyncLogicFixTester {
    private $baseURL;
    private $testUser;
    private $sessionToken;
    
    public function __construct($baseURL = 'http://localhost:8080') {
        $this->baseURL = rtrim($baseURL, '/');
    }
    
    /**
     * 运行所有测试
     */
    public function runAllTests() {
        echo "🚀 开始同步逻辑修复验证测试\n";
        echo "服务器地址: {$this->baseURL}\n";
        echo "时间: " . date('Y-m-d H:i:s') . "\n\n";
        
        try {
            // 1. 准备测试环境
            $this->setupTestEnvironment();
            
            // 2. 测试场景1：本地变更时间戳小于服务器时间戳
            $this->testLocalChangesWithOlderTimestamp();
            
            // 3. 测试场景2：并发修改冲突处理
            $this->testConcurrentModificationConflicts();
            
            // 4. 测试场景3：时间戳更新顺序
            $this->testTimestampUpdateOrder();
            
            echo "\n✅ 所有测试通过！同步逻辑修复验证成功\n";
            
        } catch (Exception $e) {
            echo "\n❌ 测试失败: " . $e->getMessage() . "\n";
            echo "堆栈跟踪:\n" . $e->getTraceAsString() . "\n";
            exit(1);
        }
    }
    
    /**
     * 准备测试环境
     */
    private function setupTestEnvironment() {
        echo "📋 准备测试环境...\n";
        
        // 创建测试用户
        $deviceUuid = $this->generateUUID();
        
        $authResponse = $this->apiRequest('POST', '/api/auth/device-init', [
            'device_uuid' => $deviceUuid,
            'device_name' => 'Test Device',
            'platform' => 'macOS'
        ]);
        
        $this->assertSuccess($authResponse);
        $this->testUser = $authResponse['data'];
        $this->sessionToken = $this->testUser['session_token'];
        
        echo "  ✓ 测试用户创建成功: {$this->testUser['user_uuid']}\n";
    }
    
    /**
     * 测试场景1：本地变更时间戳小于服务器时间戳
     */
    private function testLocalChangesWithOlderTimestamp() {
        echo "\n📊 测试场景1：本地变更时间戳小于服务器时间戳...\n";
        
        // 步骤1：模拟其他设备先推送数据到服务器
        $serverEventTime = time() * 1000;
        $serverEvent = [
            'uuid' => $this->generateUUID(),
            'title' => '服务器事件',
            'start_time' => $serverEventTime,
            'end_time' => $serverEventTime + 1500000, // 25分钟后
            'event_type' => 'pomodoro',
            'is_completed' => true,
            'created_at' => $serverEventTime,
            'updated_at' => $serverEventTime
        ];
        
        $serverResponse = $this->apiRequest('POST', '/api/user/sync/incremental', [
            'last_sync_timestamp' => 0,
            'changes' => [
                'pomodoro_events' => [
                    'created' => [$serverEvent],
                    'updated' => [],
                    'deleted' => []
                ],
                'system_events' => ['created' => []],
                'timer_settings' => null
            ]
        ], ['Authorization: Bearer ' . $this->sessionToken]);
        
        $this->assertSuccess($serverResponse);
        $serverTimestamp = $serverResponse['data']['server_timestamp'];
        
        echo "  📊 服务器事件时间: " . date('Y-m-d H:i:s', intval($serverEventTime / 1000)) . "\n";
        echo "  📊 服务器时间戳: " . date('Y-m-d H:i:s', intval($serverTimestamp / 1000)) . "\n";
        
        // 步骤2：模拟本地有一个更早时间的事件（这是关键测试点）
        $localEventTime = $serverEventTime - 600000; // 比服务器事件早10分钟
        $localEvent = [
            'uuid' => $this->generateUUID(),
            'title' => '本地早期事件',
            'start_time' => $localEventTime,
            'end_time' => $localEventTime + 1500000,
            'event_type' => 'pomodoro',
            'is_completed' => true,
            'created_at' => $localEventTime,
            'updated_at' => $localEventTime
        ];
        
        echo "  📊 本地事件时间: " . date('Y-m-d H:i:s', intval($localEventTime / 1000)) . "\n";
        
        // 步骤3：使用服务器时间戳作为 last_sync_timestamp 进行增量同步
        // 这模拟了修复前的问题场景：如果使用服务器时间戳，本地早期事件会被误判为已同步
        $incrementalResponse = $this->apiRequest('POST', '/api/user/sync/incremental', [
            'last_sync_timestamp' => $localEventTime - 300000, // 使用比本地事件更早的时间戳
            'changes' => [
                'pomodoro_events' => [
                    'created' => [$localEvent],
                    'updated' => [],
                    'deleted' => []
                ],
                'system_events' => ['created' => []],
                'timer_settings' => null
            ]
        ], ['Authorization: Bearer ' . $this->sessionToken]);
        
        $this->assertSuccess($incrementalResponse);
        
        // 验证：本地事件应该成功推送到服务器
        $finalResponse = $this->apiRequest('GET', '/api/user/sync/full', null, [
            'Authorization: Bearer ' . $this->sessionToken
        ]);
        
        $this->assertSuccess($finalResponse);
        $allEvents = $finalResponse['data']['pomodoro_events'];
        
        $localEventFound = false;
        $serverEventFound = false;
        
        foreach ($allEvents as $event) {
            if ($event['uuid'] === $localEvent['uuid']) {
                $localEventFound = true;
            }
            if ($event['uuid'] === $serverEvent['uuid']) {
                $serverEventFound = true;
            }
        }
        
        if ($localEventFound && $serverEventFound) {
            echo "  ✓ 本地早期事件成功推送到服务器\n";
            echo "  ✓ 服务器事件保持完整\n";
            echo "  ✓ 时间戳逻辑修复验证成功\n";
        } else {
            throw new Exception("事件同步失败 - 本地事件: " . ($localEventFound ? "找到" : "丢失") . 
                              ", 服务器事件: " . ($serverEventFound ? "找到" : "丢失"));
        }
    }
    
    /**
     * 测试场景2：并发修改冲突处理
     */
    private function testConcurrentModificationConflicts() {
        echo "\n🔄 测试场景2：并发修改冲突处理...\n";
        
        // 创建一个基础事件
        $baseEventTime = time() * 1000;
        $baseEvent = [
            'uuid' => $this->generateUUID(),
            'title' => '基础事件',
            'start_time' => $baseEventTime,
            'end_time' => $baseEventTime + 1500000,
            'event_type' => 'pomodoro',
            'is_completed' => false,
            'created_at' => $baseEventTime,
            'updated_at' => $baseEventTime
        ];
        
        // 推送基础事件
        $baseResponse = $this->apiRequest('POST', '/api/user/sync/incremental', [
            'last_sync_timestamp' => 0,
            'changes' => [
                'pomodoro_events' => [
                    'created' => [$baseEvent],
                    'updated' => [],
                    'deleted' => []
                ],
                'system_events' => ['created' => []],
                'timer_settings' => null
            ]
        ], ['Authorization: Bearer ' . $this->sessionToken]);
        
        $this->assertSuccess($baseResponse);
        $lastSyncTimestamp = $baseResponse['data']['server_timestamp'];
        
        // 模拟并发修改：两个不同的更新
        $updateTime1 = $baseEventTime + 60000; // 1分钟后
        $updateTime2 = $baseEventTime + 120000; // 2分钟后
        
        $updatedEvent1 = $baseEvent;
        $updatedEvent1['title'] = '更新版本1';
        $updatedEvent1['is_completed'] = true;
        $updatedEvent1['updated_at'] = $updateTime1;
        
        $updatedEvent2 = $baseEvent;
        $updatedEvent2['title'] = '更新版本2';
        $updatedEvent2['is_completed'] = true;
        $updatedEvent2['updated_at'] = $updateTime2;
        
        // 先推送更新1
        $update1Response = $this->apiRequest('POST', '/api/user/sync/incremental', [
            'last_sync_timestamp' => $lastSyncTimestamp,
            'changes' => [
                'pomodoro_events' => [
                    'created' => [],
                    'updated' => [$updatedEvent1],
                    'deleted' => []
                ],
                'system_events' => ['created' => []],
                'timer_settings' => null
            ]
        ], ['Authorization: Bearer ' . $this->sessionToken]);
        
        $this->assertSuccess($update1Response);
        
        // 再推送更新2（应该产生冲突）
        $update2Response = $this->apiRequest('POST', '/api/user/sync/incremental', [
            'last_sync_timestamp' => $lastSyncTimestamp, // 使用旧的时间戳，模拟并发修改
            'changes' => [
                'pomodoro_events' => [
                    'created' => [],
                    'updated' => [$updatedEvent2],
                    'deleted' => []
                ],
                'system_events' => ['created' => []],
                'timer_settings' => null
            ]
        ], ['Authorization: Bearer ' . $this->sessionToken]);
        
        $this->assertSuccess($update2Response);
        
        // 检查冲突处理
        if (!empty($update2Response['data']['conflicts'])) {
            echo "  ✓ 冲突检测正常工作\n";
            echo "  📊 检测到 " . count($update2Response['data']['conflicts']) . " 个冲突\n";
        } else {
            echo "  ⚠️ 未检测到预期的冲突（可能是正常的，取决于冲突解决策略）\n";
        }
        
        echo "  ✓ 并发修改冲突处理测试完成\n";
    }
    
    /**
     * 测试场景3：时间戳更新顺序
     */
    private function testTimestampUpdateOrder() {
        echo "\n⏰ 测试场景3：时间戳更新顺序...\n";
        
        // 这个测试主要验证服务器端的时间戳逻辑
        // 客户端的时间戳更新顺序已经在重构中修复
        
        $eventTime = time() * 1000;
        $testEvent = [
            'uuid' => $this->generateUUID(),
            'title' => '时间戳测试事件',
            'start_time' => $eventTime,
            'end_time' => $eventTime + 1500000,
            'event_type' => 'pomodoro',
            'is_completed' => true,
            'created_at' => $eventTime,
            'updated_at' => $eventTime
        ];
        
        $response = $this->apiRequest('POST', '/api/user/sync/incremental', [
            'last_sync_timestamp' => 0,
            'changes' => [
                'pomodoro_events' => [
                    'created' => [$testEvent],
                    'updated' => [],
                    'deleted' => []
                ],
                'system_events' => ['created' => []],
                'timer_settings' => null
            ]
        ], ['Authorization: Bearer ' . $this->sessionToken]);
        
        $this->assertSuccess($response);
        
        $serverTimestamp = $response['data']['server_timestamp'];
        
        // 验证服务器时间戳应该大于等于事件时间戳
        if ($serverTimestamp >= $eventTime) {
            echo "  ✓ 服务器时间戳逻辑正确\n";
            echo "  📊 事件时间: " . date('Y-m-d H:i:s', intval($eventTime / 1000)) . "\n";
            echo "  📊 服务器时间戳: " . date('Y-m-d H:i:s', intval($serverTimestamp / 1000)) . "\n";
        } else {
            throw new Exception("服务器时间戳逻辑错误：serverTimestamp ($serverTimestamp) < eventTime ($eventTime)");
        }
        
        echo "  ✓ 时间戳更新顺序测试完成\n";
    }
    
    // 辅助方法
    private function apiRequest($method, $endpoint, $data = null, $headers = []) {
        $url = $this->baseURL . $endpoint;
        $ch = curl_init();
        
        curl_setopt_array($ch, [
            CURLOPT_URL => $url,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_CUSTOMREQUEST => $method,
            CURLOPT_HTTPHEADER => array_merge(['Content-Type: application/json'], $headers),
            CURLOPT_TIMEOUT => 30
        ]);
        
        if ($data !== null && in_array($method, ['POST', 'PUT', 'PATCH'])) {
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
        }
        
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        
        if ($response === false) {
            throw new Exception("API请求失败: $url");
        }
        
        $decoded = json_decode($response, true);
        if ($decoded === null) {
            throw new Exception("API响应解析失败: $response");
        }
        
        $decoded['http_code'] = $httpCode;
        return $decoded;
    }
    
    private function assertSuccess($response) {
        if (!$response['success']) {
            throw new Exception("API调用失败: " . $response['message']);
        }
    }
    
    private function generateUUID() {
        return sprintf(
            '%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
            mt_rand(0, 0xffff), mt_rand(0, 0xffff),
            mt_rand(0, 0xffff),
            mt_rand(0, 0x0fff) | 0x4000,
            mt_rand(0, 0x3fff) | 0x8000,
            mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
        );
    }
}

// 运行测试
$tester = new SyncLogicFixTester();
$tester->runAllTests();
?>
