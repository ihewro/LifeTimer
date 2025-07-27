-- 修复外键约束中的 devices_new 引用
-- 由于 SQLite 不支持直接修改外键约束，我们需要重建表

PRAGMA foreign_keys=off;

BEGIN TRANSACTION;

-- 1. 重建 pomodoro_events 表
CREATE TABLE pomodoro_events_temp (
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
    FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE SET NULL,
    FOREIGN KEY (last_modified_device_id) REFERENCES devices(id) ON DELETE SET NULL
);

INSERT INTO pomodoro_events_temp SELECT * FROM pomodoro_events;
DROP TABLE pomodoro_events;
ALTER TABLE pomodoro_events_temp RENAME TO pomodoro_events;

-- 2. 重建 system_events 表
CREATE TABLE system_events_temp (
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

INSERT INTO system_events_temp SELECT * FROM system_events;
DROP TABLE system_events;
ALTER TABLE system_events_temp RENAME TO system_events;

-- 3. 重建 timer_settings 表
CREATE TABLE timer_settings_temp (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    device_id INTEGER,
    pomodoro_time INTEGER DEFAULT 1500,
    short_break_time INTEGER DEFAULT 300,
    long_break_time INTEGER DEFAULT 900,
    updated_at BIGINT NOT NULL,
    is_global BOOLEAN DEFAULT 1,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE,
    UNIQUE(user_id, device_id)
);

INSERT INTO timer_settings_temp SELECT * FROM timer_settings;
DROP TABLE timer_settings;
ALTER TABLE timer_settings_temp RENAME TO timer_settings;

COMMIT;

PRAGMA foreign_keys=on;
