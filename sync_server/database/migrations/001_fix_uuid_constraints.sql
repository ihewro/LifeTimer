-- 迁移脚本：修复UUID约束问题
-- 将单独的uuid UNIQUE约束改为uuid+user_id的组合唯一约束
-- 创建时间：2025-07-27
-- 描述：解决设备在不同用户间切换时的UUID冲突问题

-- 开始事务
BEGIN TRANSACTION;

-- 1. 处理 pomodoro_events 表
-- 创建新的临时表，使用正确的约束
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
    UNIQUE(uuid, user_id) -- 新的组合唯一约束
);

-- 复制数据到新表
INSERT INTO pomodoro_events_new (
    id, uuid, user_id, device_id, title, start_time, end_time, 
    event_type, is_completed, created_at, updated_at, deleted_at, 
    last_modified_device_id
)
SELECT 
    id, uuid, user_id, device_id, title, start_time, end_time, 
    event_type, is_completed, created_at, updated_at, deleted_at, 
    last_modified_device_id
FROM pomodoro_events;

-- 删除旧表
DROP TABLE pomodoro_events;

-- 重命名新表
ALTER TABLE pomodoro_events_new RENAME TO pomodoro_events;

-- 2. 处理 system_events 表
-- 创建新的临时表，使用正确的约束
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
    UNIQUE(uuid, user_id) -- 新的组合唯一约束
);

-- 复制数据到新表
INSERT INTO system_events_new (
    id, uuid, user_id, device_id, event_type, timestamp, 
    data, created_at, deleted_at
)
SELECT 
    id, uuid, user_id, device_id, event_type, timestamp, 
    data, created_at, deleted_at
FROM system_events;

-- 删除旧表
DROP TABLE system_events;

-- 重命名新表
ALTER TABLE system_events_new RENAME TO system_events;

-- 3. 重新创建索引
-- pomodoro_events 索引
CREATE INDEX IF NOT EXISTS idx_pomodoro_events_user_updated ON pomodoro_events(user_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_pomodoro_events_uuid ON pomodoro_events(uuid);
CREATE INDEX IF NOT EXISTS idx_pomodoro_events_device ON pomodoro_events(device_id);
CREATE INDEX IF NOT EXISTS idx_pomodoro_events_uuid_user ON pomodoro_events(uuid, user_id);

-- system_events 索引
CREATE INDEX IF NOT EXISTS idx_system_events_user_timestamp ON system_events(user_id, timestamp);
CREATE INDEX IF NOT EXISTS idx_system_events_uuid ON system_events(uuid);
CREATE INDEX IF NOT EXISTS idx_system_events_device ON system_events(device_id);
CREATE INDEX IF NOT EXISTS idx_system_events_uuid_user ON system_events(uuid, user_id);

-- 提交事务
COMMIT;

-- 验证迁移结果
-- 检查表结构
.schema pomodoro_events
.schema system_events

-- 输出迁移完成信息
SELECT 'Migration 001_fix_uuid_constraints completed successfully' as status;
