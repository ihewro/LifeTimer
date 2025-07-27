<?php
/**
 * UUID约束修复脚本
 * 专门用于修复pomodoro_events和system_events表的UUID唯一约束问题
 * 将单独的uuid UNIQUE约束改为uuid+user_id的组合唯一约束
 */

require_once __DIR__ . '/../config/database.php';

function createBackup($pdo) {
    $dbPath = __DIR__ . '/sync_database.db';
    $backupPath = __DIR__ . '/sync_database_backup_' . date('Y-m-d_H-i-s') . '.db';
    
    if (file_exists($dbPath)) {
        if (copy($dbPath, $backupPath)) {
            echo "✓ 数据库备份已创建: {$backupPath}\n";
            return $backupPath;
        } else {
            throw new Exception("无法创建数据库备份");
        }
    }
    return null;
}

function checkCurrentConstraints($pdo) {
    echo "\n=== 检查当前表结构 ===\n";
    
    // 检查pomodoro_events表结构
    $stmt = $pdo->query("SELECT sql FROM sqlite_master WHERE type='table' AND name='pomodoro_events'");
    $pomodoroSchema = $stmt->fetchColumn();
    echo "pomodoro_events表当前结构:\n";
    echo $pomodoroSchema . "\n\n";
    
    // 检查system_events表结构
    $stmt = $pdo->query("SELECT sql FROM sqlite_master WHERE type='table' AND name='system_events'");
    $systemSchema = $stmt->fetchColumn();
    echo "system_events表当前结构:\n";
    echo $systemSchema . "\n\n";
    
    // 检查是否需要迁移
    $needsMigration = (
        strpos($pomodoroSchema, 'uuid VARCHAR(36) UNIQUE NOT NULL') !== false ||
        strpos($systemSchema, 'uuid VARCHAR(36) UNIQUE NOT NULL') !== false
    );
    
    return $needsMigration;
}

function fixPomodoroEventsTable($pdo) {
    echo "开始修复 pomodoro_events 表...\n";
    
    // 创建新表
    $createNewTable = "
        CREATE TABLE pomodoro_events_new (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            uuid VARCHAR(36) NOT NULL,
            user_id INTEGER NOT NULL,
            device_id INTEGER,
            title VARCHAR(200) NOT NULL,
            start_time BIGINT NOT NULL,
            end_time BIGINT NOT NULL,
            event_type VARCHAR(20) NOT NULL,
            is_completed BOOLEAN DEFAULT 0,
            created_at BIGINT NOT NULL,
            updated_at BIGINT NOT NULL,
            deleted_at BIGINT DEFAULT NULL,
            last_modified_device_id INTEGER,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE SET NULL,
            FOREIGN KEY (last_modified_device_id) REFERENCES devices(id) ON DELETE SET NULL,
            UNIQUE(uuid, user_id)
        )
    ";
    $pdo->exec($createNewTable);
    echo "✓ 创建新的 pomodoro_events_new 表\n";
    
    // 复制数据
    $copyData = "
        INSERT INTO pomodoro_events_new (
            id, uuid, user_id, device_id, title, start_time, end_time, 
            event_type, is_completed, created_at, updated_at, deleted_at, 
            last_modified_device_id
        )
        SELECT 
            id, uuid, user_id, device_id, title, start_time, end_time, 
            event_type, is_completed, created_at, updated_at, deleted_at, 
            last_modified_device_id
        FROM pomodoro_events
    ";
    $pdo->exec($copyData);
    echo "✓ 数据复制完成\n";
    
    // 删除旧表并重命名
    $pdo->exec("DROP TABLE pomodoro_events");
    $pdo->exec("ALTER TABLE pomodoro_events_new RENAME TO pomodoro_events");
    echo "✓ 表重命名完成\n";
}

function fixSystemEventsTable($pdo) {
    echo "开始修复 system_events 表...\n";
    
    // 创建新表
    $createNewTable = "
        CREATE TABLE system_events_new (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            uuid VARCHAR(36) NOT NULL,
            user_id INTEGER NOT NULL,
            device_id INTEGER,
            event_type VARCHAR(30) NOT NULL,
            timestamp BIGINT NOT NULL,
            data TEXT,
            created_at BIGINT NOT NULL,
            deleted_at BIGINT DEFAULT NULL,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE SET NULL,
            UNIQUE(uuid, user_id)
        )
    ";
    $pdo->exec($createNewTable);
    echo "✓ 创建新的 system_events_new 表\n";
    
    // 复制数据
    $copyData = "
        INSERT INTO system_events_new (
            id, uuid, user_id, device_id, event_type, timestamp, 
            data, created_at, deleted_at
        )
        SELECT 
            id, uuid, user_id, device_id, event_type, timestamp, 
            data, created_at, deleted_at
        FROM system_events
    ";
    $pdo->exec($copyData);
    echo "✓ 数据复制完成\n";
    
    // 删除旧表并重命名
    $pdo->exec("DROP TABLE system_events");
    $pdo->exec("ALTER TABLE system_events_new RENAME TO system_events");
    echo "✓ 表重命名完成\n";
}

function recreateIndexes($pdo) {
    echo "重新创建索引...\n";
    
    $indexes = [
        // pomodoro_events 索引
        "CREATE INDEX IF NOT EXISTS idx_pomodoro_events_user_updated ON pomodoro_events(user_id, updated_at)",
        "CREATE INDEX IF NOT EXISTS idx_pomodoro_events_uuid ON pomodoro_events(uuid)",
        "CREATE INDEX IF NOT EXISTS idx_pomodoro_events_device ON pomodoro_events(device_id)",
        "CREATE INDEX IF NOT EXISTS idx_pomodoro_events_uuid_user ON pomodoro_events(uuid, user_id)",
        
        // system_events 索引
        "CREATE INDEX IF NOT EXISTS idx_system_events_user_timestamp ON system_events(user_id, timestamp)",
        "CREATE INDEX IF NOT EXISTS idx_system_events_uuid ON system_events(uuid)",
        "CREATE INDEX IF NOT EXISTS idx_system_events_device ON system_events(device_id)",
        "CREATE INDEX IF NOT EXISTS idx_system_events_uuid_user ON system_events(uuid, user_id)"
    ];
    
    foreach ($indexes as $indexSql) {
        $pdo->exec($indexSql);
    }
    
    echo "✓ 索引重建完成\n";
}

function verifyMigration($pdo) {
    echo "\n=== 验证迁移结果 ===\n";
    
    // 检查新的表结构
    $stmt = $pdo->query("SELECT sql FROM sqlite_master WHERE type='table' AND name='pomodoro_events'");
    $pomodoroSchema = $stmt->fetchColumn();
    
    $stmt = $pdo->query("SELECT sql FROM sqlite_master WHERE type='table' AND name='system_events'");
    $systemSchema = $stmt->fetchColumn();
    
    // 验证约束是否正确
    $pomodoroHasComboConstraint = strpos($pomodoroSchema, 'UNIQUE(uuid, user_id)') !== false;
    $systemHasComboConstraint = strpos($systemSchema, 'UNIQUE(uuid, user_id)') !== false;
    
    if ($pomodoroHasComboConstraint && $systemHasComboConstraint) {
        echo "✓ 迁移成功！两个表都已使用组合唯一约束 (uuid, user_id)\n";
        
        // 检查数据完整性
        $stmt = $pdo->query("SELECT COUNT(*) FROM pomodoro_events");
        $pomodoroCount = $stmt->fetchColumn();
        
        $stmt = $pdo->query("SELECT COUNT(*) FROM system_events");
        $systemCount = $stmt->fetchColumn();
        
        echo "✓ 数据完整性检查:\n";
        echo "  - pomodoro_events: {$pomodoroCount} 条记录\n";
        echo "  - system_events: {$systemCount} 条记录\n";
        
        return true;
    } else {
        echo "✗ 迁移验证失败！约束可能未正确设置\n";
        return false;
    }
}

// 主执行逻辑
try {
    echo "=== UUID约束修复脚本 ===\n";
    echo "此脚本将修复pomodoro_events和system_events表的UUID唯一约束问题\n";
    echo "将单独的uuid UNIQUE约束改为uuid+user_id的组合唯一约束\n\n";
    
    // 连接数据库
    $pdo = getDB();
    echo "✓ 数据库连接成功\n";
    
    // 检查当前约束
    if (!checkCurrentConstraints($pdo)) {
        echo "✓ 表结构已经是正确的，无需迁移\n";
        exit(0);
    }
    
    echo "检测到需要修复的约束，开始迁移...\n";
    
    // 创建备份
    $backupFile = createBackup($pdo);
    
    // 开始事务
    $pdo->beginTransaction();
    
    try {
        // 修复两个表
        fixPomodoroEventsTable($pdo);
        fixSystemEventsTable($pdo);
        
        // 重建索引
        recreateIndexes($pdo);
        
        // 提交事务
        $pdo->commit();
        
        // 验证迁移
        if (verifyMigration($pdo)) {
            echo "\n🎉 UUID约束修复完成！\n";
            echo "现在设备可以在不同用户间切换而不会出现UUID冲突问题。\n";
            if ($backupFile) {
                echo "备份文件保存在: {$backupFile}\n";
            }
        } else {
            throw new Exception("迁移验证失败");
        }
        
    } catch (Exception $e) {
        $pdo->rollBack();
        throw $e;
    }
    
} catch (Exception $e) {
    echo "\n❌ 错误: " . $e->getMessage() . "\n";
    if (isset($backupFile) && $backupFile) {
        echo "可以使用备份文件恢复数据库: {$backupFile}\n";
    }
    exit(1);
}
