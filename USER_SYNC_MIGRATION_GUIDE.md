# 用户账户同步系统迁移指南

本指南详细说明如何将番茄钟应用从基于设备隔离的同步系统迁移到基于用户账户的同步系统。

## 📋 迁移概述

### 迁移前后对比

| 特性 | 迁移前（设备隔离） | 迁移后（用户账户） |
|------|------------------|------------------|
| 数据隔离 | 按设备UUID隔离 | 按用户ID共享 |
| 跨设备同步 | ❌ 不支持 | ✅ 支持 |
| 用户认证 | ❌ 无 | ✅ 简化认证 |
| 数据共享 | ❌ 设备独立 | ✅ 用户级别 |
| 冲突处理 | 简单 | 增强 |

### 核心变更

1. **数据库结构**：新增用户表，调整外键关系
2. **API接口**：从device_uuid参数改为Authorization header
3. **客户端认证**：新增AuthManager和用户认证流程
4. **同步逻辑**：支持多设备数据共享和冲突解决

## 🚀 部署步骤

### 1. 服务端迁移

#### 1.1 备份现有数据
```bash
# 备份数据库
cp sync_server/database/sync.db sync_server/database/sync_backup_$(date +%Y%m%d_%H%M%S).db

# 备份配置文件
cp -r sync_server/config sync_server/config_backup
```

#### 1.2 执行数据库迁移
```bash
cd sync_server

# 预演模式（推荐先执行）
php migrate_database.php --dry-run

# 正式迁移
php migrate_database.php --backup-dir=./backups
```

#### 1.3 验证迁移结果
```bash
# 验证数据库结构和数据完整性
php verify_migration.php

# 运行综合测试
php test_user_sync.php test http://localhost:8080
```

#### 1.4 更新服务器配置
确保服务器支持新的API端点：
- `/api/auth/*` - 认证相关接口
- `/api/user/*` - 用户管理接口
- `/api/sync/*` - 更新的同步接口

### 2. 客户端更新

#### 2.1 集成新组件
在主应用中添加以下组件：
```swift
// 在App.swift或主视图中
@StateObject private var authManager = AuthManager(serverURL: "your-server-url")
@StateObject private var syncManager: SyncManager
@StateObject private var migrationManager: MigrationManager

init() {
    let authManager = AuthManager(serverURL: "your-server-url")
    self._authManager = StateObject(wrappedValue: authManager)
    
    let syncManager = SyncManager(serverURL: "your-server-url", authManager: authManager)
    self._syncManager = StateObject(wrappedValue: syncManager)
    
    let migrationManager = MigrationManager(authManager: authManager, apiClient: syncManager.apiClient)
    self._migrationManager = StateObject(wrappedValue: migrationManager)
}
```

#### 2.2 更新环境对象
```swift
ContentView()
    .environmentObject(authManager)
    .environmentObject(syncManager)
    .environmentObject(migrationManager)
```

#### 2.3 添加认证界面
在同步页面中集成认证检查：
```swift
if authManager.isAuthenticated {
    // 现有同步界面
    SyncView()
} else {
    // 认证界面
    AuthenticationView(authManager: authManager, migrationManager: migrationManager)
}
```

## 🔄 迁移流程

### 自动迁移流程

1. **检测旧数据**：应用启动时检查是否有旧版本数据
2. **提示用户**：显示迁移向导界面
3. **执行迁移**：调用服务端迁移API
4. **更新认证**：设置新的用户认证状态
5. **清理数据**：清理旧版本的本地数据

### 手动迁移流程

1. **获取用户UUID**：从其他已迁移设备获取
2. **输入UUID**：在迁移界面输入目标用户UUID
3. **验证绑定**：服务端验证并绑定设备
4. **同步数据**：执行全量同步获取用户数据

## 🧪 测试验证

### 服务端测试
```bash
# 完整测试套件
php test_user_sync.php test

# 数据一致性验证
php test_user_sync.php validate

# 迁移验证
php test_user_sync.php verify
```

### 客户端测试
```bash
# 运行单元测试
xcodebuild test -scheme PomodoroTimer -destination 'platform=macOS'

# 或在Xcode中运行UserSyncTests
```

### 手动测试场景

1. **新用户注册**
   - 首次启动应用
   - 选择"作为新用户开始"
   - 验证自动创建用户账户

2. **设备绑定**
   - 在第二个设备上启动应用
   - 选择"绑定到现有账户"
   - 输入第一个设备的用户UUID
   - 验证数据同步

3. **数据迁移**
   - 使用旧版本创建一些数据
   - 升级到新版本
   - 验证迁移向导正常工作
   - 确认数据完整迁移

4. **多设备同步**
   - 在设备A创建番茄事件
   - 在设备B同步数据
   - 验证事件出现在设备B
   - 在设备B修改事件
   - 在设备A同步验证修改

5. **冲突处理**
   - 在两个设备上离线修改同一事件
   - 分别上线同步
   - 验证冲突检测和处理

## 🔧 故障排除

### 常见问题

#### 1. 迁移失败
**症状**：迁移过程中出现错误
**解决方案**：
```bash
# 检查数据库权限
ls -la sync_server/database/

# 检查备份表是否存在
php -r "
$db = new PDO('sqlite:sync_server/database/sync.db');
$tables = $db->query('SELECT name FROM sqlite_master WHERE type=\"table\" AND name LIKE \"%_backup\"')->fetchAll();
var_dump($tables);
"

# 从备份恢复
cp sync_server/database/sync_backup_YYYYMMDD_HHMMSS.db sync_server/database/sync.db
```

#### 2. 认证失败
**症状**：客户端无法认证或token过期
**解决方案**：
```swift
// 清除本地认证数据
authManager.logout()

// 重新初始化
try await authManager.initializeDevice()
```

#### 3. 同步冲突
**症状**：数据同步时出现大量冲突
**解决方案**：
- 检查设备时间是否同步
- 使用强制覆盖模式解决
- 检查网络连接稳定性

#### 4. 性能问题
**症状**：同步速度慢或超时
**解决方案**：
```bash
# 检查数据库索引
php -r "
$db = new PDO('sqlite:sync_server/database/sync.db');
$indexes = $db->query('SELECT name FROM sqlite_master WHERE type=\"index\"')->fetchAll();
var_dump($indexes);
"

# 优化数据库
php -r "
$db = new PDO('sqlite:sync_server/database/sync.db');
$db->exec('VACUUM;');
$db->exec('ANALYZE;');
"
```

### 回滚方案

如果迁移出现严重问题，可以回滚到旧版本：

1. **恢复数据库**：
```bash
cp sync_server/database/sync_backup_YYYYMMDD_HHMMSS.db sync_server/database/sync.db
```

2. **恢复API**：
```bash
# 切换到旧版本API端点
# 或者修改API路由指向旧版本处理器
```

3. **客户端回滚**：
```swift
// 使用旧版本的SyncManager
let syncManager = SyncManager(serverURL: serverURL) // 不传authManager参数
```

## 📊 监控和维护

### 性能监控
- 监控API响应时间
- 跟踪同步成功率
- 监控数据库大小和查询性能

### 数据维护
```bash
# 定期清理过期会话
php -r "
require_once 'sync_server/includes/auth.php';
$cleaned = cleanupExpiredSessions();
echo \"Cleaned $cleaned expired sessions\n\";
"

# 数据库优化
php -r "
$db = getDB();
$db->exec('VACUUM;');
$db->exec('ANALYZE;');
echo \"Database optimized\n\";
"
```

### 备份策略
- 每日自动备份数据库
- 保留最近30天的备份
- 定期测试备份恢复

## 📝 最佳实践

1. **渐进式部署**：先在测试环境验证，再部署到生产环境
2. **用户通知**：提前通知用户即将进行的系统升级
3. **监控告警**：设置关键指标的监控告警
4. **文档更新**：及时更新API文档和用户手册
5. **培训支持**：为用户提供新功能的使用指导

## 🎯 后续优化

迁移完成后可以考虑的优化：

1. **增强认证**：添加邮箱/密码认证选项
2. **数据分析**：添加用户行为分析
3. **性能优化**：实现增量同步优化
4. **安全加固**：添加API限流和安全检查
5. **用户体验**：优化同步状态显示和错误处理

---

如有问题，请参考测试脚本输出或联系技术支持。
