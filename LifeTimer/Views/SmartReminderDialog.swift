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

    @State private var customFocusMinutes: String = ""
    @State private var customBreakMinutes: String = ""
    @State private var customSnoozeMinutes: String = ""

    @FocusState private var isFocusInputFocused: Bool
    @FocusState private var isBreakInputFocused: Bool
    @FocusState private var isSnoozeInputFocused: Bool

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
        VStack(spacing: 24) {
            // 标题区域
            VStack(spacing: 8) {
                Text("⏰ 该开始计时了！")
                    .font(.title)
                    .fontWeight(.semibold)

                Text("不要荒废电脑面前的无用时间，选择一个行动开始吧")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // 主要操作区域
            VStack(spacing: 16) {
                // 开始专注区域
                focusSection

                Divider()

                // 开始休息区域
                breakSection

                Divider()

                // 稍后提醒区域
                snoozeSection
            }

            //  底部按钮
            HStack(spacing: 12) {
                Button("稍后提醒") {
                    snooze(minutes: Int(reminderManager.reminderInterval))
                }
                .buttonStyle(.bordered)

                Spacer()
            }
        }
        .frame(width: 480)
        .padding(24)
        .background(backgroundView)
        .cornerRadius(12)
    }
    
    // MARK: - 开始专注区域
    private var focusSection: some View {
        VStack(spacing: 12) {
            Text("🍅 开始专注")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 快捷按钮
            HStack(spacing: 12) {
                ForEach([5, 10, 30], id: \.self) { minutes in
                    Button(action: {
                        startFocus(minutes: minutes)
                    }) {
                        Text("\(minutes)分钟")
                            .font(.title3)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)
                }
            }

            // 自定义时间输入
            HStack(spacing: 8) {
                Text("自定义:")
                    .font(.subheadline)

                TextField("分钟", text: $customFocusMinutes)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .focused($isFocusInputFocused)
                    .onSubmit {
                        startCustomFocus()
                    }

                Button("开始") {
                    startCustomFocus()
                }
                .buttonStyle(.bordered)
                .disabled(customFocusMinutes.isEmpty || Int(customFocusMinutes) == nil)
            }
        }
    }
    
    // MARK: - 开始休息区域
    private var breakSection: some View {
        VStack(spacing: 12) {
            Text("☕ 开始休息")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 快捷按钮
            HStack(spacing: 12) {
                ForEach([5, 15, 30], id: \.self) { minutes in
                    Button(action: {
                        startBreak(minutes: minutes)
                    }) {
                        Text("\(minutes)分钟")
                            .font(.title3)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)
                }
            }

            // 自定义时间输入
            HStack(spacing: 8) {
                Text("自定义:")
                    .font(.subheadline)

                TextField("分钟", text: $customBreakMinutes)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .focused($isBreakInputFocused)
                    .onSubmit {
                        startCustomBreak()
                    }

                Button("开始") {
                    startCustomBreak()
                }
                .buttonStyle(.bordered)
                .disabled(customBreakMinutes.isEmpty || Int(customBreakMinutes) == nil)
            }
        }
    }
    
    // MARK: - 稍后提醒区域
    private var snoozeSection: some View {
        VStack(spacing: 12) {
            Text("⏰ 稍后提醒")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 快捷按钮
            HStack(spacing: 12) {
                ForEach([5, 15, 30], id: \.self) { minutes in
                    Button(action: {
                        snooze(minutes: minutes)
                    }) {
                        Text("\(minutes)分钟")
                            .font(.title3)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)
                }
            }

            // 自定义时间输入
            HStack(spacing: 8) {
                Text("自定义:")
                    .font(.subheadline)

                TextField("分钟", text: $customSnoozeMinutes)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .focused($isSnoozeInputFocused)
                    .onSubmit {
                        snoozeCustom()
                    }

                Button("设置") {
                    snoozeCustom()
                }
                .buttonStyle(.bordered)
                .disabled(customSnoozeMinutes.isEmpty || Int(customSnoozeMinutes) == nil)
            }
        }
    }
    
    // MARK: - 操作方法
    
    private func startFocus(minutes: Int) {
        // 防止在关闭过程中执行操作
        guard !isClosing else { return }

        timerModel.resetTimer()
        timerModel.setCustomTime(minutes: minutes)
        timerModel.currentMode = .singlePomodoro
        timerModel.startTimer(with: selectedTask)
        reminderManager.onUserStartedTimer()
    }
    
    private func startCustomFocus() {
        guard let minutes = Int(customFocusMinutes), minutes > 0, minutes <= 99 else { return }
        startFocus(minutes: minutes)
    }

    private func startBreak(minutes: Int) {
        // 防止在关闭过程中执行操作
        guard !isClosing else { return }

        timerModel.resetTimer()
        timerModel.setCustomTime(minutes: minutes)
        timerModel.currentMode = .pureRest
        timerModel.startTimer(with: "休息")
        reminderManager.onUserStartedTimer()
    }

    private func startCustomBreak() {
        guard let minutes = Int(customBreakMinutes), minutes > 0, minutes <= 99 else { return }
        startBreak(minutes: minutes)
    }

    private func snooze(minutes: Int) {
        // 防止在关闭过程中执行操作
        guard !isClosing else { return }

        reminderManager.snoozeReminder(minutes: minutes)
    }

    private func snoozeCustom() {
        guard let minutes = Int(customSnoozeMinutes), minutes > 0, minutes <= 99 else { return }
        snooze(minutes: minutes)
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
    }
}
