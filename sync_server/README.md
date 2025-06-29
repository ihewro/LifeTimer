# 番茄钟云同步服务

## 快速部署

### 1. 环境要求
- PHP 7.4 或更高版本
- SQLite3 支持
- Web服务器（Apache/Nginx）

### 2. 部署步骤

1. **上传文件**
   ```bash
   # 将 sync_server 目录上传到你的服务器
   scp -r sync_server/ user@your-server.com:/var/www/html/
   ```

2. **设置权限**
   ```bash
   # 确保数据库目录可写
   chmod 755 /var/www/html/sync_server/database/
   chmod 666 /var/www/html/sync_server/database/pomodoro_sync.db  # 如果数据库文件已存在
   
   # 确保日志目录可写
   mkdir -p /var/www/html/sync_server/logs/
   chmod 755 /var/www/html/sync_server/logs/
   ```

3. **配置Web服务器**

   **Apache (.htaccess)**
   ```apache
   RewriteEngine On
   RewriteCond %{REQUEST_FILENAME} !-f
   RewriteCond %{REQUEST_FILENAME} !-d
   RewriteRule ^(.*)$ index.php [QSA,L]
   ```

   **Nginx**
   ```nginx
   location /sync_server/ {
       try_files $uri $uri/ /sync_server/index.php?$query_string;
   }
   ```

4. **测试部署**
   ```bash
   curl http://your-server.com/sync_server/api/health
   ```
   
   应该返回：
   ```json
   {
       "success": true,
       "data": {
           "status": "ok",
           "timestamp": 1703123456789
       },
       "timestamp": 1703123456789
   }
   ```

### 3. 客户端配置

在你的 macOS 应用中：

```swift
// 在 PomodoroTimerApp.swift 中添加
@StateObject private var syncManager = SyncManager(serverURL: "http://your-server.com/sync_server")

// 在 ContentView 中注入依赖
.environmentObject(syncManager)
.onAppear {
    syncManager.setDependencies(
        eventManager: eventManager,
        activityMonitor: activityMonitor,
        timerModel: timerModel
    )
    
    Task {
        await syncManager.registerDevice()
        await syncManager.performFullSync()
    }
}
```

## API 接口文档

### 1. 设备注册
```
POST /api/device/register
Content-Type: application/json

{
    "device_uuid": "550e8400-e29b-41d4-a716-446655440000",
    "device_name": "MacBook Pro",
    "platform": "macOS"
}
```

### 2. 全量同步
```
GET /api/sync/full?device_uuid={uuid}
```

### 3. 增量同步
```
POST /api/sync/incremental
Content-Type: application/json

{
    "device_uuid": "550e8400-e29b-41d4-a716-446655440000",
    "last_sync_timestamp": 1703120000000,
    "changes": {
        "pomodoro_events": {
            "created": [...],
            "updated": [...],
            "deleted": ["uuid1", "uuid2"]
        },
        "system_events": {
            "created": [...]
        },
        "timer_settings": {...}
    }
}
```

### 4. 健康检查
```
GET /api/health
```

## 数据库管理

### 查看数据库
```bash
sqlite3 /var/www/html/sync_server/database/pomodoro_sync.db

# 查看表结构
.schema

# 查看设备列表
SELECT * FROM devices;

# 查看同步统计
SELECT 
    d.device_name,
    d.platform,
    COUNT(pe.id) as pomodoro_count,
    COUNT(se.id) as system_event_count,
    d.last_sync_timestamp
FROM devices d
LEFT JOIN pomodoro_events pe ON d.device_uuid = pe.device_uuid
LEFT JOIN system_events se ON d.device_uuid = se.device_uuid
GROUP BY d.device_uuid;
```

### 备份数据库
```bash
# 创建备份
cp /var/www/html/sync_server/database/pomodoro_sync.db \
   /var/www/html/sync_server/database/backup_$(date +%Y%m%d_%H%M%S).db

# 定期备份（添加到 crontab）
0 2 * * * cp /var/www/html/sync_server/database/pomodoro_sync.db /var/www/html/sync_server/database/backup_$(date +\%Y\%m\%d).db
```

### 清理旧数据
```sql
-- 删除30天前的系统事件
DELETE FROM system_events 
WHERE timestamp < (strftime('%s', 'now', '-30 days') * 1000);

-- 删除已标记删除超过7天的番茄事件
DELETE FROM pomodoro_events 
WHERE deleted_at IS NOT NULL 
AND deleted_at < (strftime('%s', 'now', '-7 days') * 1000);
```

## 监控和日志

### 查看日志
```bash
tail -f /var/www/html/sync_server/logs/sync.log
```

### 常见问题

1. **数据库权限错误**
   ```bash
   chmod 666 /var/www/html/sync_server/database/pomodoro_sync.db
   chmod 755 /var/www/html/sync_server/database/
   ```

2. **PHP错误**
   - 检查 PHP 错误日志
   - 确保 SQLite3 扩展已安装

3. **同步冲突**
   - 查看日志中的冲突记录
   - 冲突采用"最后写入获胜"策略

## 安全建议

1. **HTTPS**: 在生产环境中使用 HTTPS
2. **访问控制**: 限制对数据库文件的直接访问
3. **备份**: 定期备份数据库
4. **监控**: 监控 API 调用频率和错误率

## 扩展功能

### 添加用户认证
如果需要多用户支持，可以添加用户表和认证机制：

```sql
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 在设备表中添加用户关联
ALTER TABLE devices ADD COLUMN user_id INTEGER REFERENCES users(id);
```

### 添加数据统计API
```php
// 在 api/ 目录下添加 stats.php
GET /api/stats?device_uuid={uuid}&date={YYYY-MM-DD}
```

### 添加数据导出功能
```php
// 导出用户所有数据
GET /api/export?device_uuid={uuid}&format=json
```
