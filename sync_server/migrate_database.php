<?php
/**
 * 数据库迁移脚本：从设备隔离改为用户账户系统
 * 
 * 使用方法：
 * php migrate_database.php [--dry-run] [--backup-dir=/path/to/backup]
 * 
 * 参数：
 * --dry-run: 只检查不执行迁移
 * --backup-dir: 指定备份目录（默认为./backups）
 */

require_once 'config/database.php';
require_once 'includes/functions.php';

class DatabaseMigrator {
    private $db;
    private $backupDir;
    private $isDryRun;
    
    public function __construct($backupDir = './backups', $isDryRun = false) {
        $this->db = getDB();
        $this->backupDir = $backupDir;
        $this->isDryRun = $isDryRun;
        
        // 确保备份目录存在
        if (!is_dir($this->backupDir)) {
            mkdir($this->backupDir, 0755, true);
        }
    }
    
    /**
     * 执行完整的迁移流程
     */
    public function migrate() {
        try {
            echo "🚀 开始数据库迁移：从设备隔离改为用户账户系统\n";
            echo "时间：" . date('Y-m-d H:i:s') . "\n";
            echo "模式：" . ($this->isDryRun ? "预演模式（不会实际修改数据）" : "正式迁移") . "\n\n";
            
            // 1. 检查当前数据库状态
            $this->checkCurrentState();
            
            // 2. 创建备份
            if (!$this->isDryRun) {
                $this->createBackup();
            }
            
            // 3. 检查迁移前置条件
            $this->checkPrerequisites();
            
            // 4. 执行迁移
            if (!$this->isDryRun) {
                $this->executeMigration();
            } else {
                echo "📋 预演模式：跳过实际迁移执行\n";
            }
            
            // 5. 验证迁移结果
            if (!$this->isDryRun) {
                $this->verifyMigration();
            }
            
            echo "\n✅ 迁移完成！\n";
            
        } catch (Exception $e) {
            echo "\n❌ 迁移失败：" . $e->getMessage() . "\n";
            if (!$this->isDryRun) {
                echo "请检查备份文件并考虑回滚操作\n";
            }
            exit(1);
        }
    }
    
    /**
     * 检查当前数据库状态
     */
    private function checkCurrentState() {
        echo "📊 检查当前数据库状态...\n";
        
        // 检查是否已经迁移过
        $tables = $this->db->query("SELECT name FROM sqlite_master WHERE type='table'")->fetchAll(PDO::FETCH_COLUMN);
        
        if (in_array('users', $tables)) {
            throw new Exception("检测到users表已存在，可能已经迁移过了");
        }
        
        // 统计当前数据
        $deviceCount = $this->db->query("SELECT COUNT(*) FROM devices")->fetchColumn();
        $eventCount = $this->db->query("SELECT COUNT(*) FROM pomodoro_events")->fetchColumn();
        $systemEventCount = $this->db->query("SELECT COUNT(*) FROM system_events")->fetchColumn();
        $settingsCount = $this->db->query("SELECT COUNT(*) FROM timer_settings")->fetchColumn();
        
        echo "  - 设备数量: $deviceCount\n";
        echo "  - 番茄事件数量: $eventCount\n";
        echo "  - 系统事件数量: $systemEventCount\n";
        echo "  - 计时器设置数量: $settingsCount\n\n";
        
        if ($deviceCount == 0) {
            echo "⚠️  警告：没有发现任何设备数据，迁移可能不必要\n";
        }
    }
    
    /**
     * 创建数据库备份
     */
    private function createBackup() {
        echo "💾 创建数据库备份...\n";
        
        $timestamp = date('Y-m-d_H-i-s');
        $backupFile = $this->backupDir . "/database_backup_$timestamp.db";
        
        // 获取数据库文件路径
        $dbPath = $this->getDatabasePath();
        
        if (!copy($dbPath, $backupFile)) {
            throw new Exception("备份创建失败");
        }
        
        echo "  备份文件: $backupFile\n";
        echo "  备份大小: " . $this->formatBytes(filesize($backupFile)) . "\n\n";
    }
    
    /**
     * 检查迁移前置条件
     */
    private function checkPrerequisites() {
        echo "🔍 检查迁移前置条件...\n";
        
        // 检查磁盘空间（需要至少2倍的数据库大小）
        $dbPath = $this->getDatabasePath();
        $dbSize = filesize($dbPath);
        $freeSpace = disk_free_space(dirname($dbPath));
        
        if ($freeSpace < $dbSize * 2) {
            throw new Exception("磁盘空间不足，需要至少 " . $this->formatBytes($dbSize * 2));
        }
        
        // 检查数据完整性
        $this->checkDataIntegrity();
        
        echo "  ✓ 磁盘空间充足\n";
        echo "  ✓ 数据完整性检查通过\n\n";
    }
    
    /**
     * 执行迁移
     */
    private function executeMigration() {
        echo "🔄 执行数据库迁移...\n";
        
        // 读取迁移SQL文件
        $migrationSQL = file_get_contents(__DIR__ . '/database/migrate_to_user_system.sql');
        
        if (!$migrationSQL) {
            throw new Exception("无法读取迁移SQL文件");
        }
        
        // 执行迁移
        $this->db->exec($migrationSQL);
        
        echo "  ✓ 迁移SQL执行完成\n\n";
    }
    
    /**
     * 验证迁移结果
     */
    private function verifyMigration() {
        echo "✅ 验证迁移结果...\n";
        
        // 检查新表是否存在
        $tables = $this->db->query("SELECT name FROM sqlite_master WHERE type='table'")->fetchAll(PDO::FETCH_COLUMN);
        $requiredTables = ['users', 'devices', 'pomodoro_events', 'system_events', 'timer_settings', 'user_sessions'];
        
        foreach ($requiredTables as $table) {
            if (!in_array($table, $tables)) {
                throw new Exception("表 $table 不存在");
            }
        }
        
        // 检查数据数量
        $userCount = $this->db->query("SELECT COUNT(*) FROM users")->fetchColumn();
        $deviceCount = $this->db->query("SELECT COUNT(*) FROM devices")->fetchColumn();
        $eventCount = $this->db->query("SELECT COUNT(*) FROM pomodoro_events")->fetchColumn();
        
        echo "  - 用户数量: $userCount\n";
        echo "  - 设备数量: $deviceCount\n";
        echo "  - 番茄事件数量: $eventCount\n";
        
        // 检查备份表是否存在
        $backupTables = ['devices_backup', 'pomodoro_events_backup', 'system_events_backup', 'timer_settings_backup'];
        foreach ($backupTables as $table) {
            if (!in_array($table, $tables)) {
                echo "  ⚠️  警告：备份表 $table 不存在\n";
            }
        }
        
        echo "  ✓ 迁移验证通过\n\n";
    }
    
    /**
     * 检查数据完整性
     */
    private function checkDataIntegrity() {
        // 检查是否有重复的device_uuid
        $duplicates = $this->db->query("
            SELECT device_uuid, COUNT(*) as count 
            FROM devices 
            GROUP BY device_uuid 
            HAVING COUNT(*) > 1
        ")->fetchAll();
        
        if (!empty($duplicates)) {
            throw new Exception("发现重复的device_uuid，请先清理数据");
        }
        
        // 检查外键完整性
        $orphanEvents = $this->db->query("
            SELECT COUNT(*) 
            FROM pomodoro_events pe 
            LEFT JOIN devices d ON pe.device_uuid = d.device_uuid 
            WHERE d.device_uuid IS NULL
        ")->fetchColumn();
        
        if ($orphanEvents > 0) {
            throw new Exception("发现 $orphanEvents 个孤立的番茄事件记录");
        }
    }
    
    /**
     * 获取数据库文件路径
     */
    private function getDatabasePath() {
        // 从PDO连接中获取数据库路径
        $dsn = $this->db->getAttribute(PDO::ATTR_CONNECTION_STATUS);
        // 这里需要根据实际的数据库配置来获取路径
        return __DIR__ . '/database/sync.db'; // 假设的路径
    }
    
    /**
     * 格式化字节大小
     */
    private function formatBytes($bytes, $precision = 2) {
        $units = array('B', 'KB', 'MB', 'GB', 'TB');
        
        for ($i = 0; $bytes > 1024; $i++) {
            $bytes /= 1024;
        }
        
        return round($bytes, $precision) . ' ' . $units[$i];
    }
}

// 解析命令行参数
$isDryRun = in_array('--dry-run', $argv);
$backupDir = './backups';

foreach ($argv as $arg) {
    if (strpos($arg, '--backup-dir=') === 0) {
        $backupDir = substr($arg, 13);
    }
}

// 执行迁移
try {
    $migrator = new DatabaseMigrator($backupDir, $isDryRun);
    $migrator->migrate();
} catch (Exception $e) {
    echo "错误：" . $e->getMessage() . "\n";
    exit(1);
}
?>
