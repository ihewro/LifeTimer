-- 数据库迁移脚本：从设备隔离改为用户账户系统
-- 执行前请备份现有数据库！

-- 开始事务
BEGIN TRANSACTION;

-- 1. 创建用户表
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_uuid VARCHAR(36) UNIQUE NOT NULL,
    user_name VARCHAR(100),
    email VARCHAR(255),
    password_hash VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_active_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. 为每个现有设备创建对应的用户
-- 这里采用一对一迁移策略：每个设备对应一个用户
INSERT INTO users (user_uuid, user_name, created_at, updated_at, last_active_at)
SELECT 
    device_uuid as user_uuid,
    device_name as user_name,
    created_at,
    updated_at,
    updated_at as last_active_at
FROM devices
WHERE device_uuid NOT IN (SELECT user_uuid FROM users);

-- 3. 备份原始表
CREATE TABLE devices_backup AS SELECT * FROM devices;
CREATE TABLE pomodoro_events_backup AS SELECT * FROM pomodoro_events;
CREATE TABLE system_events_backup AS SELECT * FROM system_events;
CREATE TABLE timer_settings_backup AS SELECT * FROM timer_settings;

-- 4. 创建新的设备表结构
DROP TABLE IF EXISTS devices_new;
CREATE TABLE devices_new (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_uuid VARCHAR(36) UNIQUE NOT NULL,
    user_id INTEGER NOT NULL,
    device_name VARCHAR(100),
    platform VARCHAR(20),
    last_sync_timestamp BIGINT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT 1,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 5. 迁移设备数据（关联到对应的用户）
INSERT INTO devices_new (device_uuid, user_id, device_name, platform, last_sync_timestamp, created_at, updated_at, is_active)
SELECT 
    d.device_uuid,
    u.id as user_id,
    d.device_name,
    d.platform,
    d.last_sync_timestamp,
    d.created_at,
    d.updated_at,
    1 as is_active
FROM devices d
JOIN users u ON d.device_uuid = u.user_uuid;

-- 6. 创建新的番茄事件表结构
DROP TABLE IF EXISTS pomodoro_events_new;
CREATE TABLE pomodoro_events_new (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    uuid VARCHAR(36) UNIQUE NOT NULL,
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
    FOREIGN KEY (device_id) REFERENCES devices_new(id) ON DELETE SET NULL,
    FOREIGN KEY (last_modified_device_id) REFERENCES devices_new(id) ON DELETE SET NULL
);

-- 7. 迁移番茄事件数据
INSERT INTO pomodoro_events_new (
    uuid, user_id, device_id, title, start_time, end_time, 
    event_type, is_completed, created_at, updated_at, deleted_at, last_modified_device_id
)
SELECT 
    pe.uuid,
    u.id as user_id,
    dn.id as device_id,
    pe.title,
    pe.start_time,
    pe.end_time,
    pe.event_type,
    pe.is_completed,
    pe.created_at,
    pe.updated_at,
    pe.deleted_at,
    dn.id as last_modified_device_id
FROM pomodoro_events pe
JOIN users u ON pe.device_uuid = u.user_uuid
JOIN devices_new dn ON pe.device_uuid = dn.device_uuid;

-- 8. 创建新的系统事件表结构
DROP TABLE IF EXISTS system_events_new;
CREATE TABLE system_events_new (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    uuid VARCHAR(36) UNIQUE NOT NULL,
    user_id INTEGER NOT NULL,
    device_id INTEGER,
    event_type VARCHAR(30) NOT NULL,
    timestamp BIGINT NOT NULL,
    data TEXT,
    created_at BIGINT NOT NULL,
    deleted_at BIGINT DEFAULT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (device_id) REFERENCES devices_new(id) ON DELETE SET NULL
);

-- 9. 迁移系统事件数据
INSERT INTO system_events_new (
    uuid, user_id, device_id, event_type, timestamp, data, created_at, deleted_at
)
SELECT 
    se.uuid,
    u.id as user_id,
    dn.id as device_id,
    se.event_type,
    se.timestamp,
    se.data,
    se.created_at,
    se.deleted_at
FROM system_events se
JOIN users u ON se.device_uuid = u.user_uuid
JOIN devices_new dn ON se.device_uuid = dn.device_uuid;

-- 10. 创建新的计时器设置表结构
DROP TABLE IF EXISTS timer_settings_new;
CREATE TABLE timer_settings_new (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    device_id INTEGER,
    pomodoro_time INTEGER DEFAULT 1500,
    short_break_time INTEGER DEFAULT 300,
    long_break_time INTEGER DEFAULT 900,
    updated_at BIGINT NOT NULL,
    is_global BOOLEAN DEFAULT 1,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (device_id) REFERENCES devices_new(id) ON DELETE CASCADE,
    UNIQUE(user_id, device_id)
);

-- 11. 迁移计时器设置数据
INSERT INTO timer_settings_new (
    user_id, device_id, pomodoro_time, short_break_time, long_break_time, updated_at, is_global
)
SELECT 
    u.id as user_id,
    dn.id as device_id,
    ts.pomodoro_time,
    ts.short_break_time,
    ts.long_break_time,
    ts.updated_at,
    1 as is_global
FROM timer_settings ts
JOIN users u ON ts.device_uuid = u.user_uuid
JOIN devices_new dn ON ts.device_uuid = dn.device_uuid;

-- 12. 创建用户会话表
CREATE TABLE IF NOT EXISTS user_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    device_id INTEGER NOT NULL,
    session_token VARCHAR(255) UNIQUE NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_used_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT 1,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (device_id) REFERENCES devices_new(id) ON DELETE CASCADE
);

-- 13. 替换原表
DROP TABLE devices;
DROP TABLE pomodoro_events;
DROP TABLE system_events;
DROP TABLE timer_settings;

ALTER TABLE devices_new RENAME TO devices;
ALTER TABLE pomodoro_events_new RENAME TO pomodoro_events;
ALTER TABLE system_events_new RENAME TO system_events;
ALTER TABLE timer_settings_new RENAME TO timer_settings;

-- 14. 创建索引
CREATE INDEX IF NOT EXISTS idx_users_uuid ON users(user_uuid);
CREATE INDEX IF NOT EXISTS idx_devices_user_id ON devices(user_id);
CREATE INDEX IF NOT EXISTS idx_devices_uuid ON devices(device_uuid);

CREATE INDEX IF NOT EXISTS idx_pomodoro_events_user_updated ON pomodoro_events(user_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_pomodoro_events_uuid ON pomodoro_events(uuid);
CREATE INDEX IF NOT EXISTS idx_pomodoro_events_device ON pomodoro_events(device_id);

CREATE INDEX IF NOT EXISTS idx_system_events_user_timestamp ON system_events(user_id, timestamp);
CREATE INDEX IF NOT EXISTS idx_system_events_uuid ON system_events(uuid);
CREATE INDEX IF NOT EXISTS idx_system_events_device ON system_events(device_id);

CREATE INDEX IF NOT EXISTS idx_timer_settings_user ON timer_settings(user_id);
CREATE INDEX IF NOT EXISTS idx_timer_settings_device ON timer_settings(device_id);

CREATE INDEX IF NOT EXISTS idx_user_sessions_token ON user_sessions(session_token);
CREATE INDEX IF NOT EXISTS idx_user_sessions_user_device ON user_sessions(user_id, device_id);
CREATE INDEX IF NOT EXISTS idx_user_sessions_expires ON user_sessions(expires_at);

-- 15. 创建视图
CREATE VIEW IF NOT EXISTS user_device_summary AS
SELECT 
    u.user_uuid,
    u.user_name,
    COUNT(d.id) as device_count,
    MAX(d.last_sync_timestamp) as last_sync_timestamp,
    u.last_active_at
FROM users u
LEFT JOIN devices d ON u.id = d.user_id AND d.is_active = 1
GROUP BY u.id, u.user_uuid, u.user_name, u.last_active_at;

-- 提交事务
COMMIT;

-- 验证迁移结果
SELECT 'Migration completed successfully' as status;
SELECT COUNT(*) as user_count FROM users;
SELECT COUNT(*) as device_count FROM devices;
SELECT COUNT(*) as pomodoro_event_count FROM pomodoro_events;
SELECT COUNT(*) as system_event_count FROM system_events;
SELECT COUNT(*) as timer_setting_count FROM timer_settings;
