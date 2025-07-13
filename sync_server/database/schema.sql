-- 用户账户同步系统数据库架构

-- 用户表
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_uuid VARCHAR(36) UNIQUE NOT NULL,
    user_name VARCHAR(100),
    email VARCHAR(255),
    password_hash VARCHAR(255), -- 可选，用于传统认证
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_active_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 设备表
CREATE TABLE IF NOT EXISTS devices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_uuid VARCHAR(36) UNIQUE NOT NULL,
    user_id INTEGER NOT NULL, -- 关联到用户
    device_name VARCHAR(100),
    platform VARCHAR(20),
    last_sync_timestamp BIGINT DEFAULT 0,
    last_access_timestamp BIGINT DEFAULT 0, -- 最后访问时间（用于数据预览等轻量操作）
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT 1, -- 设备是否活跃
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 番茄事件表
CREATE TABLE IF NOT EXISTS pomodoro_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    uuid VARCHAR(36) UNIQUE NOT NULL,
    user_id INTEGER NOT NULL, -- 主要关联：用户ID
    device_id INTEGER, -- 辅助信息：创建设备（用于冲突解决和审计）
    title VARCHAR(200) NOT NULL,
    start_time BIGINT NOT NULL,
    end_time BIGINT NOT NULL,
    event_type VARCHAR(20) NOT NULL,
    is_completed BOOLEAN DEFAULT 0,
    created_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL,
    deleted_at BIGINT DEFAULT NULL,
    last_modified_device_id INTEGER, -- 最后修改的设备
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE SET NULL,
    FOREIGN KEY (last_modified_device_id) REFERENCES devices(id) ON DELETE SET NULL
);

-- 系统事件表
CREATE TABLE IF NOT EXISTS system_events (
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
    FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE SET NULL
);

-- 计时器设置表
CREATE TABLE IF NOT EXISTS timer_settings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    device_id INTEGER, -- NULL表示全局设置，非NULL表示设备特定设置
    pomodoro_time INTEGER DEFAULT 1500,
    short_break_time INTEGER DEFAULT 300,
    long_break_time INTEGER DEFAULT 900,
    updated_at BIGINT NOT NULL,
    is_global BOOLEAN DEFAULT 1, -- 是否为全局设置
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE,
    UNIQUE(user_id, device_id) -- 每个用户每个设备只能有一个设置
);

-- 用户会话表（用于认证token管理）
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
    FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE
);

-- 创建索引（优化查询性能）
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

-- 创建视图（简化查询）
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
