<?php
class Database {
    private static $instance = null;
    private $pdo;
    
    private function __construct() {
        $db_path = __DIR__ . '/../database/pomodoro_sync.db';
        $db_dir = dirname($db_path);
        
        // 确保数据库目录存在
        if (!is_dir($db_dir)) {
            mkdir($db_dir, 0755, true);
        }
        
        try {
            $this->pdo = new PDO("sqlite:$db_path");
            $this->pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
            $this->pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
            
            // 启用外键约束
            $this->pdo->exec('PRAGMA foreign_keys = ON');
            
            // 初始化数据库结构
            $this->initializeDatabase();
        } catch (PDOException $e) {
            throw new Exception("Database connection failed: " . $e->getMessage());
        }
    }
    
    public static function getInstance() {
        if (self::$instance === null) {
            self::$instance = new self();
        }
        return self::$instance;
    }
    
    public function getConnection() {
        return $this->pdo;
    }
    
    private function initializeDatabase() {
        // 检查是否已经迁移到用户系统
        $hasUserTable = $this->checkTableExists('users');

        if ($hasUserTable) {
            // 使用新的用户系统表结构
            $this->initializeUserSystemTables();
        } else {
            // 使用旧的设备隔离表结构
            $this->initializeLegacyTables();
        }
    }

    private function checkTableExists($tableName) {
        $stmt = $this->pdo->prepare("SELECT name FROM sqlite_master WHERE type='table' AND name=?");
        $stmt->execute([$tableName]);
        return $stmt->fetch() !== false;
    }

    private function initializeUserSystemTables() {
        $schema = file_get_contents(__DIR__ . '/../database/user_schema.sql');
        if ($schema === false) {
            throw new Exception("Could not read user system schema file");
        }

        $this->executeSchemaStatements($schema);
    }

    private function initializeLegacyTables() {
        $schema = file_get_contents(__DIR__ . '/../database/schema.sql');
        if ($schema === false) {
            throw new Exception("Could not read legacy schema file");
        }

        $this->executeSchemaStatements($schema);
    }

    private function executeSchemaStatements($schema) {
        // 执行建表语句
        $statements = explode(';', $schema);
        foreach ($statements as $statement) {
            $statement = trim($statement);
            if (!empty($statement)) {
                try {
                    $this->pdo->exec($statement);
                } catch (PDOException $e) {
                    // 忽略表已存在的错误
                    if (strpos($e->getMessage(), 'already exists') === false) {
                        throw $e;
                    }
                }
            }
        }
    }

    /**
     * 获取数据库版本信息
     */
    public function getDatabaseVersion() {
        if ($this->checkTableExists('users')) {
            return [
                'version' => '2.0',
                'type' => 'user_system',
                'description' => '基于用户账户的同步系统'
            ];
        } else {
            return [
                'version' => '1.0',
                'type' => 'device_isolation',
                'description' => '基于设备隔离的同步系统'
            ];
        }
    }

    /**
     * 检查是否需要迁移
     */
    public function needsMigration() {
        return !$this->checkTableExists('users') && $this->hasLegacyData();
    }

    /**
     * 检查是否有旧版本数据
     */
    private function hasLegacyData() {
        if (!$this->checkTableExists('devices')) {
            return false;
        }

        $stmt = $this->pdo->query("SELECT COUNT(*) FROM devices");
        return $stmt->fetchColumn() > 0;
    }

    // 防止克隆
    private function __clone() {}
    
    // 防止反序列化
    public function __wakeup() {
        throw new Exception("Cannot unserialize singleton");
    }
}

// 全局数据库连接函数
function getDB() {
    return Database::getInstance()->getConnection();
}
?>
