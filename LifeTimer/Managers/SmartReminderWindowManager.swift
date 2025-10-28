//
//  SmartReminderWindowManager.swift
//  LifeTimer
//
//  Created by Developer on 2024.
//

import SwiftUI
#if canImport(Cocoa)
import Cocoa
#endif

/// 智能提醒弹窗的独立窗口管理器
#if os(macOS)
class SmartReminderWindowManager: ObservableObject {
    static let shared = SmartReminderWindowManager()

    private var reminderWindow: NSWindow?
    private var hostingController: NSHostingController<AnyView>?
    private var windowCloseObserver: NSObjectProtocol?
    private var isClosing: Bool = false

    private init() {}

    /// 显示番茄钟完成弹窗（窗口级别）
    func showCompletionDialog(
        timerModel: TimerModel,
        smartReminderManager: SmartReminderManager,
        selectedTask: String,
        eventManager: EventManager
    ) {
        // 如果窗口已经存在，先关闭以避免冲突
        closeCompletionDialog()

        isClosing = false

        // 创建完成弹窗内容视图：复用 MenuBarPopoverView 的完成状态 UI
        let completionView = AnyView(
            MenuBarPopoverView(
                timerModel: timerModel,
                mode: .reminder,
                defaultTaskFallback: selectedTask,
                onClose: {
                    SmartReminderWindowManager.shared.closeCompletionDialog()
                }
            )
            .environmentObject(eventManager)
            .environmentObject(smartReminderManager)
            .background(GlassEffectBackground())
            .cornerRadius(12)
        )

        // 创建 hosting controller
        hostingController = NSHostingController(rootView: completionView)

        // 创建窗口（与提醒窗口同样的轻量级样式）
        reminderWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 50, width: 480, height: 600),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        guard let window = reminderWindow, let controller = hostingController else { return }

        // 配置并显示窗口
        configureWindow(window)
        window.contentViewController = controller
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)

        // 监听关闭事件（与提醒窗口复用同一套逻辑）
        setupWindowCloseObserver()
    }

    /// 显示智能提醒弹窗
    func showReminderDialog(
        timerModel: TimerModel,
        reminderManager: SmartReminderManager,
        selectedTask: String,
        eventManager: EventManager
    ) {
        // 如果窗口已经存在，先关闭
        closeReminderDialog()

        // 重置关闭状态
        isClosing = false
        
        // 创建 SwiftUI 视图
        let reminderDialog = AnyView(
            SmartReminderDialog(
                isPresented: .constant(true),
                timerModel: timerModel,
                reminderManager: reminderManager,
                selectedTask: selectedTask
            )
            .environmentObject(eventManager)
        )
        
        // 创建 hosting controller
        hostingController = NSHostingController(rootView: reminderDialog)
        
        // 创建窗口 - 使用更简单的样式避免复杂的窗口管理
        reminderWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 50, width: 480, height: 600),
            styleMask: [.titled, .fullSizeContentView], // 简化窗口样式
            backing: .buffered,
            defer: false
        )
        
        guard let window = reminderWindow, let controller = hostingController else { return }
        
        // 配置窗口属性
        configureWindow(window)
        
        // 设置内容视图
        window.contentViewController = controller
        
        // 居中显示窗口
        window.center()
        
        // 显示窗口并置于前台
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        
        // 激活应用
        NSApp.activate(ignoringOtherApps: true)
        
        // 监听关闭事件
        setupWindowCloseObserver()
    }
    
    /// 关闭智能提醒弹窗
    func closeReminderDialog() {
        // 确保在主线程执行
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.closeReminderDialog()
            }
            return
        }

        // 防止重复调用
        guard !isClosing else { return }
        guard reminderWindow != nil || hostingController != nil || windowCloseObserver != nil else { return }

        // 设置关闭状态
        isClosing = true

        // 先清理引用，再关闭窗口
        let windowToClose = reminderWindow
        reminderWindow = nil
        hostingController = nil
        cleanupWindow()
        windowToClose?.close()
        isClosing = false  // 重置关闭状态
    }

    /// 关闭番茄钟完成弹窗（与提醒弹窗共用同一窗口）
    func closeCompletionDialog() {
        closeReminderDialog()
    }





    /// 配置窗口属性
    private func configureWindow(_ window: NSWindow) {
        // 窗口置顶显示
        window.level = .floating

        // 简化窗口配置，避免复杂的标题栏设置
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true

        // 隐藏窗口按钮
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.standardWindowButton(.closeButton)?.isHidden = true

        // 基本窗口行为设置
        window.isMovableByWindowBackground = true
        window.canHide = false
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false

        // 确保窗口在所有空间中可见
        if #available(macOS 10.9, *) {
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        }

        // 设置背景
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true

        // 禁用不必要的功能，可能与 TouchBar 相关
        window.toolbar = nil
        if #available(macOS 10.12.2, *) {
            window.touchBar = nil
        }
        window.standardWindowButton(.closeButton)?.isEnabled = true

    }
    
    /// 设置窗口关闭监听
    private func setupWindowCloseObserver() {
        guard let window = reminderWindow else { return }

        // 移除之前的观察者（如果存在）
        if let observer = windowCloseObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        windowCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            // 当用户点击关闭按钮时，清理资源
            DispatchQueue.main.async {
                self?.cleanupWindow()
            }
        }
    }

    /// 清理窗口资源的统一方法
    private func cleanupWindow() {
        // 移除观察者
        if let observer = windowCloseObserver {
            NotificationCenter.default.removeObserver(observer)
            windowCloseObserver = nil
        }

        // 清理窗口引用
        reminderWindow = nil
        hostingController = nil
        isClosing = false  // 重置关闭状态
    }
}



#else
// iOS 版本的空实现
class SmartReminderWindowManager: ObservableObject {
    static let shared = SmartReminderWindowManager()

    private init() {}

    func showReminderDialog(
        timerModel: TimerModel,
        reminderManager: SmartReminderManager,
        selectedTask: String
    ) {
        // iOS 上不需要实现独立窗口
    }

    func closeReminderDialog() {
        // iOS 上不需要实现
    }

    func moveWindow(by translation: CGSize) {
        // iOS 上不需要实现
    }

    func showCompletionDialog(
        timerModel: TimerModel,
        smartReminderManager: SmartReminderManager,
        selectedTask: String,
        eventManager: EventManager
    ) {
        // iOS 不支持窗口级别弹窗，留空实现
    }

    func closeCompletionDialog() {
        // iOS 上不需要实现
    }
}
#endif
