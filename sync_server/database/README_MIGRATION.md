# 数据库迁移说明

## 问题描述

在番茄事件表(`pomodoro_events`)和系统事件表(`system_events`)中，当前的`uuid`字段设置为`UNIQUE`约束存在问题。这会导致以下场景出现数据冲突：

1. 设备A最初绑定到用户A，创建了一些事件记录
2. 设备A解除与用户A的绑定
3. 设备A重新绑定到用户B
4. 由于设备A本地仍有之前的事件记录（相同的uuid），当尝试同步到服务器时会因为uuid唯一性约束而失败

## 解决方案

将数据库约束从单独的`uuid UNIQUE`改为`uuid+user_id`的组合唯一约束：
- 允许相同的uuid在不同用户间存在
- 同一用户下的uuid仍然保持唯一
- 解决设备在用户间切换时的冲突问题

## 迁移文件

### 1. 修改后的Schema文件
- `schema.sql` - 更新后的数据库结构定义
- 包含正确的组合唯一约束：`UNIQUE(uuid, user_id)`

### 2. 迁移脚本
- `migrations/001_fix_uuid_constraints.sql` - 标准迁移SQL文件
- `run_migration.php` - 通用迁移执行器（支持多个迁移文件）
- `fix_uuid_constraints.php` - 专用的UUID约束修复脚本

## 执行迁移

### 方法1：使用专用修复脚本（推荐）

```bash
cd sync_server/database
php fix_uuid_constraints.php
```

这个脚本会：
- 自动检查当前表结构是否需要迁移
- 创建数据库备份
- 在事务中安全地执行迁移
- 验证迁移结果
- 提供详细的执行日志

### 方法2：使用通用迁移执行器

```bash
cd sync_server/database
php run_migration.php run
```

查看迁移状态：
```bash
php run_migration.php status
```

执行特定迁移：
```bash
php run_migration.php specific 001_fix_uuid_constraints.sql
```

## 迁移过程

1. **备份创建**：自动创建数据库备份文件
2. **表重建**：
   - 创建带有正确约束的新表
   - 复制所有现有数据
   - 删除旧表并重命名新表
3. **索引重建**：重新创建所有相关索引，包括新的组合索引
4. **验证**：检查表结构和数据完整性

## 影响的表

### pomodoro_events
- **旧约束**：`uuid VARCHAR(36) UNIQUE NOT NULL`
- **新约束**：`uuid VARCHAR(36) NOT NULL` + `UNIQUE(uuid, user_id)`

### system_events
- **旧约束**：`uuid VARCHAR(36) UNIQUE NOT NULL`
- **新约束**：`uuid VARCHAR(36) NOT NULL` + `UNIQUE(uuid, user_id)`

## 新增索引

为了优化查询性能，添加了以下组合索引：
- `idx_pomodoro_events_uuid_user` - 在 `(uuid, user_id)` 上
- `idx_system_events_uuid_user` - 在 `(uuid, user_id)` 上

## 安全措施

1. **自动备份**：执行前自动创建数据库备份
2. **事务保护**：所有操作在事务中执行，失败时自动回滚
3. **验证检查**：迁移后验证表结构和数据完整性
4. **幂等性**：可以安全地重复执行，已执行的迁移会被跳过

## 回滚方案

如果迁移出现问题：
1. 脚本会自动回滚事务
2. 可以使用自动创建的备份文件恢复数据库
3. 备份文件位置：`sync_server/database/sync_database_backup_YYYY-MM-DD_HH-mm-ss.db`

## 注意事项

1. **执行前确保**：
   - 数据库文件有写权限
   - 有足够的磁盘空间创建备份
   - 没有其他进程正在使用数据库

2. **执行后验证**：
   - 检查应用程序功能是否正常
   - 确认同步功能工作正常
   - 测试设备切换用户的场景

3. **生产环境**：
   - 建议在维护窗口期间执行
   - 提前通知用户可能的短暂服务中断
   - 准备回滚计划

## 测试建议

迁移完成后，建议测试以下场景：
1. 正常的事件同步功能
2. 设备解绑和重新绑定到不同用户
3. 相同UUID在不同用户间的处理
4. 数据查询性能（特别是涉及UUID的查询）
