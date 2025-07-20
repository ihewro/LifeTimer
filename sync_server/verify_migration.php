<?php
/**
 * 数据库迁移验证脚本
 * 验证从设备隔离到用户账户系统的迁移是否成功
 */

require_once 'config/database.php';
require_once 'includes/functions.php';

class MigrationVerifier {
    private $db;
    
    public function __construct() {
        $this->db = getDB();
    }
    
    /**
     * 执行完整的迁移验证
     */
    public function verify() {
        echo "🔍 开始验证数据库迁移结果\n";
        echo "时间：" . date('Y-m-d H:i:s') . "\n\n";
        
        try {
            // 1. 检查数据库版本
            $this->checkDatabaseVersion();
            
            // 2. 验证表结构
            $this->verifyTableStructure();
            
            // 3. 验证数据完整性
            $this->verifyDataIntegrity();
            
            // 4. 验证外键关系
            $this->verifyForeignKeys();
            
            // 5. 验证索引
            $this->verifyIndexes();
            
            // 6. 对比迁移前后数据量
            $this->compareDataCounts();
            
            // 7. 验证备份表
            $this->verifyBackupTables();
            
            echo "\n✅ 迁移验证完成！所有检查都通过了。\n";
            
        } catch (Exception $e) {
            echo "\n❌ 迁移验证失败：" . $e->getMessage() . "\n";
            exit(1);
        }
    }
    
    /**
     * 检查数据库版本
     */
    private function checkDatabaseVersion() {
        echo "📋 检查数据库版本...\n";
        
        $dbVersion = Database::getInstance()->getDatabaseVersion();
        
        if ($dbVersion['type'] !== 'user_system') {
            throw new Exception("数据库版本不正确，期望：user_system，实际：{$dbVersion['type']}");
        }
        
        echo "  ✓ 数据库版本：{$dbVersion['version']} ({$dbVersion['description']})\n";
    }
    
    /**
     * 验证表结构
     */
    private function verifyTableStructure() {
        echo "🏗️  验证表结构...\n";
        
        $requiredTables = [
            'users' => [
                'id', 'user_uuid', 'user_name', 'email', 'password_hash',
                'created_at', 'updated_at', 'last_active_at'
            ],
            'devices' => [
                'id', 'device_uuid', 'user_id', 'device_name', 'platform',
                'last_sync_timestamp', 'created_at', 'updated_at', 'is_active'
            ],
            'pomodoro_events' => [
                'id', 'uuid', 'user_id', 'device_id', 'title', 'start_time',
                'end_time', 'event_type', 'is_completed', 'created_at',
                'updated_at', 'deleted_at', 'last_modified_device_id'
            ],
            'system_events' => [
                'id', 'uuid', 'user_id', 'device_id', 'event_type',
                'timestamp', 'data', 'created_at', 'deleted_at'
            ],
            'timer_settings' => [
                'id', 'user_id', 'device_id', 'setting_key',
                'setting_value', 'updated_at', 'is_global'
            ],
            'user_sessions' => [
                'id', 'user_id', 'device_id', 'session_token',
                'expires_at', 'created_at', 'last_used_at', 'is_active'
            ]
        ];
        
        foreach ($requiredTables as $tableName => $expectedColumns) {
            $this->verifyTableColumns($tableName, $expectedColumns);
        }
        
        echo "  ✓ 所有表结构验证通过\n";
    }
    
    /**
     * 验证表的列结构
     */
    private function verifyTableColumns($tableName, $expectedColumns) {
        $stmt = $this->db->prepare("PRAGMA table_info($tableName)");
        $stmt->execute();
        $columns = $stmt->fetchAll();
        
        if (empty($columns)) {
            throw new Exception("表 $tableName 不存在");
        }
        
        $actualColumns = array_column($columns, 'name');
        
        foreach ($expectedColumns as $expectedColumn) {
            if (!in_array($expectedColumn, $actualColumns)) {
                throw new Exception("表 $tableName 缺少列：$expectedColumn");
            }
        }
        
        echo "    ✓ 表 $tableName 结构正确\n";
    }
    
    /**
     * 验证数据完整性
     */
    private function verifyDataIntegrity() {
        echo "🔍 验证数据完整性...\n";
        
        // 检查用户表
        $userCount = $this->db->query("SELECT COUNT(*) FROM users")->fetchColumn();
        echo "  - 用户数量：$userCount\n";
        
        // 检查设备表
        $deviceCount = $this->db->query("SELECT COUNT(*) FROM devices")->fetchColumn();
        echo "  - 设备数量：$deviceCount\n";
        
        // 检查番茄事件表
        $eventCount = $this->db->query("SELECT COUNT(*) FROM pomodoro_events")->fetchColumn();
        echo "  - 番茄事件数量：$eventCount\n";
        
        // 检查系统事件表
        $systemEventCount = $this->db->query("SELECT COUNT(*) FROM system_events")->fetchColumn();
        echo "  - 系统事件数量：$systemEventCount\n";
        
        // 检查计时器设置表
        $settingsCount = $this->db->query("SELECT COUNT(*) FROM timer_settings")->fetchColumn();
        echo "  - 计时器设置数量：$settingsCount\n";
        
        if ($userCount == 0 && $deviceCount > 0) {
            throw new Exception("发现设备但没有用户，数据不一致");
        }
        
        echo "  ✓ 数据完整性检查通过\n";
    }
    
    /**
     * 验证外键关系
     */
    private function verifyForeignKeys() {
        echo "🔗 验证外键关系...\n";
        
        // 检查设备的用户关联
        $orphanDevices = $this->db->query("
            SELECT COUNT(*) 
            FROM devices d 
            LEFT JOIN users u ON d.user_id = u.id 
            WHERE u.id IS NULL
        ")->fetchColumn();
        
        if ($orphanDevices > 0) {
            throw new Exception("发现 $orphanDevices 个孤立的设备记录");
        }
        
        // 检查番茄事件的用户关联
        $orphanEvents = $this->db->query("
            SELECT COUNT(*) 
            FROM pomodoro_events pe 
            LEFT JOIN users u ON pe.user_id = u.id 
            WHERE u.id IS NULL
        ")->fetchColumn();
        
        if ($orphanEvents > 0) {
            throw new Exception("发现 $orphanEvents 个孤立的番茄事件记录");
        }
        
        // 检查系统事件的用户关联
        $orphanSystemEvents = $this->db->query("
            SELECT COUNT(*) 
            FROM system_events se 
            LEFT JOIN users u ON se.user_id = u.id 
            WHERE u.id IS NULL
        ")->fetchColumn();
        
        if ($orphanSystemEvents > 0) {
            throw new Exception("发现 $orphanSystemEvents 个孤立的系统事件记录");
        }
        
        echo "  ✓ 外键关系验证通过\n";
    }
    
    /**
     * 验证索引
     */
    private function verifyIndexes() {
        echo "📊 验证索引...\n";
        
        $requiredIndexes = [
            'idx_users_uuid',
            'idx_devices_user_id',
            'idx_devices_uuid',
            'idx_pomodoro_events_user_updated',
            'idx_pomodoro_events_uuid',
            'idx_system_events_user_timestamp',
            'idx_system_events_uuid',
            'idx_timer_settings_user',
            'idx_user_sessions_token'
        ];
        
        $stmt = $this->db->query("SELECT name FROM sqlite_master WHERE type='index'");
        $actualIndexes = $stmt->fetchAll(PDO::FETCH_COLUMN);
        
        foreach ($requiredIndexes as $indexName) {
            if (!in_array($indexName, $actualIndexes)) {
                echo "  ⚠️  警告：缺少索引 $indexName\n";
            } else {
                echo "    ✓ 索引 $indexName 存在\n";
            }
        }
    }
    
    /**
     * 对比迁移前后数据量
     */
    private function compareDataCounts() {
        echo "📈 对比迁移前后数据量...\n";
        
        $backupTables = ['devices_backup', 'pomodoro_events_backup', 'system_events_backup', 'timer_settings_backup'];
        
        foreach ($backupTables as $backupTable) {
            $newTable = str_replace('_backup', '', $backupTable);
            
            if ($this->tableExists($backupTable)) {
                $backupCount = $this->db->query("SELECT COUNT(*) FROM $backupTable")->fetchColumn();
                $newCount = $this->db->query("SELECT COUNT(*) FROM $newTable")->fetchColumn();
                
                echo "  - $newTable: 迁移前 $backupCount，迁移后 $newCount";
                
                if ($backupCount == $newCount) {
                    echo " ✓\n";
                } else {
                    echo " ⚠️  数量不匹配\n";
                }
            }
        }
    }
    
    /**
     * 验证备份表
     */
    private function verifyBackupTables() {
        echo "💾 验证备份表...\n";
        
        $backupTables = ['devices_backup', 'pomodoro_events_backup', 'system_events_backup', 'timer_settings_backup'];
        
        foreach ($backupTables as $table) {
            if ($this->tableExists($table)) {
                $count = $this->db->query("SELECT COUNT(*) FROM $table")->fetchColumn();
                echo "  ✓ 备份表 $table 存在，包含 $count 条记录\n";
            } else {
                echo "  ⚠️  警告：备份表 $table 不存在\n";
            }
        }
    }
    
    /**
     * 检查表是否存在
     */
    private function tableExists($tableName) {
        $stmt = $this->db->prepare("SELECT name FROM sqlite_master WHERE type='table' AND name=?");
        $stmt->execute([$tableName]);
        return $stmt->fetch() !== false;
    }
}

// 执行验证
try {
    $verifier = new MigrationVerifier();
    $verifier->verify();
} catch (Exception $e) {
    echo "错误：" . $e->getMessage() . "\n";
    exit(1);
}
?>
