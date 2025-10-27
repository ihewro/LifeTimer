//
//  SmartReminderDialog.swift
//  LifeTimer
//
//  Created by Developer on 2024.
//

import SwiftUI
#if canImport(Cocoa)
import Cocoa
#endif

/// 智能提醒弹窗
struct SmartReminderDialog: View {
    @Binding var isPresented: Bool
    @ObservedObject var timerModel: TimerModel
    @ObservedObject var reminderManager: SmartReminderManager
    let selectedTask: String
    
    @EnvironmentObject var eventManager: EventManager

    @State private var currentTask: String = ""
    @State private var showingTaskSelector = false
    @State private var isClosing: Bool = false

    /// 背景视图
    @ViewBuilder
    private var backgroundView: some View {
        #if os(macOS)
        // macOS 使用毛玻璃效果
        GlassEffectBackground()
        #else
        // iOS 使用系统背景
        Color.systemBackground
        #endif
    }

    var body: some View {
        VStack(spacing: 16) {
            // 标题区域
            VStack(spacing: 6) {
                Text("⏰ 该开始计时了！")
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
                Button("稍后提醒") {
                    snooze(minutes: Int(reminderManager.reminderInterval))
                }
                .buttonStyle(.bordered)

                Spacer()
            }
        }
        .frame(width: 320)
        .padding(20)
        .background(backgroundView)
        .cornerRadius(12)
        .onAppear {
            // 初始化当前任务
            currentTask = timerModel.getCurrentDisplayTask(fallback: selectedTask)
        }
        // 当弹窗内选择的任务变化时，同步到计时器模型，保证与主界面一致
        .onChange(of: currentTask) { newTask in
            timerModel.setUserCustomTask(newTask)
        }
        // 当 TimerView 或其他位置更新了任务（写入 TimerModel）时，这里也同步更新
        .onChange(of: timerModel.userCustomTaskTitle) { newTitle in
            if !newTitle.isEmpty {
                currentTask = newTitle
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
        // 防止在关闭过程中执行操作
        guard !isClosing else { return }

        timerModel.resetTimer()
        timerModel.setCustomTime(minutes: minutes)
        timerModel.currentMode = .singlePomodoro
        
        // 使用当前选择的任务，如果为空则使用默认任务
        let taskToUse = currentTask.isEmpty ? selectedTask : currentTask
        timerModel.startTimer(with: taskToUse)
        reminderManager.onUserStartedTimer()
        
        // 关闭弹窗
        isPresented = false
    }

    private func snooze(minutes: Int) {
        // 防止在关闭过程中执行操作
        guard !isClosing else { return }

        reminderManager.snoozeReminder(minutes: minutes)
        
        // 关闭弹窗
        isPresented = false
    }

}

// MARK: - 预览
struct SmartReminderDialog_Previews: PreviewProvider {
    static var previews: some View {
        SmartReminderDialog(
            isPresented: .constant(true),
            timerModel: TimerModel(),
            reminderManager: SmartReminderManager(),
            selectedTask: "示例任务"
        )
        .environmentObject(EventManager())
    }
}
