## 目标

* 在计时器的关键事件（开始、暂停、停止、完成）自动触发用户指定的 macOS 快捷指令（Shortcuts）。

* 提供偏好设置，允许用户按事件分别启用/禁用，并填写要运行的快捷指令名称。

## 触发时机与集成点

* 开始计时：`/LifeTimer/Models/TimerModel.swift:154` 的 `startTimer(with:)` 完成状态切换后触发。

* 暂停计时：`/LifeTimer/Models/TimerModel.swift:184` 的 `pauseTimer()` 成功暂停后触发。

* 手动停止：`/LifeTimer/Models/TimerModel.swift:259` 的 `stopTimer()` 执行返回 `idle` 后触发。

* 计时完成：`/LifeTimer/Models/TimerModel.swift:312` 的 `completeTimer()` 在 `post` 完成通知前或后触发；另外可在监听处统一处理：`/LifeTimer/Managers/SmartReminderManager.swift:136–141, 242–272`。

* 说明：优先在 `TimerModel` 统一触发，避免分散在 UI 按钮（如 `/LifeTimer/Views/TimerView.swift`、`/LifeTimer/Views/MenuBarPopoverView.swift`）造成漏触发；完成事件也可在现有通知监听中统一。

## 执行方式（URL Scheme）

* URL Scheme：`shortcuts://run-shortcut?name=<NAME>&input=<OPTIONAL>`，通过 `NSWorkspace.shared.open(URL)` 调用；优点是无需子进程，沙盒兼容性好。

  <br />

## 偏好设置

* 新增设置页分组“快捷指令”（Shortcuts）：

  * 输入框：`快捷指令名称`（字符串，必填）。

  * 开关：`开始时运行`、`暂停时运行`、`停止时运行`、`完成时运行`（四个独立开关）。

  * 高级选项：`使用 CLI 运行`（默认关闭）；`传入输入文本`（可选）。

* 将配置存于现有偏好存储（沿用当前项目的设置管理方式）。

## 实现要点

* 新增轻量工具类 `ShortcutRunner`：

  * `run(name: String, input: String?)` 封装 URL 与 CLI；根据偏好选择路径，CLI 不可用时自动回退到 URL。

  * 调用时异步触发、主线程安全；失败时记录日志但不影响计时流程。

* 在 `TimerModel` 的四个事件点调用 `ShortcutRunner`，按偏好布尔开关决定是否执行。

* 对完成事件也在 `SmartReminderManager` 的监听中调用一次（可选），与 `TimerModel` 二选一，保持单点触发避免重复。

## 权限与兼容

* URL Scheme 与 `/usr/bin/shortcuts` 在 macOS 12+ 可用；沙盒下允许打开 URL 和运行系统可执行文件；不请求额外敏感权限。

* 若用户机器无 Shortcuts 或禁用了 URL Scheme/CLI，工具类应静默降级并在日志提示。

## 验证与回滚

* 在开发模式下：

  * 添加一个测试快捷指令（例如弹通知），手动测试四种事件触发是否生效。

  * 验证重复点击与快速状态切换不产生多次并发触发（通过内部节流/去重保证）。

* 提供“测试运行”按钮于设置页，便于用户验证配置。

* 出现异常时不影响计时器本身，触发失败仅记录日志。

## 最小实现范围

* 仅实现“按事件运行指定名称的快捷指令”，无复杂变量传递；保留输入文本可选。

* 后续扩展再支持变量映射（如当前任务名、剩余时间等）。

## 交付内容

* 新的 `ShortcutRunner` 工具类及调用点接入。

* 设置页面的配置项与持久化。

* 开发验证说明与日志输出。

