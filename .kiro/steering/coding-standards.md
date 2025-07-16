# Swift 编码规范

## 命名约定
- **类和结构体**: 使用 PascalCase (如 `TimerModel`, `AudioManager`)
- **变量和函数**: 使用 camelCase (如 `isRunning`, `startTimer()`)
- **常量**: 使用 camelCase (如 `defaultDuration`)
- **枚举**: 使用 PascalCase，成员使用 camelCase

## SwiftUI 最佳实践
- 使用 `@StateObject` 创建 ObservableObject 实例
- 使用 `@ObservedObject` 接收传入的 ObservableObject
- 使用 `@EnvironmentObject` 进行跨视图数据共享
- 保持 View 结构简洁，复杂逻辑提取到 ViewModel
- 使用 `@Published` 标记需要触发 UI 更新的属性

## 代码组织
- 每个文件只包含一个主要类型
- 使用 `// MARK: -` 分隔代码段
- 按功能分组相关方法
- 私有方法放在文件末尾

## 错误处理
- 使用 Swift 的 `Result` 类型处理可能失败的操作
- 网络请求使用 async/await 模式
- 适当使用 `do-catch` 块处理异常
- 提供有意义的错误信息

## 性能优化
- 避免在 View 的 body 中进行复杂计算
- 使用 `@State` 和 `@Binding` 最小化重绘范围
- 合理使用 `onReceive` 和 `onChange` 修饰符
- 及时释放不需要的资源

## 注释规范
- 使用中文注释说明复杂逻辑
- 公共 API 使用文档注释 (`///`)
- 标记 TODO 和 FIXME 项目
- 解释业务逻辑而非代码本身