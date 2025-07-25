# 日历月视图崩溃问题修复报告

## 问题描述

在日历功能的月视图中，当用户切换日期时应用会崩溃。崩溃发生在 `LifeTimer/Managers/SystemEventStore.swift` 文件中的 `appStatsCache[key]` 这一行，错误信息为：`Thread 4: EXC_BAD_ACCESS (code=1, address=0x10)`。

## 根本原因分析

经过深入分析，发现崩溃的根本原因是**线程竞争条件**（Race Condition）：

### 1. 线程安全问题
- `appStatsCache[key]` 在主线程被访问（第209行）
- 同时在后台线程 `cacheQueue.async` 中被修改（第219行）
- 缓存字典没有线程安全保护，导致并发访问时出现内存访问冲突

### 2. 缓存清理时机问题
- 用户快速切换日期时，`invalidateCache()` 方法在后台线程清空缓存
- 主线程可能正在访问同一个缓存，导致访问已释放的内存

### 3. 批量查询加剧问题
- `ActivityMonitorManager.getAppUsageStatsForDates()` 通过循环调用单独的 `getAppUsageStats()` 方法
- 增加了线程竞争的概率和频率

## 修复方案

### 1. 添加线程安全保护

**修改前：**
```swift
private var appStatsCache: [String: [AppUsageStats]] = [:]
private let cacheQueue = DispatchQueue(label: "com.pomodorotimer.systemeventcache", qos: .userInitiated)

// 不安全的缓存访问
if let cachedStats = appStatsCache[key] {
    return cachedStats
}
```

**修改后：**
```swift
private var appStatsCache: [String: [AppUsageStats]] = [:]
private let cacheQueue = DispatchQueue(label: "com.pomodorotimer.systemeventcache", qos: .userInitiated)
private let cacheLock = NSLock() // 新增线程安全锁

// 线程安全的缓存访问
cacheLock.lock()
let cachedStats = appStatsCache[key]
cacheLock.unlock()

if let cachedStats = cachedStats {
    return cachedStats
}
```

### 2. 修复缓存清理逻辑

**修改前：**
```swift
private func invalidateCache() {
    cacheQueue.async { [weak self] in
        self?.dateEventsCache.removeAll()
        self?.appStatsCache.removeAll()
        self?.overviewCache.removeAll()
    }
}
```

**修改后：**
```swift
private func invalidateCache() {
    cacheLock.lock()
    defer { cacheLock.unlock() }
    
    dateEventsCache.removeAll()
    appStatsCache.removeAll()
    overviewCache.removeAll()
}
```

### 3. 优化批量查询

**新增方法：**
```swift
/// 批量获取多个日期的应用使用统计（线程安全版本）
func getAppUsageStatsForDates(_ dates: [Date]) -> [Date: [AppUsageStats]] {
    // 线程安全的批量查询实现
    // 减少单独调用次数，降低线程竞争概率
}
```

**更新 ActivityMonitorManager：**
```swift
func getAppUsageStatsForDates(_ dates: [Date]) -> [Date: [AppUsageStats]] {
    // 使用 SystemEventStore 的批量查询方法
    return eventStore.getAppUsageStatsForDates(dates)
}
```

### 4. 添加调试日志

为了便于问题排查，添加了详细的调试日志：

```swift
#if DEBUG
print("📊 SystemEventStore: 应用统计缓存命中 - 日期 \(key)")
print("📊 SystemEventStore: 应用统计缓存未命中 - 计算日期 \(key) 的统计")
print("🗑️ SystemEventStore: 清除所有缓存")
#endif
```

## 修复的文件列表

1. **LifeTimer/Managers/SystemEventStore.swift**
   - 添加 `cacheLock` 线程安全锁
   - 修复所有缓存访问方法的线程安全性
   - 新增批量查询方法 `getAppUsageStatsForDates`
   - 添加调试日志

2. **LifeTimer/Managers/ActivityMonitorManager.swift**
   - 优化 `getAppUsageStatsForDates` 方法使用批量查询

3. **PomodoroTimerTests/SystemEventStoreThreadSafetyTests.swift**（新增）
   - 线程安全性测试用例
   - 并发访问测试
   - 快速日期切换测试
   - 批量查询测试
   - 缓存清理测试

4. **Scripts/test_calendar_stability.swift**（新增）
   - 日历稳定性压力测试脚本
   - 模拟真实用户操作场景

## 测试验证

### 1. 单元测试
运行 `SystemEventStoreThreadSafetyTests` 中的测试用例：
```bash
xcodebuild test -scheme LifeTimer -destination 'platform=macOS' -only-testing:PomodoroTimerTests/SystemEventStoreThreadSafetyTests
```

### 2. 压力测试
运行稳定性测试脚本：
```bash
swift Scripts/test_calendar_stability.swift
```

### 3. 手动测试
1. 打开日历月视图
2. 快速切换不同日期（特别是跨月切换）
3. 观察应用是否稳定运行，无崩溃现象

## 性能影响

线程安全修改对性能的影响：
- **锁开销**：NSLock 的开销很小，对性能影响微乎其微
- **批量查询优化**：减少了重复计算，实际上提升了性能
- **缓存命中率**：线程安全的缓存访问提高了缓存的可靠性

## 预防措施

为了避免类似问题再次发生：

1. **代码审查**：所有涉及多线程的缓存操作都需要仔细审查
2. **静态分析**：使用工具检测潜在的线程安全问题
3. **压力测试**：定期运行并发测试，确保线程安全性
4. **监控日志**：在 DEBUG 模式下启用详细日志，便于问题排查

## 总结

通过添加线程安全保护、优化批量查询和完善测试用例，成功修复了日历月视图的崩溃问题。修复方案不仅解决了当前问题，还提升了整体的稳定性和性能。

**关键改进点：**
- ✅ 消除了线程竞争条件
- ✅ 提供了线程安全的缓存访问
- ✅ 优化了批量查询性能
- ✅ 增加了详细的调试信息
- ✅ 建立了完善的测试体系

修复后的代码在保持原有功能的同时，显著提升了稳定性和可维护性。
