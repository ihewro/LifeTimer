# 同步逻辑修复验证测试

## 修复内容总结

### 问题分析
原来的 `performSmartMerge` 函数采用"先拉取后推送"的两阶段策略：
1. **第一阶段**：`performPullOnly` - 立即更新 `lastSyncTimestampKey` 为服务器时间戳
2. **第二阶段**：`performPushOnly` - 使用更新后的时间戳检查本地变更

**问题**：如果服务器时间戳大于本地数据修改时间，本地变更会被误判为"已同步"而无法推送。

### 修复方案
重构为单一的增量同步操作：
1. 使用当前的 `lastSyncTimestampKey` 作为基准收集本地变更
2. 通过增量同步API同时发送本地变更并接收服务器变更
3. 应用服务器变更到本地
4. 最后统一更新 `lastSyncTimestampKey`

## 修复的关键函数

### 1. `performSmartMerge` 重构
```swift
/// 智能合并 - 使用单一增量同步操作
private func performSmartMerge(detailsCollector: inout SyncDetailsCollector) async throws {
    // 获取当前的同步基准时间戳
    let lastSyncTimestamp = userDefaults.object(forKey: lastSyncTimestampKey) as? Int64 ?? 0
    
    // 收集本地变更（基于当前的同步基准时间戳）
    let localChanges = await collectLocalChanges(since: lastSyncTimestamp)
    
    // 执行增量同步：同时发送本地变更并接收服务器变更
    let response = try await apiClient.incrementalSync(request, token: token)
    
    // 应用服务器端的变更到本地
    await applyServerChanges(response.data.serverChanges)
    
    // 最后统一更新同步时间戳
    userDefaults.set(response.data.serverTimestamp, forKey: lastSyncTimestampKey)
}
```

### 2. `performIncrementalSync` 修复
```swift
/// 增量同步 - 直接使用增量同步API
private func performIncrementalSync(detailsCollector: inout SyncDetailsCollector) async throws {
    // 直接使用增量同步逻辑，不再调用 performSmartMerge
    // 实现与 performSmartMerge 相同的逻辑
}
```

### 3. 新增辅助函数
- `collectDownloadDetails(from: ServerChanges)` - 收集增量同步响应的下载详情
- `collectConflictDetails(from: [SyncConflict])` - 收集冲突详情
- `applyServerChanges(_ serverChanges: ServerChanges)` - 应用服务器端的增量变更
- `updateServerDataPreviewFromIncrementalResponse()` - 更新服务端数据预览

## 测试场景

### 场景1：本地变更时间戳小于服务器时间戳
**修复前问题**：
```
10:00 - 本地创建事件A (updatedAt: 10:00)
10:05 - 服务器有其他设备数据 (serverTimestamp: 10:05)

执行 performSmartMerge：
1. performPullOnly: lastSyncTimestampKey 更新为 10:05
2. performPushOnly: 事件A (10:00) < lastSyncTimestamp (10:05)
   结果：事件A被误判为已同步，不会推送！
```

**修复后效果**：
```
10:00 - 本地创建事件A (updatedAt: 10:00)
10:05 - 服务器有其他设备数据 (serverTimestamp: 10:05)

执行修复后的 performSmartMerge：
1. 使用原始 lastSyncTimestamp (例如: 09:50) 收集本地变更
2. 事件A (10:00) > lastSyncTimestamp (09:50) - 正确识别为需要推送
3. 同时接收服务器变更并应用到本地
4. 最后更新 lastSyncTimestamp 为新的服务器时间戳
```

### 场景2：并发修改冲突处理
**测试内容**：
- 本地和服务器同时修改同一事件
- 验证冲突检测和处理逻辑
- 确保冲突详情正确收集

### 场景3：时间戳更新顺序
**测试内容**：
- 验证 `lastSyncTimestampKey` 只在同步完成后更新
- 确保中间过程不会影响本地变更检测

## 验证要点

1. **本地变更正确推送**：确保所有本地变更都能正确推送到服务器
2. **服务器变更正确拉取**：确保服务器变更能正确应用到本地
3. **时间戳更新逻辑**：验证 `lastSyncTimestampKey` 更新时机正确
4. **冲突处理**：验证冲突检测和处理逻辑
5. **数据一致性**：确保同步后本地和服务器数据一致

## 预期结果

修复后的同步逻辑应该：
- ✅ 解决本地变更丢失问题
- ✅ 保持原有的冲突检测功能
- ✅ 维护 SyncDetailsCollector 统计功能
- ✅ 确保时间戳更新逻辑正确
- ✅ 提供更可靠的数据同步体验
