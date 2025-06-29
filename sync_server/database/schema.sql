-- 设备管理表
CREATE TABLE IF NOT EXISTS devices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_uuid VARCHAR(36) UNIQUE NOT NULL,
    device_name VARCHAR(100),
    platform VARCHAR(20),
    last_sync_timestamp BIGINT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 番茄事件表
CREATE TABLE IF NOT EXISTS pomodoro_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    uuid VARCHAR(36) UNIQUE NOT NULL,
    device_uuid VARCHAR(36) NOT NULL,
    title VARCHAR(200) NOT NULL,
    start_time BIGINT NOT NULL,
    end_time BIGINT NOT NULL,
    event_type VARCHAR(20) NOT NULL,
    is_completed BOOLEAN DEFAULT 0,
    created_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL,
    deleted_at BIGINT DEFAULT NULL,
    FOREIGN KEY (device_uuid) REFERENCES devices(device_uuid)
);

-- 系统事件表
CREATE TABLE IF NOT EXISTS system_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    uuid VARCHAR(36) UNIQUE NOT NULL,
    device_uuid VARCHAR(36) NOT NULL,
    event_type VARCHAR(30) NOT NULL,
    timestamp BIGINT NOT NULL,
    data TEXT,
    created_at BIGINT NOT NULL,
    deleted_at BIGINT DEFAULT NULL,
    FOREIGN KEY (device_uuid) REFERENCES devices(device_uuid)
);

-- 计时器设置表
CREATE TABLE IF NOT EXISTS timer_settings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_uuid VARCHAR(36) NOT NULL,
    pomodoro_time INTEGER DEFAULT 1500,
    short_break_time INTEGER DEFAULT 300,
    long_break_time INTEGER DEFAULT 900,
    updated_at BIGINT NOT NULL,
    FOREIGN KEY (device_uuid) REFERENCES devices(device_uuid)
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_pomodoro_events_device_updated ON pomodoro_events(device_uuid, updated_at);
CREATE INDEX IF NOT EXISTS idx_system_events_device_timestamp ON system_events(device_uuid, timestamp);
CREATE INDEX IF NOT EXISTS idx_pomodoro_events_uuid ON pomodoro_events(uuid);
CREATE INDEX IF NOT EXISTS idx_system_events_uuid ON system_events(uuid);
CREATE INDEX IF NOT EXISTS idx_devices_uuid ON devices(device_uuid);
