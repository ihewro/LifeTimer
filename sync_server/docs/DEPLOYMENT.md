# 用户账户同步系统部署指南

## 系统要求

- PHP 8.0 或更高版本
- SQLite 3.x 或 MySQL 5.7+
- Web服务器（Apache/Nginx/PHP内置服务器）
- 支持 JSON 和 PDO 扩展

## 快速部署

### 1. 环境准备

```bash
# 克隆项目
git clone <repository-url>
cd sync_server

# 确保目录权限
chmod 755 .
chmod 666 database/
chmod 666 logs/
```

### 2. 数据库初始化

```bash
# 使用 SQLite（推荐用于开发和小规模部署）
cd database
sqlite3 pomodoro_sync.db < schema.sql

# 或使用 MySQL
mysql -u username -p database_name < schema.sql
```

### 3. 配置数据库连接

编辑 `config/database.php`：

```php
<?php
// SQLite 配置（默认）
return [
    'type' => 'sqlite',
    'path' => __DIR__ . '/../database/pomodoro_sync.db'
];

// 或 MySQL 配置
return [
    'type' => 'mysql',
    'host' => 'localhost',
    'dbname' => 'pomodoro_sync',
    'username' => 'your_username',
    'password' => 'your_password',
    'charset' => 'utf8mb4'
];
?>
```

### 4. 启动服务

#### 开发环境（PHP 内置服务器）
```bash
php -S localhost:8080 router.php
```

#### 生产环境（Apache）
```apache
<VirtualHost *:80>
    DocumentRoot /path/to/sync_server
    ServerName your-domain.com
    
    <Directory /path/to/sync_server>
        AllowOverride All
        Require all granted
    </Directory>
    
    # 重写规则
    RewriteEngine On
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteCond %{REQUEST_FILENAME} !-d
    RewriteRule ^(.*)$ index.php [QSA,L]
</VirtualHost>
```

#### 生产环境（Nginx）
```nginx
server {
    listen 80;
    server_name your-domain.com;
    root /path/to/sync_server;
    index index.php;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.0-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
```

## API 端点

### 认证相关
- `POST /api/auth/device-init` - 设备初始化
- `POST /api/auth/device-bind` - 设备绑定
- `POST /api/auth/refresh` - Token 刷新
- `POST /api/auth/logout` - 用户登出

### 同步相关
- `GET /api/user/sync/full` - 全量同步
- `POST /api/user/sync/incremental` - 增量同步
- `POST /api/user/sync/migrate` - 数据迁移

### 用户管理
- `GET /api/user/profile` - 获取用户信息
- `GET /api/user/devices` - 获取用户设备列表
- `DELETE /api/user/devices/{device_uuid}` - 删除设备

### 健康检查
- `GET /api/health` - 服务健康状态

## 测试部署

### 1. 健康检查
```bash
curl http://localhost:8080/api/health
```

预期响应：
```json
{
    "success": true,
    "data": {
        "status": "ok",
        "timestamp": 1703123456789
    }
}
```

### 2. 设备初始化测试
```bash
curl -X POST http://localhost:8080/api/auth/device-init \
  -H "Content-Type: application/json" \
  -d '{
    "device_uuid": "test-device-001",
    "device_name": "Test Device",
    "platform": "macOS"
  }'
```

## 安全配置

### 1. HTTPS 配置
生产环境必须使用 HTTPS：

```apache
# Apache SSL 配置
<VirtualHost *:443>
    SSLEngine on
    SSLCertificateFile /path/to/certificate.crt
    SSLCertificateKeyFile /path/to/private.key
    # ... 其他配置
</VirtualHost>
```

### 2. 防火墙设置
```bash
# 只允许必要端口
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable
```

### 3. 文件权限
```bash
# 设置安全的文件权限
find . -type f -exec chmod 644 {} \;
find . -type d -exec chmod 755 {} \;
chmod 600 config/database.php
```

## 监控和维护

### 1. 日志监控
```bash
# 查看同步日志
tail -f logs/sync.log

# 查看错误日志
tail -f logs/error.log
```

### 2. 数据库维护
```bash
# SQLite 数据库优化
sqlite3 database/pomodoro_sync.db "VACUUM;"

# 清理过期会话
sqlite3 database/pomodoro_sync.db "DELETE FROM user_sessions WHERE expires_at < datetime('now');"
```

### 3. 备份策略
```bash
# 数据库备份脚本
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
cp database/pomodoro_sync.db backups/pomodoro_sync_$DATE.db
find backups/ -name "*.db" -mtime +7 -delete
```

## 故障排除

### 常见问题

1. **数据库连接失败**
   - 检查 `config/database.php` 配置
   - 确认数据库文件权限
   - 验证 PDO 扩展是否安装

2. **API 返回 404**
   - 检查 URL 重写规则
   - 确认 `index.php` 可访问
   - 查看服务器错误日志

3. **认证失败**
   - 检查 Token 格式和有效期
   - 确认用户会话表数据
   - 验证时间同步

### 调试模式
在 `config/database.php` 中启用调试：

```php
return [
    'debug' => true,
    // ... 其他配置
];
```

## 性能优化

### 1. 数据库优化
- 定期执行 `VACUUM` 清理
- 监控索引使用情况
- 考虑分区大表

### 2. 缓存策略
- 使用 Redis 缓存用户会话
- 实现 API 响应缓存
- 静态资源 CDN 加速

### 3. 负载均衡
- 多实例部署
- 数据库读写分离
- API 网关限流

## 版本升级

### 数据库迁移
```bash
# 备份现有数据
cp database/pomodoro_sync.db database/pomodoro_sync_backup.db

# 应用新的架构变更
sqlite3 database/pomodoro_sync.db < database/migrations/v2.0.sql
```

### 滚动更新
1. 部署新版本到备用服务器
2. 切换流量到新服务器
3. 验证功能正常
4. 停用旧服务器
