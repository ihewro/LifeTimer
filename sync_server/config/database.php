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
        $schema = file_get_contents(__DIR__ . '/../database/schema.sql');
        if ($schema === false) {
            throw new Exception("Could not read database schema file");
        }
        
        // 执行建表语句
        $statements = explode(';', $schema);
        foreach ($statements as $statement) {
            $statement = trim($statement);
            if (!empty($statement)) {
                $this->pdo->exec($statement);
            }
        }
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
