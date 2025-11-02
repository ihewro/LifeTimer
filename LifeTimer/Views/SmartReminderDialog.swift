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

/// 智能提醒弹窗（复用菜单栏弹窗视图）
struct SmartReminderDialog: View {
    @Binding var isPresented: Bool
    @ObservedObject var timerModel: TimerModel
    @ObservedObject var reminderManager: SmartReminderManager
    let selectedTask: String

    @EnvironmentObject var eventManager: EventManager
    
    /// 背景视图（macOS 使用毛玻璃）
    @ViewBuilder
    private var backgroundView: some View {
        #if os(macOS)
        GlassEffectBackground()
        #else
        Color.systemBackground
        #endif
    }

    var body: some View {
        MenuBarPopoverView(
            timerModel: timerModel,
            mode: .reminder,
            defaultTaskFallback: selectedTask,
            onClose: {
                #if os(macOS)
                // 在独立窗口模式下，必须通过窗口管理器显式关闭窗口
                SmartReminderWindowManager.shared.closeReminderDialog()
                #else
                // 非 macOS 平台使用绑定控制显示
                isPresented = false
                #endif
            }
        )
        .environmentObject(eventManager)
        .environmentObject(reminderManager)
        .background(backgroundView)
        .cornerRadius(12)
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
