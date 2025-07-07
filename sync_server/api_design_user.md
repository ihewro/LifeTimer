# 用户账户同步API设计

## 1. 认证流程

### 1.1 设备首次启动
```
POST /api/auth/device-init
{
    "device_uuid": "550e8400-e29b-41d4-a716-446655440000",
    "device_name": "MacBook Pro",
    "platform": "macOS"
}

Response:
{
    "success": true,
    "data": {
        "user_uuid": "新生成的用户UUID",
        "session_token": "认证token",
        "expires_at": "2024-01-01T00:00:00Z",
        "is_new_user": true,
        "user_info": {
            "user_uuid": "用户UUID",
            "user_name": "用户名",
            "email": "邮箱（可选）",
            "created_at": "2024-01-01T00:00:00Z"
        }
    }
}
```

### 1.2 现有用户添加新设备
```
POST /api/auth/device-bind
{
    "user_uuid": "现有用户UUID",
    "device_uuid": "新设备UUID",
    "device_name": "iPhone",
    "platform": "iOS"
}

Response:
{
    "success": true,
    "data": {
        "session_token": "认证token",
        "expires_at": "2024-01-01T00:00:00Z",
        "user_data": {
            "user_uuid": "用户UUID",
            "user_name": "用户名",
            "email": "邮箱（可选）",
            "created_at": "2024-01-01T00:00:00Z",
            "device_count": 2,
            "last_sync_timestamp": 1703123456789
        }
    }
}
```

### 1.3 Token刷新
```
POST /api/auth/refresh
Headers: Authorization: Bearer {current_token}

Response:
{
    "success": true,
    "data": {
        "session_token": "新token",
        "expires_at": "2024-01-01T00:00:00Z"
    }
}
```



## 2. 同步API接口

### 2.1 全量同步
```
GET /api/user/sync/full
Headers: Authorization: Bearer {session_token}

Response:
{
    "success": true,
    "data": {
        "pomodoro_events": [...],
        "system_events": [...],
        "timer_settings": {...},
        "server_timestamp": 1703123456789,
        "user_info": {
            "user_uuid": "用户UUID",
            "device_count": 3
        }
    }
}
```

### 2.2 增量同步
```
POST /api/user/sync/incremental
Headers: Authorization: Bearer {session_token}
{
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
        "conflicts": [
            {
                "type": "pomodoro_event",
                "uuid": "事件UUID",
                "reason": "concurrent_modification",
                "server_data": {...},
                "client_data": {...},
                "conflict_resolution": "server_wins|client_wins|manual"
            }
        ],
        "server_changes": {
            "pomodoro_events": [...],
            "system_events": [...],
            "timer_settings": {...}
        },
        "server_timestamp": 1703123456789
    }
}
```

## 3. 用户管理API

### 3.1 获取用户信息
```
GET /api/user/profile
Headers: Authorization: Bearer {session_token}

Response:
{
    "success": true,
    "data": {
        "user_uuid": "用户UUID",
        "user_name": "用户名",
        "email": "邮箱",
        "created_at": "2024-01-01T00:00:00Z",
        "devices": [
            {
                "device_uuid": "设备UUID",
                "device_name": "设备名称",
                "platform": "平台",
                "last_sync_timestamp": 1703123456789,
                "is_current": true
            }
        ]
    }
}
```

### 3.2 设备管理
```
GET /api/user/devices
Headers: Authorization: Bearer {session_token}

DELETE /api/user/devices/{device_uuid}
Headers: Authorization: Bearer {session_token}
```

## 4. 冲突解决策略

### 4.1 冲突检测规则
1. **时间戳冲突**：同一事件在多个设备上被修改
2. **设备信息**：记录最后修改的设备，用于冲突解决
3. **优先级规则**：
   - 删除操作优先于修改
   - 最新修改时间优先（Last Write Wins）
   - 特殊情况下支持手动解决

### 4.2 冲突解决流程
```
1. 检测冲突：比较客户端和服务端的updated_at时间戳
2. 自动解决：根据预设规则自动解决大部分冲突
3. 返回冲突：无法自动解决的冲突返回给客户端
4. 手动解决：客户端提供界面让用户选择解决方案
```

## 5. 数据迁移策略

### 5.1 迁移API
```
POST /api/user/sync/migrate
{
    "device_uuid": "现有设备UUID",
    "target_user_uuid": "目标用户UUID（可选）"
}

Response:
{
    "success": true,
    "data": {
        "user_uuid": "用户UUID",
        "migrated_events": 150,
        "migrated_settings": 1,
        "session_token": "新的认证token"
    }
}
```



## 6. 安全考虑

### 6.1 Token安全
- JWT token包含用户ID和设备ID
- Token有效期24小时，支持自动刷新
- 支持token撤销（登出时）

### 6.2 数据隔离
- 严格按用户ID隔离数据
- API层面验证用户权限
- 防止跨用户数据泄露

### 6.3 设备管理
- 支持设备解绑
- 异常设备检测和处理
- 设备数量限制（可配置）
