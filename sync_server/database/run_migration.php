<?php
/**
 * 数据库迁移执行脚本
 * 用于安全地执行数据库结构变更
 */

require_once __DIR__ . '/../config/database.php';

class MigrationRunner {
    private $pdo;
    private $migrationsPath;
    
    public function __construct() {
        $this->pdo = getDB();
        $this->migrationsPath = __DIR__ . '/migrations/';
        
        // 创建迁移记录表
        $this->createMigrationsTable();
    }
    
    /**
     * 创建迁移记录表
     */
    private function createMigrationsTable() {
        $sql = "
            CREATE TABLE IF NOT EXISTS migrations (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                migration_name VARCHAR(255) UNIQUE NOT NULL,
                executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                success BOOLEAN DEFAULT 1
            )
        ";
        $this->pdo->exec($sql);
    }
    
    /**
     * 检查迁移是否已执行
     */
    private function isMigrationExecuted($migrationName) {
        $stmt = $this->pdo->prepare("SELECT COUNT(*) FROM migrations WHERE migration_name = ? AND success = 1");
        $stmt->execute([$migrationName]);
        return $stmt->fetchColumn() > 0;
    }
    
    /**
     * 记录迁移执行结果
     */
    private function recordMigration($migrationName, $success = true) {
        $stmt = $this->pdo->prepare("
            INSERT OR REPLACE INTO migrations (migration_name, executed_at, success) 
            VALUES (?, datetime('now'), ?)
        ");
        $stmt->execute([$migrationName, $success ? 1 : 0]);
    }
    
    /**
     * 执行单个迁移文件
     */
    public function runMigration($migrationFile) {
        $migrationName = basename($migrationFile, '.sql');
        
        if ($this->isMigrationExecuted($migrationName)) {
            echo "迁移 {$migrationName} 已经执行过，跳过。\n";
            return true;
        }
        
        echo "开始执行迁移: {$migrationName}\n";
        
        // 创建数据库备份
        $backupFile = $this->createBackup();
        echo "数据库备份已创建: {$backupFile}\n";
        
        try {
            // 读取迁移文件内容
            $migrationContent = file_get_contents($migrationFile);
            if ($migrationContent === false) {
                throw new Exception("无法读取迁移文件: {$migrationFile}");
            }
            
            // 分割SQL语句（简单的分割，基于分号）
            $statements = array_filter(
                array_map('trim', explode(';', $migrationContent)),
                function($stmt) {
                    return !empty($stmt) && 
                           !preg_match('/^\s*--/', $stmt) && 
                           !preg_match('/^\s*\./', $stmt); // 跳过SQLite命令
                }
            );
            
            // 开始事务
            $this->pdo->beginTransaction();
            
            // 执行每个SQL语句
            foreach ($statements as $statement) {
                if (trim($statement)) {
                    echo "执行: " . substr(trim($statement), 0, 50) . "...\n";
                    $this->pdo->exec($statement);
                }
            }
            
            // 提交事务
            $this->pdo->commit();
            
            // 记录成功执行
            $this->recordMigration($migrationName, true);
            
            echo "迁移 {$migrationName} 执行成功！\n";
            return true;
            
        } catch (Exception $e) {
            // 回滚事务
            if ($this->pdo->inTransaction()) {
                $this->pdo->rollBack();
            }
            
            // 记录失败
            $this->recordMigration($migrationName, false);
            
            echo "迁移 {$migrationName} 执行失败: " . $e->getMessage() . "\n";
            echo "数据库已回滚到迁移前状态。\n";
            echo "如需恢复，可使用备份文件: {$backupFile}\n";
            
            return false;
        }
    }
    
    /**
     * 创建数据库备份
     */
    private function createBackup() {
        $dbPath = __DIR__ . '/sync_database.db';
        $backupPath = __DIR__ . '/backups/sync_database_backup_' . date('Y-m-d_H-i-s') . '.db';
        
        // 确保备份目录存在
        $backupDir = dirname($backupPath);
        if (!is_dir($backupDir)) {
            mkdir($backupDir, 0755, true);
        }
        
        if (file_exists($dbPath)) {
            copy($dbPath, $backupPath);
        }
        
        return $backupPath;
    }
    
    /**
     * 执行所有待执行的迁移
     */
    public function runAllMigrations() {
        $migrationFiles = glob($this->migrationsPath . '*.sql');
        sort($migrationFiles); // 按文件名排序执行
        
        $success = true;
        foreach ($migrationFiles as $file) {
            if (!$this->runMigration($file)) {
                $success = false;
                break; // 如果有迁移失败，停止执行后续迁移
            }
        }
        
        return $success;
    }
    
    /**
     * 显示迁移状态
     */
    public function showMigrationStatus() {
        echo "\n=== 迁移状态 ===\n";
        
        $stmt = $this->pdo->query("
            SELECT migration_name, executed_at, success 
            FROM migrations 
            ORDER BY executed_at DESC
        ");
        
        $migrations = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        if (empty($migrations)) {
            echo "没有执行过的迁移记录。\n";
        } else {
            foreach ($migrations as $migration) {
                $status = $migration['success'] ? '✓ 成功' : '✗ 失败';
                echo sprintf(
                    "%-30s %s %s\n",
                    $migration['migration_name'],
                    $status,
                    $migration['executed_at']
                );
            }
        }
        echo "\n";
    }
}

// 命令行执行
if (php_sapi_name() === 'cli') {
    $runner = new MigrationRunner();
    
    $command = $argv[1] ?? 'run';
    
    switch ($command) {
        case 'run':
            echo "开始执行数据库迁移...\n";
            if ($runner->runAllMigrations()) {
                echo "所有迁移执行完成！\n";
            } else {
                echo "迁移执行过程中出现错误。\n";
                exit(1);
            }
            break;
            
        case 'status':
            $runner->showMigrationStatus();
            break;
            
        case 'specific':
            if (!isset($argv[2])) {
                echo "请指定要执行的迁移文件名。\n";
                echo "用法: php run_migration.php specific 001_fix_uuid_constraints.sql\n";
                exit(1);
            }
            $migrationFile = __DIR__ . '/migrations/' . $argv[2];
            if (!file_exists($migrationFile)) {
                echo "迁移文件不存在: {$migrationFile}\n";
                exit(1);
            }
            $runner->runMigration($migrationFile);
            break;
            
        default:
            echo "用法:\n";
            echo "  php run_migration.php run     - 执行所有待执行的迁移\n";
            echo "  php run_migration.php status  - 显示迁移状态\n";
            echo "  php run_migration.php specific <filename> - 执行指定的迁移文件\n";
            break;
    }
}
