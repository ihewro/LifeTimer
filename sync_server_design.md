# 番茄钟云同步服务设计方案

## 1. 数据库设计（SQLite）

### 核心表结构

```sql
-- 设备管理表
CREATE TABLE devices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_uuid VARCHAR(36) UNIQUE NOT NULL,
    device_name VARCHAR(100),
    platform VARCHAR(20), -- 'macOS', 'iOS'
    last_sync_timestamp BIGINT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 番茄事件表
CREATE TABLE pomodoro_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    uuid VARCHAR(36) UNIQUE NOT NULL, -- 客户端生成的UUID
    device_uuid VARCHAR(36) NOT NULL,
    title VARCHAR(200) NOT NULL,
    start_time BIGINT NOT NULL, -- Unix timestamp (ms)
    end_time BIGINT NOT NULL,
    event_type VARCHAR(20) NOT NULL, -- 'pomodoro', 'shortBreak', 'longBreak', 'custom'
    is_completed BOOLEAN DEFAULT 0,
    created_at BIGINT NOT NULL, -- 创建时间戳
    updated_at BIGINT NOT NULL, -- 更新时间戳
    deleted_at BIGINT DEFAULT NULL, -- 软删除时间戳
    FOREIGN KEY (device_uuid) REFERENCES devices(device_uuid)
);

-- 系统事件表
CREATE TABLE system_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    uuid VARCHAR(36) UNIQUE NOT NULL,
    device_uuid VARCHAR(36) NOT NULL,
    event_type VARCHAR(30) NOT NULL,
    timestamp BIGINT NOT NULL,
    data TEXT, -- JSON格式存储额外数据
    created_at BIGINT NOT NULL,
    deleted_at BIGINT DEFAULT NULL,
    FOREIGN KEY (device_uuid) REFERENCES devices(device_uuid)
);

-- 计时器设置表
CREATE TABLE timer_settings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_uuid VARCHAR(36) NOT NULL,
    pomodoro_time INTEGER DEFAULT 1500, -- 25分钟，单位秒
    short_break_time INTEGER DEFAULT 300, -- 5分钟
    long_break_time INTEGER DEFAULT 900, -- 15分钟
    updated_at BIGINT NOT NULL,
    FOREIGN KEY (device_uuid) REFERENCES devices(device_uuid)
);

-- 创建索引
CREATE INDEX idx_pomodoro_events_device_updated ON pomodoro_events(device_uuid, updated_at);
CREATE INDEX idx_system_events_device_timestamp ON system_events(device_uuid, timestamp);
CREATE INDEX idx_pomodoro_events_uuid ON pomodoro_events(uuid);
CREATE INDEX idx_system_events_uuid ON system_events(uuid);
```

## 2. API接口设计

### 基础响应格式
```json
{
    "success": true,
    "data": {},
    "message": "操作成功",
    "timestamp": 1703123456789
}
```

### 2.1 设备注册/认证
```
POST /api/device/register
{
    "device_uuid": "550e8400-e29b-41d4-a716-446655440000",
    "device_name": "MacBook Pro",
    "platform": "macOS"
}

Response:
{
    "success": true,
    "data": {
        "device_uuid": "550e8400-e29b-41d4-a716-446655440000",
        "last_sync_timestamp": 0
    }
}
```

### 2.2 全量同步（首次使用）
```
GET /api/sync/full?device_uuid={uuid}

Response:
{
    "success": true,
    "data": {
        "pomodoro_events": [...],
        "system_events": [...],
        "timer_settings": {...},
        "server_timestamp": 1703123456789
    }
}
```

### 2.3 增量同步
```
POST /api/sync/incremental
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

Response:
{
    "success": true,
    "data": {
        "conflicts": [], // 冲突数据
        "server_changes": {
            "pomodoro_events": [...],
            "system_events": [...],
            "timer_settings": {...}
        },
        "server_timestamp": 1703123456789
    }
}
```

## 3. 冲突解决策略

### 3.1 冲突检测
- 同一UUID的记录在多个设备上被修改
- 使用 `updated_at` 时间戳判断

### 3.2 解决规则
1. **番茄事件**: 最后修改时间优先（Last Write Wins）
2. **系统事件**: 只允许创建，不允许修改
3. **设置**: 最后修改时间优先
4. **删除操作**: 删除优先于修改

## 4. 客户端实现要点

### 4.1 数据变更追踪
```swift
// 为每个数据模型添加同步字段
struct PomodoroEvent {
    let uuid: String = UUID().uuidString
    var createdAt: Int64
    var updatedAt: Int64
    var needsSync: Bool = true
    var isDeleted: Bool = false
    // ... 其他字段
}
```

### 4.2 同步管理器
```swift
class SyncManager: ObservableObject {
    @Published var isSyncing = false
    @Published var lastSyncTime: Date?
    
    private let apiClient: APIClient
    private let deviceUUID: String
    
    func performFullSync() async
    func performIncrementalSync() async
    func markForSync<T: Syncable>(_ item: T)
}
```

## 5. PHP服务端实现要点

### 5.1 目录结构
```
sync_server/
├── index.php          # 入口文件
├── config/
│   └── database.php   # 数据库配置
├── api/
│   ├── device.php     # 设备管理
│   ├── sync.php       # 同步接口
│   └── base.php       # 基础类
├── models/
│   ├── Device.php
│   ├── PomodoroEvent.php
│   └── SystemEvent.php
└── database/
    └── schema.sql     # 数据库结构
```

### 5.2 核心特性
- 简单的路由系统
- PDO数据库操作
- JSON API响应
- 基本的错误处理
- 事务支持（确保数据一致性）

## 6. 同步流程

### 6.1 首次启动
1. 生成设备UUID
2. 调用设备注册API
3. 执行全量同步
4. 保存最后同步时间

### 6.2 日常同步
1. 收集本地变更
2. 调用增量同步API
3. 处理服务器返回的变更
4. 解决冲突
5. 更新最后同步时间

### 6.3 多设备场景
- 设备A创建事件 → 同步到服务器
- 设备B同步时获取设备A的变更
- 冲突时按时间戳规则解决

## 7. 安全考虑

1. **设备认证**: 使用设备UUID作为简单认证
2. **数据隔离**: 每个设备只能访问自己的数据
3. **输入验证**: 验证所有API输入参数
4. **SQL注入防护**: 使用PDO预处理语句

## 8. 性能优化

1. **分页查询**: 大量数据时分页返回
2. **索引优化**: 在关键字段上建立索引
3. **数据压缩**: 大量数据时使用gzip压缩
4. **缓存策略**: 可选择添加Redis缓存

## 9. 部署建议

1. **服务器要求**: PHP 7.4+, SQLite3
2. **目录权限**: 确保数据库文件可写
3. **备份策略**: 定期备份SQLite数据库
4. **监控**: 添加基本的日志记录
