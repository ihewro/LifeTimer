<?php
/**
 * 测试 server_timestamp 修复后的同步功能
 * 验证 server_timestamp 是否正确反映数据的实际修改时间
 */

require_once 'config/database.php';
require_once 'includes/functions.php';
require_once 'includes/auth.php';

class ServerTimestampTester {
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
        echo "🚀 开始 server_timestamp 修复验证测试\n";
        echo "服务器地址: {$this->baseURL}\n";
        echo "时间: " . date('Y-m-d H:i:s') . "\n\n";
        
        try {
            // 1. 准备测试环境
            $this->setupTestEnvironment();
            
            // 2. 测试全量同步的 server_timestamp
            $this->testFullSyncTimestamp();
            
            // 3. 测试增量同步的 server_timestamp
            $this->testIncrementalSyncTimestamp();
            
            // 4. 测试强制覆盖的 server_timestamp
            $this->testForceOverwriteTimestamp();
            
            // 5. 测试时间戳比较逻辑
            $this->testTimestampComparison();
            
            echo "\n✅ 所有测试通过！server_timestamp 修复验证成功\n";
            
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
     * 测试全量同步的 server_timestamp
     */
    private function testFullSyncTimestamp() {
        echo "\n📡 测试全量同步的 server_timestamp...\n";
        
        // 先添加一些测试数据
        $testEvent = [
            'uuid' => $this->generateUUID(),
            'title' => 'Test Event',
            'start_time' => time() * 1000 - 3600000, // 1小时前
            'end_time' => time() * 1000 - 1800000,   // 30分钟前
            'event_type' => 'pomodoro',
            'is_completed' => true,
            'created_at' => time() * 1000 - 3600000,
            'updated_at' => time() * 1000 - 1800000  // 30分钟前更新
        ];
        
        // 通过增量同步添加数据
        $incrementalResponse = $this->apiRequest('POST', '/api/user/sync/incremental', [
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
        
        $this->assertSuccess($incrementalResponse);
        
        // 等待一秒确保时间差异
        sleep(1);
        
        // 执行全量同步
        $fullSyncResponse = $this->apiRequest('GET', '/api/user/sync/full', null, [
            'Authorization: Bearer ' . $this->sessionToken
        ]);
        
        $this->assertSuccess($fullSyncResponse);
        
        $serverTimestamp = $fullSyncResponse['data']['server_timestamp'];
        $eventUpdatedAt = $testEvent['updated_at'];
        
        // 验证 server_timestamp 应该反映数据的实际修改时间
        // 由于我们的事件是30分钟前更新的，server_timestamp 应该接近那个时间
        echo "  📊 事件更新时间: " . date('Y-m-d H:i:s', intval($eventUpdatedAt / 1000)) . "\n";
        echo "  📊 服务器时间戳: " . date('Y-m-d H:i:s', intval($serverTimestamp / 1000)) . "\n";
        
        // server_timestamp 应该大于等于事件的更新时间
        if ($serverTimestamp >= $eventUpdatedAt) {
            echo "  ✓ server_timestamp 正确反映了数据的修改时间\n";
        } else {
            throw new Exception("server_timestamp ($serverTimestamp) 小于事件更新时间 ($eventUpdatedAt)");
        }
    }
    
    /**
     * 测试增量同步的 server_timestamp
     */
    private function testIncrementalSyncTimestamp() {
        echo "\n🔄 测试增量同步的 server_timestamp...\n";
        
        // 获取当前的 server_timestamp
        $fullSyncResponse = $this->apiRequest('GET', '/api/user/sync/full', null, [
            'Authorization: Bearer ' . $this->sessionToken
        ]);
        $this->assertSuccess($fullSyncResponse);
        $lastSyncTimestamp = $fullSyncResponse['data']['server_timestamp'];
        
        // 等待一秒确保时间差异
        sleep(1);
        
        // 创建新的测试事件
        $newEventTime = time() * 1000;
        $newTestEvent = [
            'uuid' => $this->generateUUID(),
            'title' => 'New Test Event',
            'start_time' => $newEventTime,
            'end_time' => $newEventTime + 1500000, // 25分钟后
            'event_type' => 'pomodoro',
            'is_completed' => false,
            'created_at' => $newEventTime,
            'updated_at' => $newEventTime
        ];
        
        // 执行增量同步
        $incrementalResponse = $this->apiRequest('POST', '/api/user/sync/incremental', [
            'last_sync_timestamp' => $lastSyncTimestamp,
            'changes' => [
                'pomodoro_events' => [
                    'created' => [$newTestEvent],
                    'updated' => [],
                    'deleted' => []
                ],
                'system_events' => ['created' => []],
                'timer_settings' => null
            ]
        ], ['Authorization: Bearer ' . $this->sessionToken]);
        
        $this->assertSuccess($incrementalResponse);
        
        $newServerTimestamp = $incrementalResponse['data']['server_timestamp'];
        
        echo "  📊 新事件创建时间: " . date('Y-m-d H:i:s', intval($newEventTime / 1000)) . "\n";
        echo "  📊 增量同步后时间戳: " . date('Y-m-d H:i:s', intval($newServerTimestamp / 1000)) . "\n";
        
        // 新的 server_timestamp 应该大于等于新事件的创建时间
        if ($newServerTimestamp >= $newEventTime) {
            echo "  ✓ 增量同步的 server_timestamp 正确反映了新数据的时间\n";
        } else {
            throw new Exception("增量同步的 server_timestamp ($newServerTimestamp) 小于新事件时间 ($newEventTime)");
        }
        
        // 新的 server_timestamp 应该大于上次同步时间
        if ($newServerTimestamp > $lastSyncTimestamp) {
            echo "  ✓ server_timestamp 正确更新\n";
        } else {
            throw new Exception("新的 server_timestamp ($newServerTimestamp) 不大于上次同步时间 ($lastSyncTimestamp)");
        }
    }
    
    /**
     * 测试强制覆盖的 server_timestamp
     */
    private function testForceOverwriteTimestamp() {
        echo "\n🔄 测试强制覆盖的 server_timestamp...\n";
        
        // 创建一个较早时间的事件用于强制覆盖
        $oldEventTime = time() * 1000 - 7200000; // 2小时前
        $overwriteEvent = [
            'uuid' => $this->generateUUID(),
            'title' => 'Overwrite Event',
            'start_time' => $oldEventTime,
            'end_time' => $oldEventTime + 1500000,
            'event_type' => 'pomodoro',
            'is_completed' => true,
            'created_at' => $oldEventTime,
            'updated_at' => $oldEventTime
        ];
        
        // 执行强制覆盖远程（last_sync_timestamp = 0）
        $forceOverwriteResponse = $this->apiRequest('POST', '/api/user/sync/incremental', [
            'last_sync_timestamp' => 0,
            'changes' => [
                'pomodoro_events' => [
                    'created' => [$overwriteEvent],
                    'updated' => [],
                    'deleted' => []
                ],
                'system_events' => ['created' => []],
                'timer_settings' => null
            ]
        ], ['Authorization: Bearer ' . $this->sessionToken]);
        
        $this->assertSuccess($forceOverwriteResponse);
        
        $overwriteServerTimestamp = $forceOverwriteResponse['data']['server_timestamp'];
        
        echo "  📊 覆盖事件时间: " . date('Y-m-d H:i:s', intval($oldEventTime / 1000)) . "\n";
        echo "  📊 强制覆盖后时间戳: " . date('Y-m-d H:i:s', intval($overwriteServerTimestamp / 1000)) . "\n";
        
        // 强制覆盖的 server_timestamp 应该反映覆盖数据的时间
        if ($overwriteServerTimestamp >= $oldEventTime) {
            echo "  ✓ 强制覆盖的 server_timestamp 正确\n";
        } else {
            throw new Exception("强制覆盖的 server_timestamp ($overwriteServerTimestamp) 小于覆盖事件时间 ($oldEventTime)");
        }
    }
    
    /**
     * 测试时间戳比较逻辑
     */
    private function testTimestampComparison() {
        echo "\n⏰ 测试时间戳比较逻辑...\n";
        
        // 获取当前状态
        $fullSyncResponse = $this->apiRequest('GET', '/api/user/sync/full', null, [
            'Authorization: Bearer ' . $this->sessionToken
        ]);
        $this->assertSuccess($fullSyncResponse);
        $currentTimestamp = $fullSyncResponse['data']['server_timestamp'];
        
        // 使用当前时间戳进行增量同步，应该没有变更
        $incrementalResponse = $this->apiRequest('POST', '/api/user/sync/incremental', [
            'last_sync_timestamp' => $currentTimestamp,
            'changes' => [
                'pomodoro_events' => ['created' => [], 'updated' => [], 'deleted' => []],
                'system_events' => ['created' => []],
                'timer_settings' => null
            ]
        ], ['Authorization: Bearer ' . $this->sessionToken]);
        
        $this->assertSuccess($incrementalResponse);
        
        $serverChanges = $incrementalResponse['data']['server_changes'];
        
        // 应该没有服务器端变更
        if (empty($serverChanges['pomodoro_events']) && 
            empty($serverChanges['system_events']) && 
            $serverChanges['timer_settings'] === null) {
            echo "  ✓ 时间戳比较逻辑正确，没有检测到虚假变更\n";
        } else {
            throw new Exception("时间戳比较逻辑错误，检测到了不应该存在的变更");
        }
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
$tester = new ServerTimestampTester();
$tester->runAllTests();
?>
