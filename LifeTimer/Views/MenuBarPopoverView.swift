//
//  MenuBarPopoverView.swift
//  LifeTimer
//
//  Created by Developer on 2024.
//

import SwiftUI
#if canImport(Cocoa)
import Cocoa
#endif
// 轻量按压反馈样式，扩大点击区域并在按下时提供视觉反馈（文件级作用域）
struct PressableIconButtonStyle: ButtonStyle {
    var hitSize: CGFloat = 28
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: hitSize, height: hitSize)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: hitSize / 2)
                    .fill(Color.secondary.opacity(configuration.isPressed ? 0.15 : 0.0))
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// 菜单栏弹窗视图，复用SmartReminderDialog的UI和功能
struct MenuBarPopoverView: View {
    @ObservedObject var timerModel: TimerModel
    @EnvironmentObject var eventManager: EventManager
    @EnvironmentObject var smartReminderManager: SmartReminderManager
    
    @State private var currentTask: String = ""
    @State private var showingTaskSelector = false
    @State private var customMinutes: String = ""
    @FocusState private var isCustomInputFocused: Bool
    
    // 复用配置：标准菜单栏弹窗 / 智能提醒弹窗
    enum Mode {
        case standard
        case reminder
    }
    var mode: Mode = .standard
    
    // 当当前任务为空时的回退任务标题（用于提醒弹窗传入选择任务）
    var defaultTaskFallback: String = ""
    
    // 关闭弹窗的回调
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // 根据计时状态显示不同内容
            if timerModel.timerState == .idle {
                // 未开始计时时的UI
                idleStateView
            } else if timerModel.timerState == .completed {
                // 计时完成后的选择面板
                completedStateView
            } else {
                // 计时中的UI
                runningStateView
            }
        }
        .frame(width: 320)
        .padding(20)
        // .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .onAppear {
            // 初始化当前任务
            currentTask = timerModel.getCurrentDisplayTask(fallback: defaultTaskFallback)
        }
        // 当弹窗内选择的任务变化时，同步到计时器模型，保证与主界面一致
        .onChange(of: currentTask) { newTask in
            timerModel.setUserCustomTask(newTask)
        }
        // 当外部（如 TimerView）更新任务时，弹窗也同步显示
        .onChange(of: timerModel.userCustomTaskTitle) { newTitle in
            if !newTitle.isEmpty {
                currentTask = newTitle
            }
        }
        // 添加与主界面一致的键盘快捷键：空格（暂停/继续）、+（增加时间）、-（减少时间）
        .background(
            Group {
                // 空格键：根据当前状态开始/暂停/继续/重置
                Button("Toggle Timer (Space)") {
                    handleSpaceKeyPress()
                }
                .keyboardShortcut(.space, modifiers: [])
                .hidden()

                // 增加当前结束时间（按 + 或 Shift+=）
                Button("Increase Time (+)") {
                    if timerModel.canAdjustTime() {
                        timerModel.adjustCurrentTime(by: 5)
                    }
                }
                .keyboardShortcut("=", modifiers: [])
                .hidden()
                .disabled(!timerModel.canAdjustTime())

                // 减少当前结束时间（按 -）
                Button("Decrease Time (-)") {
                    if timerModel.canAdjustTime() {
                        timerModel.adjustCurrentTime(by: -5)
                    }
                }
                .keyboardShortcut("-", modifiers: [])
                .hidden()
                .disabled(!timerModel.canAdjustTime())
            }
        )
    }
    
    // MARK: - 未开始计时时的视图
    private var idleStateView: some View {
        VStack(spacing: 16) {
            // 标题区域
            VStack(spacing: 6) {
                Text(mode == .reminder ? "⏰ 该开始计时了！" : "⏰ 开始计时")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("选择任务并开始专注")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // 任务输入框
            taskInputSection

            // 专注时间按钮网格
            focusTimeGrid

            // 底部按钮
            HStack(spacing: 12) {
                if mode == .reminder {
                    Button("稍后提醒") {
                        let minutes = Int(smartReminderManager.reminderInterval)
                        smartReminderManager.snoozeReminder(minutes: minutes)
                        onClose()
                    }
                    .buttonStyle(.bordered)

                    Spacer()
                } else {
                    Button("打开主窗口") {
                        openMainWindow()
                    }
                    .buttonStyle(.bordered)

                    Spacer()
                    
                    Button("关闭") {
                        onClose()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
    
    // MARK: - 计时中的视图
    private var runningStateView: some View {
        VStack(spacing: 16) {
            // 标题区域
            VStack(spacing: 6) {
                Text("⏰ 计时进行中")
                    .font(.title2)
                    .fontWeight(.semibold)
                // 运行中任务修改 UI 与初始界面保持一致
                taskInputSection
            }

            // 时间显示 + 调节按钮（与主界面逻辑一致）
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    // 减少时间（左侧）
                    Button(action: {
                        if timerModel.canAdjustTime() {
                            timerModel.adjustCurrentTime(by: -5)
                        }
                    }) {
                        Image(systemName: "minus")
                            .font(.title2)
                            .foregroundColor(.secondary)
                            .opacity(timerModel.canAdjustTime() ? 1.0 : 0.35)
                    }
                    .buttonStyle(PressableIconButtonStyle(hitSize: 28))
                    .disabled(!timerModel.canAdjustTime())

                    // 时间文本
                    Text(timerModel.formattedTime())
                        .font(.system(size: 48, weight: .light, design: .monospaced))
                        .foregroundColor(.primary)

                    // 增加时间（右侧）
                    Button(action: {
                        if timerModel.canAdjustTime() {
                            timerModel.adjustCurrentTime(by: 5)
                        }
                    }) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(.secondary)
                            .opacity(timerModel.canAdjustTime() ? 1.0 : 0.35)
                    }
                    .buttonStyle(PressableIconButtonStyle(hitSize: 28))
                    .disabled(!timerModel.canAdjustTime())
                }

                // 状态指示
                if timerModel.timerState == .paused {
                    Text("已暂停")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(4)
                } else if timerModel.timerState == .running {
                    Text("专注中...")
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(4)
                }
            }

 

            // 控制按钮
            timerControlButtons

            // 底部按钮
            HStack(spacing: 12) {
                Button("打开主窗口") {
                    openMainWindow()
                }
                .buttonStyle(.bordered)

                Spacer()
                
                Button("关闭") {
                    onClose()
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    // MARK: - 计时完成后的视图（集成原 sheet dialog 功能）
    private var completedStateView: some View {
        VStack(spacing: 16) {
            // 标题
            VStack(spacing: 6) {
                Text("🍅 番茄钟已完成！")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("选择下一步行动")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // 支持在完成界面修改任务
            taskInputSection

            // 继续专注
            VStack(spacing: 12) {
                Text("继续专注")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // 使用上次时长 + 快速选择
                HStack(spacing: 8) {
                    Button(action: {
                        startPomodoro(minutes: Int(timerModel.getCurrentPomodoroTime() / 60))
                    }) {
                        VStack(spacing: 4) {
                            Text("上次时长")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(Int(timerModel.getCurrentPomodoroTime() / 60))分钟")
                                .font(.title3)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)

                    ForEach([10, 15, 30], id: \ .self) { minutes in
                        Button(action: {
                            startPomodoro(minutes: minutes)
                        }) {
                            Text("\(minutes)分钟")
                                .font(.title3)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            Divider()

            // 开始休息
            VStack(spacing: 12) {
                Text("开始休息")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: {
                    startBreak()
                }) {
                    HStack {
                        Image(systemName: "cup.and.saucer")
                        Text("休息 \(Int(timerModel.getCurrentBreakTime() / 60)) 分钟")
                            .font(.title3)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .tint(.blue)
            }

            // 底部按钮：菜单弹窗显示“打开主窗口”与“跳过”，提醒模式保持“稍后决定”
            HStack(spacing: 12) {
                if mode == .reminder {
                    Button("稍后决定") {
                        onClose()
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                } else {
                    Button("打开主窗口") {
                        openMainWindow()
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("跳过") {
                        timerModel.skipBreak()
                        onClose()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
    
    // MARK: - 计时控制按钮
    private var timerControlButtons: some View {
        VStack(spacing: 8) {
            // 运行中：与主界面逻辑保持一致
            if timerModel.timerState == .running {
                // 番茄模式运行中：暂停 / 放弃 / 提前结束
                if timerModel.currentMode == .singlePomodoro {
                    HStack(spacing: 8) {
                        Button(action: {
                            timerModel.pauseTimer()
                        }) {
                            Text("暂停")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .controlSize(.regular)

                        Button(action: {
                            timerModel.resetTimer()
                            onClose()
                        }) {
                            Text("放弃")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .controlSize(.regular)

                        Button(action: {
                            timerModel.completeEarly()
                            onClose()
                        }) {
                            Text("提前结束")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .controlSize(.regular)
                    }
                }
                // 正计时运行中：暂停 / 结束
                else if timerModel.currentMode == .countUp {
                    HStack(spacing: 8) {
                        Button(action: {
                            timerModel.pauseTimer()
                        }) {
                            Text("暂停")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .controlSize(.regular)

                        Button(action: {
                            timerModel.stopTimer()
                            onClose()
                        }) {
                            Text("结束")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .controlSize(.regular)
                    }
                }
                // 纯休息运行中：结束
                else if timerModel.currentMode == .pureRest {
                    Button(action: {
                        timerModel.stopTimer()
                        onClose()
                    }) {
                        Text("结束")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .controlSize(.regular)
                }
                // 自定义等其他模式运行中：暂停
                else {
                    Button(action: {
                        timerModel.pauseTimer()
                    }) {
                        Text("暂停")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .controlSize(.regular)
                }
            }
            // 暂停中：继续（与主界面一致）
            else if timerModel.timerState == .paused {
                Button(action: {
                    timerModel.startTimer(with: currentTask)
                    onClose()
                }) {
                    Text("继续")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
            // 其他状态：保持原有逻辑
            else {
                Button(action: {
                    timerModel.resetTimer()
                    onClose()
                }) {
                    Text("停止计时")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
        }
    }
    
    // MARK: - 任务输入框区域
    private var taskInputSection: some View {
        Button(action: {
            showingTaskSelector = true
        }) {
            HStack {
                Text(currentTask.isEmpty ? "选择任务" : currentTask)
                    .font(.body)
                    .foregroundColor(currentTask.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .popover(isPresented: $showingTaskSelector, arrowEdge: .top) {
            TaskSelectorPopoverView(
                selectedTask: $currentTask, 
                isPresented: $showingTaskSelector
            )
            .environmentObject(eventManager)
        }
    }
    
    // MARK: - 专注时间按钮网格
    private var focusTimeGrid: some View {
        VStack(spacing: 8) {
            Text("选择专注时间")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // 两行两列网格布局
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    focusTimeButton(minutes: 10)
                    focusTimeButton(minutes: 20)
                }
                HStack(spacing: 8) {
                    focusTimeButton(minutes: 30)
                    focusTimeButton(minutes: 40)
                }
            }
        }
    }
    
    // MARK: - 专注时间按钮
    private func focusTimeButton(minutes: Int) -> some View {
        Button(action: {
            startFocus(minutes: minutes)
        }) {
            VStack(spacing: 4) {
                Text("\(minutes)")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("分钟")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        // .buttonStyle(.borderedProminent)
        .controlSize(.regular)
    }
    
    // MARK: - 操作方法
    
    private func startFocus(minutes: Int) {
        timerModel.resetTimer()
        timerModel.setCustomTime(minutes: minutes)
        timerModel.currentMode = .singlePomodoro
        
        // 使用当前选择的任务，如果为空则使用默认任务
        let taskToUse = currentTask.isEmpty ? defaultTaskFallback : currentTask
        timerModel.startTimer(with: taskToUse)
        
        // 关闭弹窗
        onClose()
    }

    private func startPomodoro(minutes: Int) {
        // 先重置计时器状态，这样setCustomTime才能正常工作
        timerModel.resetTimer()
        timerModel.setCustomTime(minutes: minutes)
        timerModel.currentMode = .singlePomodoro
        let taskToUse = currentTask.isEmpty ? defaultTaskFallback : currentTask
        timerModel.startTimer(with: taskToUse)
        onClose()
    }

    private func startCustomPomodoro() {
        guard let minutes = Int(customMinutes), minutes > 0, minutes <= 99 else { return }
        startPomodoro(minutes: minutes)
    }

    private func startBreak() {
        timerModel.isBreakFromPomodoro = true
        timerModel.currentMode = .pureRest
        timerModel.resetTimer()
        timerModel.startTimer()
        onClose()
    }

    /// 处理空格键按下事件（与主界面逻辑保持一致）
    private func handleSpaceKeyPress() {
        switch timerModel.timerState {
        case .idle:
            // 空闲状态：开始计时器
            timerModel.startTimer(with: currentTask)

        case .running:
            // 运行状态：纯休息模式直接结束，其他模式暂停
            if timerModel.currentMode == .pureRest {
                timerModel.stopTimer()
            } else {
                timerModel.pauseTimer()
            }

        case .paused:
            // 暂停状态：继续计时器，并恢复音乐播放
            timerModel.startTimer(with: currentTask)

        case .completed:
            // 完成状态：重置计时器（为下一次做准备）
            timerModel.resetTimer()
        }
    }

    private func openMainWindow() {
        // 打开主窗口
        let windowManager = WindowManager.shared
        windowManager.showOrCreateMainWindow()
        
        // 关闭弹窗
        onClose()
    }
}

// MARK: - 预览
struct MenuBarPopoverView_Previews: PreviewProvider {
    static var previews: some View {
        MenuBarPopoverView(
            timerModel: TimerModel(),
            onClose: {}
        )
        .environmentObject(EventManager())
    }
}
