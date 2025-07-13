-- 添加 last_access_timestamp 字段到 devices 表
-- 用于跟踪设备最后访问时间（数据预览等轻量操作）

-- 检查字段是否已存在，如果不存在则添加
ALTER TABLE devices ADD COLUMN last_access_timestamp BIGINT DEFAULT 0;

-- 更新现有记录的 last_access_timestamp 为当前时间戳
UPDATE devices SET last_access_timestamp = (strftime('%s', 'now') * 1000) WHERE last_access_timestamp = 0;
