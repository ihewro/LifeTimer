<?php
/**
 * 数据迁移脚本：从 life.sqlite 迁移数据到 sync_database.db
 * 
 * 迁移规则：
 * 1. Focus 表 -> pomodoro_events 表
 *    - isTomato = true -> 番茄时间
 *    - isTomato = false -> 正计时
 * 2. Rests 表 -> pomodoro_events 表 (休息类型)
 */

class LifeDataMigrator {
    private $sourceDb;
    private $targetDb;
    private $userId = 1; // 默认用户ID
    private $deviceId = 1; // 默认设备ID
    
    public function __construct($sourceDbPath, $targetDbPath) {
        try {
            $this->sourceDb = new PDO("sqlite:$sourceDbPath");
            $this->sourceDb->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
            
            $this->targetDb = new PDO("sqlite:$targetDbPath");
            $this->targetDb->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
            
            echo "✅ 数据库连接成功\n";
        } catch (PDOException $e) {
            die("❌ 数据库连接失败: " . $e->getMessage() . "\n");
        }
    }
    
    /**
     * 执行完整的数据迁移
     */
    public function migrate() {
        echo "🚀 开始数据迁移...\n\n";
        
        try {
            // 确保目标数据库有基础用户和设备数据
            $this->ensureUserAndDevice();
            
            // 迁移 Focus 表数据
            $this->migrateFocusData();
            
            // 迁移 Rests 表数据
            $this->migrateRestsData();
            
            // 验证迁移结果
            $this->verifyMigration();
            
            echo "\n🎉 数据迁移完成！\n";
            
        } catch (Exception $e) {
            echo "❌ 迁移失败: " . $e->getMessage() . "\n";
            throw $e;
        }
    }
    
    /**
     * 确保目标数据库有基础的用户和设备记录
     */
    private function ensureUserAndDevice() {
        echo "📋 检查用户和设备数据...\n";
        
        // 检查是否已有用户
        $stmt = $this->targetDb->query("SELECT COUNT(*) FROM users");
        $userCount = $stmt->fetchColumn();
        
        if ($userCount == 0) {
            // 创建默认用户
            $userUuid = $this->generateUUID();
            $currentTime = time() * 1000; // 毫秒时间戳
            
            $stmt = $this->targetDb->prepare("
                INSERT INTO users (user_uuid, user_name, created_at, updated_at, last_active_at) 
                VALUES (?, ?, datetime('now'), datetime('now'), datetime('now'))
            ");
            $stmt->execute([$userUuid, '迁移用户']);
            
            $this->userId = $this->targetDb->lastInsertId();
            echo "  ✓ 创建默认用户 (ID: {$this->userId})\n";
        } else {
            // 使用第一个用户
            $stmt = $this->targetDb->query("SELECT id FROM users LIMIT 1");
            $this->userId = $stmt->fetchColumn();
            echo "  ✓ 使用现有用户 (ID: {$this->userId})\n";
        }
        
        // 检查是否已有设备
        $stmt = $this->targetDb->prepare("SELECT COUNT(*) FROM devices WHERE user_id = ?");
        $stmt->execute([$this->userId]);
        $deviceCount = $stmt->fetchColumn();
        
        if ($deviceCount == 0) {
            // 创建默认设备
            $deviceUuid = $this->generateUUID();
            
            $stmt = $this->targetDb->prepare("
                INSERT INTO devices (device_uuid, user_id, device_name, platform, created_at, updated_at) 
                VALUES (?, ?, ?, ?, datetime('now'), datetime('now'))
            ");
            $stmt->execute([$deviceUuid, $this->userId, '迁移设备', 'macOS']);
            
            $this->deviceId = $this->targetDb->lastInsertId();
            echo "  ✓ 创建默认设备 (ID: {$this->deviceId})\n";
        } else {
            // 使用第一个设备
            $stmt = $this->targetDb->prepare("SELECT id FROM devices WHERE user_id = ? LIMIT 1");
            $stmt->execute([$this->userId]);
            $this->deviceId = $stmt->fetchColumn();
            echo "  ✓ 使用现有设备 (ID: {$this->deviceId})\n";
        }
    }
    
    /**
     * 迁移 Focus 表数据
     */
    private function migrateFocusData() {
        echo "\n📊 迁移 Focus 表数据...\n";
        
        // 查询 Focus 表数据，关联 Tasks 表获取任务名称
        $stmt = $this->sourceDb->query("
            SELECT 
                f.id,
                f.endAt,
                f.len,
                f.isTomato,
                f.createdAt,
                f.updatedAt,
                COALESCE(t.name, '未知任务') as task_name
            FROM Focus f
            LEFT JOIN Tasks t ON f.TaskId = t.id
            ORDER BY f.createdAt
        ");
        
        $focusRecords = $stmt->fetchAll(PDO::FETCH_ASSOC);
        $totalRecords = count($focusRecords);
        echo "  📈 找到 {$totalRecords} 条 Focus 记录\n";
        
        $insertStmt = $this->targetDb->prepare("
            INSERT INTO pomodoro_events (
                uuid, user_id, device_id, title, start_time, end_time, 
                event_type, is_completed, created_at, updated_at, last_modified_device_id
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ");
        
        $successCount = 0;
        $errorCount = 0;
        
        foreach ($focusRecords as $record) {
            try {
                $uuid = $this->generateUUID();
                $title = $record['task_name'] ?: '未知任务';
                
                // 根据 isTomato 字段确定事件类型
                $eventType = $record['isTomato'] ? 'pomodoro' : 'count_up';

                // 使用 createdAt 作为开始时间，endAt 作为结束时间
                $startTime = $this->parseDateTime($record['createdAt']);
                $endTime = $this->parseDateTime($record['endAt']);
                
                $createdAt = $this->parseDateTime($record['createdAt']);
                $updatedAt = $this->parseDateTime($record['updatedAt']);
                
                $insertStmt->execute([
                    $uuid,
                    $this->userId,
                    $this->deviceId,
                    $title,
                    $startTime,
                    $endTime,
                    $eventType,
                    1, // is_completed = true
                    $createdAt,
                    $updatedAt,
                    $this->deviceId
                ]);
                
                $successCount++;
                
                if ($successCount % 500 == 0) {
                    echo "    ⏳ 已处理 {$successCount}/{$totalRecords} 条记录\n";
                }
                
            } catch (Exception $e) {
                $errorCount++;
                echo "    ⚠️  处理记录失败 (ID: {$record['id']}): " . $e->getMessage() . "\n";
            }
        }
        
        echo "  ✅ Focus 数据迁移完成: 成功 {$successCount} 条，失败 {$errorCount} 条\n";
    }
    
    /**
     * 迁移 Rests 表数据
     */
    private function migrateRestsData() {
        echo "\n🛌 迁移 Rests 表数据...\n";
        
        $stmt = $this->sourceDb->query("
            SELECT id, endAt, createdAt, updatedAt
            FROM Rests
            ORDER BY createdAt
        ");
        
        $restRecords = $stmt->fetchAll(PDO::FETCH_ASSOC);
        $totalRecords = count($restRecords);
        echo "  📈 找到 {$totalRecords} 条 Rests 记录\n";
        
        $insertStmt = $this->targetDb->prepare("
            INSERT INTO pomodoro_events (
                uuid, user_id, device_id, title, start_time, end_time, 
                event_type, is_completed, created_at, updated_at, last_modified_device_id
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ");
        
        $successCount = 0;
        $errorCount = 0;
        
        foreach ($restRecords as $record) {
            try {
                $uuid = $this->generateUUID();
                $title = '休息';
                $eventType = 'rest';

                // 解析时间 - 使用 createdAt 作为开始时间，endAt 作为结束时间
                $startTime = $this->parseDateTime($record['createdAt']);
                $endTime = $this->parseDateTime($record['endAt']);
                $createdAt = $startTime;
                $updatedAt = $this->parseDateTime($record['updatedAt']);
                
                $insertStmt->execute([
                    $uuid,
                    $this->userId,
                    $this->deviceId,
                    $title,
                    $startTime,
                    $endTime,
                    $eventType,
                    1, // is_completed = true
                    $createdAt,
                    $updatedAt,
                    $this->deviceId
                ]);
                
                $successCount++;
                
                if ($successCount % 500 == 0) {
                    echo "    ⏳ 已处理 {$successCount}/{$totalRecords} 条记录\n";
                }
                
            } catch (Exception $e) {
                $errorCount++;
                echo "    ⚠️  处理记录失败 (ID: {$record['id']}): " . $e->getMessage() . "\n";
            }
        }
        
        echo "  ✅ Rests 数据迁移完成: 成功 {$successCount} 条，失败 {$errorCount} 条\n";
    }
    
    /**
     * 验证迁移结果
     */
    private function verifyMigration() {
        echo "\n🔍 验证迁移结果...\n";
        
        // 统计目标数据库中的记录数
        $stmt = $this->targetDb->query("
            SELECT 
                event_type,
                COUNT(*) as count
            FROM pomodoro_events 
            WHERE user_id = {$this->userId}
            GROUP BY event_type
        ");
        
        $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        echo "  📊 迁移结果统计:\n";
        foreach ($results as $result) {
            echo "    - {$result['event_type']}: {$result['count']} 条记录\n";
        }
        
        // 总计
        $stmt = $this->targetDb->prepare("SELECT COUNT(*) FROM pomodoro_events WHERE user_id = ?");
        $stmt->execute([$this->userId]);
        $totalCount = $stmt->fetchColumn();
        
        echo "  📈 总计: {$totalCount} 条记录\n";
    }
    
    /**
     * 生成 UUID
     */
    private function generateUUID() {
        return sprintf('%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
            mt_rand(0, 0xffff), mt_rand(0, 0xffff),
            mt_rand(0, 0xffff),
            mt_rand(0, 0x0fff) | 0x4000,
            mt_rand(0, 0x3fff) | 0x8000,
            mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
        );
    }
    
    /**
     * 解析日期时间字符串为毫秒时间戳
     * 将UTC+0时间转换为UTC+8时间
     */
    private function parseDateTime($dateTimeStr) {
        if (empty($dateTimeStr)) {
            return time() * 1000;
        }

        try {
            // 创建UTC时区的DateTime对象
            $dateTime = new DateTime($dateTimeStr, new DateTimeZone('UTC'));

            // 转换为UTC+8时区（北京时间）
            $dateTime->setTimezone(new DateTimeZone('Asia/Shanghai'));

            return $dateTime->getTimestamp() * 1000; // 转换为毫秒
        } catch (Exception $e) {
            echo "    ⚠️  日期解析失败: {$dateTimeStr}, 使用当前时间\n";
            return time() * 1000;
        }
    }
}

// 执行迁移
if ($argc < 3) {
    echo "用法: php migrate_life_data.php <源数据库路径> <目标数据库路径>\n";
    echo "示例: php migrate_life_data.php /Users/hewro/Documents/life/life.sqlite sync_server/database/sync_database.db\n";
    exit(1);
}

$sourceDbPath = $argv[1];
$targetDbPath = $argv[2];

if (!file_exists($sourceDbPath)) {
    die("❌ 源数据库文件不存在: {$sourceDbPath}\n");
}

if (!file_exists($targetDbPath)) {
    die("❌ 目标数据库文件不存在: {$targetDbPath}\n");
}

try {
    $migrator = new LifeDataMigrator($sourceDbPath, $targetDbPath);
    $migrator->migrate();
} catch (Exception $e) {
    echo "❌ 迁移过程中发生错误: " . $e->getMessage() . "\n";
    exit(1);
}
