-- 迁移timer_settings表到key-value格式
-- 注意：此脚本会删除现有的timer_settings数据，不保留向后兼容性

-- 1. 删除现有的timer_settings表
DROP TABLE IF EXISTS timer_settings;

-- 2. 创建新的key-value格式的timer_settings表
CREATE TABLE timer_settings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    device_id INTEGER, -- NULL表示全局设置，非NULL表示设备特定设置
    setting_key VARCHAR(50) NOT NULL, -- 设置项键名，如 'pomodoro_time', 'short_break_time', 'long_break_time'
    setting_value TEXT NOT NULL, -- 设置项值，支持字符串、数字等各种类型
    updated_at BIGINT NOT NULL, -- 毫秒时间戳
    is_global BOOLEAN DEFAULT 1, -- 是否为全局设置
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE,
    UNIQUE(user_id, device_id, setting_key) -- 每个用户每个设备每个设置项只能有一个值
);

-- 3. 创建索引
CREATE INDEX idx_timer_settings_user ON timer_settings(user_id);
CREATE INDEX idx_timer_settings_device ON timer_settings(device_id);
CREATE INDEX idx_timer_settings_user_key ON timer_settings(user_id, setting_key);
CREATE INDEX idx_timer_settings_updated_at ON timer_settings(updated_at);

-- 4. 插入默认设置（可选，用于测试）
-- INSERT INTO timer_settings (user_id, device_id, setting_key, setting_value, updated_at, is_global) VALUES
-- (1, NULL, 'pomodoro_time', '1500', strftime('%s', 'now') * 1000, 1),
-- (1, NULL, 'short_break_time', '300', strftime('%s', 'now') * 1000, 1),
-- (1, NULL, 'long_break_time', '900', strftime('%s', 'now') * 1000, 1);
