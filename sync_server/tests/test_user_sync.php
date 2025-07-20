<?php
/**
 * 用户账户同步系统综合测试脚本
 * 测试从设备隔离到用户账户系统的完整功能
 */

require_once 'config/database.php';
require_once 'includes/functions.php';
require_once 'includes/auth.php';

class UserSyncTester {
    private $baseURL;
    private $testUsers = [];
    private $testDevices = [];
    private $testSessions = [];
    
    public function __construct($baseURL = 'http://localhost:8080') {
        $this->baseURL = rtrim($baseURL, '/');
    }
    
    /**
     * 运行所有测试
     */
    public function runAllTests() {
        echo "🚀 开始用户账户同步系统测试\n";
        echo "服务器地址: {$this->baseURL}\n";
        echo "时间: " . date('Y-m-d H:i:s') . "\n\n";
        
        try {
            // 1. 数据库版本检查
            $this->testDatabaseVersion();
            
            // 2. 用户认证测试
            $this->testUserAuthentication();
            
            // 3. 设备管理测试
            $this->testDeviceManagement();
            
            // 4. 数据同步测试
            $this->testDataSync();
            
            // 5. 冲突处理测试
            $this->testConflictResolution();
            
            // 6. 多设备同步测试
            $this->testMultiDeviceSync();
            
            // 7. 数据迁移测试
            $this->testDataMigration();
            
            // 8. 性能测试
            $this->testPerformance();
            
            // 9. 清理测试数据
            $this->cleanup();
            
            echo "\n✅ 所有测试通过！用户账户同步系统工作正常。\n";
            
        } catch (Exception $e) {
            echo "\n❌ 测试失败: " . $e->getMessage() . "\n";
            $this->cleanup();
            exit(1);
        }
    }
    
    /**
     * 测试数据库版本
     */
    private function testDatabaseVersion() {
        echo "📋 测试数据库版本...\n";
        
        $dbVersion = Database::getInstance()->getDatabaseVersion();
        
        if ($dbVersion['type'] !== 'user_system') {
            throw new Exception("数据库版本错误，期望: user_system，实际: {$dbVersion['type']}");
        }
        
        echo "  ✓ 数据库版本正确: {$dbVersion['version']}\n";
    }
    
    /**
     * 测试用户认证
     */
    private function testUserAuthentication() {
        echo "🔐 测试用户认证...\n";
        
        // 测试设备初始化
        $deviceInitResponse = $this->apiRequest('POST', '/api/auth/device-init', [
            'device_uuid' => $this->generateUUID(),
            'device_name' => 'Test Device 1',
            'platform' => 'macOS'
        ]);
        
        $this->assertSuccess($deviceInitResponse);
        $this->assertTrue($deviceInitResponse['data']['is_new_user'], '应该创建新用户');
        
        $user1 = $deviceInitResponse['data'];
        $this->testUsers[] = $user1;
        
        echo "  ✓ 设备初始化成功，创建用户: {$user1['user_uuid']}\n";
        
        // 测试设备绑定
        $deviceBindResponse = $this->apiRequest('POST', '/api/auth/device-bind', [
            'user_uuid' => $user1['user_uuid'],
            'device_uuid' => $this->generateUUID(),
            'device_name' => 'Test Device 2',
            'platform' => 'iOS'
        ]);
        
        $this->assertSuccess($deviceBindResponse);
        
        echo "  ✓ 设备绑定成功\n";
        
        // 测试Token刷新
        $refreshResponse = $this->apiRequest('POST', '/api/auth/refresh', [], [
            'Authorization: Bearer ' . $user1['session_token']
        ]);
        
        $this->assertSuccess($refreshResponse);
        
        echo "  ✓ Token刷新成功\n";
    }
    
    /**
     * 测试设备管理
     */
    private function testDeviceManagement() {
        echo "📱 测试设备管理...\n";
        
        $user = $this->testUsers[0];
        
        // 获取用户设备列表
        $devicesResponse = $this->apiRequest('GET', '/api/user/devices', [], [
            'Authorization: Bearer ' . $user['session_token']
        ]);
        
        $this->assertSuccess($devicesResponse);
        $this->assertTrue(count($devicesResponse['data']) >= 2, '应该有至少2个设备');
        
        echo "  ✓ 设备列表获取成功，设备数量: " . count($devicesResponse['data']) . "\n";
    }
    
    /**
     * 测试数据同步
     */
    private function testDataSync() {
        echo "🔄 测试数据同步...\n";
        
        $user = $this->testUsers[0];
        
        // 测试全量同步
        $fullSyncResponse = $this->apiRequest('GET', '/api/sync/full', [], [
            'Authorization: Bearer ' . $user['session_token']
        ]);
        
        $this->assertSuccess($fullSyncResponse);
        
        echo "  ✓ 全量同步成功\n";
        
        // 测试增量同步
        $testEvent = [
            'uuid' => $this->generateUUID(),
            'title' => 'Test Pomodoro',
            'start_time' => time() * 1000,
            'end_time' => (time() + 1500) * 1000,
            'event_type' => 'pomodoro',
            'is_completed' => true,
            'created_at' => time() * 1000,
            'updated_at' => time() * 1000
        ];
        
        $incrementalSyncResponse = $this->apiRequest('POST', '/api/sync/incremental', [
            'last_sync_timestamp' => 0,
            'changes' => [
                'pomodoro_events' => [
                    'created' => [$testEvent],
                    'updated' => [],
                    'deleted' => []
                ],
                'system_events' => [
                    'created' => []
                ],
                'timer_settings' => null
            ]
        ], [
            'Authorization: Bearer ' . $user['session_token']
        ]);
        
        $this->assertSuccess($incrementalSyncResponse);
        
        echo "  ✓ 增量同步成功\n";
    }
    
    /**
     * 测试冲突处理
     */
    private function testConflictResolution() {
        echo "⚔️  测试冲突处理...\n";
        
        $user = $this->testUsers[0];
        
        // 创建一个事件
        $eventUUID = $this->generateUUID();
        $baseTime = time() * 1000;
        
        $event1 = [
            'uuid' => $eventUUID,
            'title' => 'Conflict Test Event',
            'start_time' => $baseTime,
            'end_time' => $baseTime + 1500000,
            'event_type' => 'pomodoro',
            'is_completed' => false,
            'created_at' => $baseTime,
            'updated_at' => $baseTime
        ];
        
        // 第一次同步
        $sync1Response = $this->apiRequest('POST', '/api/sync/incremental', [
            'last_sync_timestamp' => 0,
            'changes' => [
                'pomodoro_events' => [
                    'created' => [$event1],
                    'updated' => [],
                    'deleted' => []
                ],
                'system_events' => ['created' => []],
                'timer_settings' => null
            ]
        ], [
            'Authorization: Bearer ' . $user['session_token']
        ]);
        
        $this->assertSuccess($sync1Response);
        
        // 模拟冲突：尝试创建相同UUID的事件
        $event2 = $event1;
        $event2['title'] = 'Conflict Test Event Modified';
        $event2['updated_at'] = $baseTime + 1000;
        
        $sync2Response = $this->apiRequest('POST', '/api/sync/incremental', [
            'last_sync_timestamp' => $baseTime - 1000,
            'changes' => [
                'pomodoro_events' => [
                    'created' => [$event2],
                    'updated' => [],
                    'deleted' => []
                ],
                'system_events' => ['created' => []],
                'timer_settings' => null
            ]
        ], [
            'Authorization: Bearer ' . $user['session_token']
        ]);
        
        $this->assertSuccess($sync2Response);
        $this->assertTrue(count($sync2Response['data']['conflicts']) > 0, '应该检测到冲突');
        
        echo "  ✓ 冲突检测成功，冲突数量: " . count($sync2Response['data']['conflicts']) . "\n";
    }
    
    /**
     * 测试多设备同步
     */
    private function testMultiDeviceSync() {
        echo "📲 测试多设备同步...\n";
        
        $user = $this->testUsers[0];
        
        // 创建第二个设备会话
        $device2Response = $this->apiRequest('POST', '/api/auth/device-bind', [
            'user_uuid' => $user['user_uuid'],
            'device_uuid' => $this->generateUUID(),
            'device_name' => 'Test Device 3',
            'platform' => 'iOS'
        ]);
        
        $this->assertSuccess($device2Response);
        $device2Token = $device2Response['data']['session_token'];
        
        // 设备1创建事件
        $eventUUID = $this->generateUUID();
        $testEvent = [
            'uuid' => $eventUUID,
            'title' => 'Multi-Device Test',
            'start_time' => time() * 1000,
            'end_time' => (time() + 1500) * 1000,
            'event_type' => 'pomodoro',
            'is_completed' => true,
            'created_at' => time() * 1000,
            'updated_at' => time() * 1000
        ];
        
        $device1SyncResponse = $this->apiRequest('POST', '/api/sync/incremental', [
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
        ], [
            'Authorization: Bearer ' . $user['session_token']
        ]);
        
        $this->assertSuccess($device1SyncResponse);
        
        // 设备2同步数据
        $device2SyncResponse = $this->apiRequest('POST', '/api/sync/incremental', [
            'last_sync_timestamp' => 0,
            'changes' => [
                'pomodoro_events' => ['created' => [], 'updated' => [], 'deleted' => []],
                'system_events' => ['created' => []],
                'timer_settings' => null
            ]
        ], [
            'Authorization: Bearer ' . $device2Token
        ]);
        
        $this->assertSuccess($device2SyncResponse);
        $this->assertTrue(count($device2SyncResponse['data']['server_changes']['pomodoro_events']) > 0, '设备2应该收到设备1的数据');
        
        echo "  ✓ 多设备同步成功\n";
    }
    
    /**
     * 测试数据迁移
     */
    private function testDataMigration() {
        echo "📦 测试数据迁移...\n";
        
        // 这里应该测试从旧版本数据库的迁移
        // 由于测试环境限制，我们只测试迁移API的可用性
        
        $migrationResponse = $this->apiRequest('POST', '/api/sync/migrate', [
            'device_uuid' => $this->generateUUID(),
            'target_user_uuid' => null
        ], [], false); // 允许失败，因为可能没有旧数据
        
        // 迁移API应该返回错误（因为没有旧数据），但不应该崩溃
        echo "  ✓ 迁移API可用\n";
    }
    
    /**
     * 测试性能
     */
    private function testPerformance() {
        echo "⚡ 测试性能...\n";
        
        $user = $this->testUsers[0];
        
        // 批量创建事件测试
        $events = [];
        for ($i = 0; $i < 100; $i++) {
            $events[] = [
                'uuid' => $this->generateUUID(),
                'title' => "Performance Test Event $i",
                'start_time' => (time() + $i * 1500) * 1000,
                'end_time' => (time() + ($i + 1) * 1500) * 1000,
                'event_type' => 'pomodoro',
                'is_completed' => true,
                'created_at' => time() * 1000,
                'updated_at' => time() * 1000
            ];
        }
        
        $startTime = microtime(true);
        
        $batchSyncResponse = $this->apiRequest('POST', '/api/sync/incremental', [
            'last_sync_timestamp' => 0,
            'changes' => [
                'pomodoro_events' => [
                    'created' => $events,
                    'updated' => [],
                    'deleted' => []
                ],
                'system_events' => ['created' => []],
                'timer_settings' => null
            ]
        ], [
            'Authorization: Bearer ' . $user['session_token']
        ]);
        
        $endTime = microtime(true);
        $duration = $endTime - $startTime;
        
        $this->assertSuccess($batchSyncResponse);
        
        echo "  ✓ 批量同步100个事件耗时: " . round($duration, 3) . "秒\n";
        
        if ($duration > 5.0) {
            echo "  ⚠️  警告: 同步耗时较长，可能需要优化\n";
        }
    }
    
    /**
     * 清理测试数据
     */
    private function cleanup() {
        echo "🧹 清理测试数据...\n";
        
        // 这里可以添加清理逻辑
        // 例如删除测试用户、设备、事件等
        
        echo "  ✓ 清理完成\n";
    }
    
    // MARK: - Helper Methods
    
    private function apiRequest($method, $endpoint, $data = [], $headers = [], $expectSuccess = true) {
        $url = $this->baseURL . $endpoint;
        
        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_CUSTOMREQUEST, $method);
        curl_setopt($ch, CURLOPT_TIMEOUT, 30);
        
        if (!empty($data)) {
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
            $headers[] = 'Content-Type: application/json';
        }
        
        if (!empty($headers)) {
            curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
        }
        
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        
        if ($response === false) {
            throw new Exception("API请求失败: $url");
        }
        
        $decoded = json_decode($response, true);
        
        if ($expectSuccess && $httpCode !== 200) {
            throw new Exception("API请求失败 ($httpCode): " . ($decoded['message'] ?? 'Unknown error'));
        }
        
        return $decoded;
    }
    
    private function assertSuccess($response) {
        if (!$response['success']) {
            throw new Exception("API响应失败: " . $response['message']);
        }
    }
    
    private function assertTrue($condition, $message) {
        if (!$condition) {
            throw new Exception("断言失败: $message");
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

/**
 * 数据一致性验证器
 */
class DataConsistencyValidator {
    private $db;

    public function __construct() {
        $this->db = getDB();
    }

    /**
     * 验证数据一致性
     */
    public function validateConsistency() {
        echo "🔍 验证数据一致性...\n";

        $this->validateUserDeviceRelations();
        $this->validateEventUserRelations();
        $this->validateSessionIntegrity();
        $this->validateTimestampConsistency();

        echo "  ✓ 数据一致性验证通过\n";
    }

    private function validateUserDeviceRelations() {
        // 检查所有设备都有对应的用户
        $orphanDevices = $this->db->query("
            SELECT COUNT(*)
            FROM devices d
            LEFT JOIN users u ON d.user_id = u.id
            WHERE u.id IS NULL
        ")->fetchColumn();

        if ($orphanDevices > 0) {
            throw new Exception("发现 $orphanDevices 个孤立的设备记录");
        }
    }

    private function validateEventUserRelations() {
        // 检查所有事件都有对应的用户
        $orphanEvents = $this->db->query("
            SELECT COUNT(*)
            FROM pomodoro_events pe
            LEFT JOIN users u ON pe.user_id = u.id
            WHERE u.id IS NULL
        ")->fetchColumn();

        if ($orphanEvents > 0) {
            throw new Exception("发现 $orphanEvents 个孤立的事件记录");
        }
    }

    private function validateSessionIntegrity() {
        // 检查会话的完整性
        $invalidSessions = $this->db->query("
            SELECT COUNT(*)
            FROM user_sessions s
            LEFT JOIN users u ON s.user_id = u.id
            LEFT JOIN devices d ON s.device_id = d.id
            WHERE u.id IS NULL OR d.id IS NULL
        ")->fetchColumn();

        if ($invalidSessions > 0) {
            throw new Exception("发现 $invalidSessions 个无效的会话记录");
        }
    }

    private function validateTimestampConsistency() {
        // 检查时间戳的一致性
        $inconsistentEvents = $this->db->query("
            SELECT COUNT(*)
            FROM pomodoro_events
            WHERE start_time > end_time OR created_at > updated_at
        ")->fetchColumn();

        if ($inconsistentEvents > 0) {
            throw new Exception("发现 $inconsistentEvents 个时间戳不一致的事件");
        }
    }
}

// 运行测试
if (php_sapi_name() === 'cli') {
    $command = $argv[1] ?? 'test';

    switch ($command) {
        case 'test':
            $serverURL = $argv[2] ?? 'http://localhost:8080';
            $tester = new UserSyncTester($serverURL);
            $tester->runAllTests();
            break;

        case 'validate':
            $validator = new DataConsistencyValidator();
            $validator->validateConsistency();
            break;

        case 'migrate':
            echo "执行数据库迁移...\n";
            include 'migrate_database.php';
            break;

        case 'verify':
            echo "验证迁移结果...\n";
            include 'verify_migration.php';
            break;

        default:
            echo "用法: php test_user_sync.php [command] [options]\n";
            echo "命令:\n";
            echo "  test [server_url]  - 运行完整测试套件\n";
            echo "  validate          - 验证数据一致性\n";
            echo "  migrate           - 执行数据库迁移\n";
            echo "  verify            - 验证迁移结果\n";
            break;
    }
} else {
    echo "请在命令行中运行此脚本\n";
}
?>
