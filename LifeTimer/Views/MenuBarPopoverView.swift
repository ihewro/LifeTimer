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

/// 菜单栏弹窗视图，复用SmartReminderDialog的UI和功能
struct MenuBarPopoverView: View {
    @ObservedObject var timerModel: TimerModel
    @EnvironmentObject var eventManager: EventManager
    
    @State private var currentTask: String = ""
    @State private var showingTaskSelector = false
    
    // 关闭弹窗的回调
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // 根据计时状态显示不同内容
            if timerModel.timerState == .idle {
                // 未开始计时时的UI
                idleStateView
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
            currentTask = timerModel.getCurrentDisplayTask(fallback: "")
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
    }
    
    // MARK: - 未开始计时时的视图
    private var idleStateView: some View {
        VStack(spacing: 16) {
            // 标题区域
            VStack(spacing: 6) {
                Text("⏰ 开始计时")
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
    
    // MARK: - 计时中的视图
    private var runningStateView: some View {
        VStack(spacing: 16) {
            // 标题区域
            VStack(spacing: 6) {
                Text("⏰ 计时进行中")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(timerModel.getCurrentDisplayTask(fallback: currentTask))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            // 时间显示
            VStack(spacing: 8) {
                Text(timerModel.formattedTime())
                    .font(.system(size: 48, weight: .light, design: .monospaced))
                    .foregroundColor(.primary)
                
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
    
    // MARK: - 计时控制按钮
    private var timerControlButtons: some View {
        VStack(spacing: 8) {
            // 番茄钟运行时显示放弃和提前结束按钮
            if timerModel.currentMode == .singlePomodoro && timerModel.timerState == .running {
                HStack(spacing: 8) {
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
            // 番茄钟暂停时显示继续按钮
            else if timerModel.currentMode == .singlePomodoro && timerModel.timerState == .paused {
                Button("继续") {
                    timerModel.startTimer(with: currentTask)
                    onClose()
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .frame(maxWidth: .infinity)
            }
            // 其他状态的控制按钮
            else {
                Button("停止计时") {
                    timerModel.resetTimer()
                    onClose()
                }
                .buttonStyle(.borderedProminent)
                .tint(.secondary)
                .frame(maxWidth: .infinity)
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
                    focusTimeButton(minutes: 50)
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
        let taskToUse = currentTask.isEmpty ? "专注任务" : currentTask
        timerModel.startTimer(with: taskToUse)
        
        // 关闭弹窗
        onClose()
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