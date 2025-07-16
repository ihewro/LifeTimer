# 数据管理指导

## 数据持久化策略
- 用户设置：使用 UserDefaults 存储
- 事件数据：JSON 序列化到 UserDefaults
- 临时数据：使用 @State 和 @Published 管理
- 大文件：存储到 Documents 目录

## 数据模型设计
```swift
// 所有数据模型必须实现 Codable
struct TimerEvent: Codable, Identifiable {
    let id = UUID()
    var title: String
    var startTime: Date
    var duration: TimeInterval
    var type: EventType
    var isCompleted: Bool = false
}
```

## 同步架构
- 客户端优先：本地操作立即生效
- 后台同步：定期与服务器同步
- 冲突解决：使用时间戳判断优先级
- 离线支持：本地缓存所有数据

## 数据验证
- 输入验证：在 ViewModel 层进行
- 数据完整性：保存前检查必填字段
- 类型安全：使用强类型而非字符串

## 错误处理
```swift
enum DataError: Error, LocalizedError {
    case invalidData
    case networkUnavailable
    case syncFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidData: return "数据格式错误"
        case .networkUnavailable: return "网络连接不可用"
        case .syncFailed: return "同步失败"
        }
    }
}
```

## 性能优化
- 懒加载：按需加载数据
- 分页：大数据集分批加载
- 缓存：合理使用内存缓存
- 后台处理：耗时操作在后台队列执行

## 数据迁移
- 版本控制：为数据结构添加版本号
- 向后兼容：支持旧版本数据格式
- 渐进迁移：分步骤迁移复杂数据