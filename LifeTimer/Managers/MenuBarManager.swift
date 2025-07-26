//
//  MenuBarManager.swift
//  LifeTimer
//
//  Created by Developer on 2024.
//

#if canImport(Cocoa)
import Cocoa
import SwiftUI
import Combine

class MenuBarManager: ObservableObject {
    private var statusItem: NSStatusItem?
    private var timerModel: TimerModel?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // 延迟初始化状态栏项，确保在主线程和应用完全启动后执行
        DispatchQueue.main.async {
            self.setupStatusItem()
        }
    }
    
    deinit {
        statusItem = nil
    }
    
    func setTimerModel(_ timerModel: TimerModel) {
        self.timerModel = timerModel
        setupTimerObservers()
        updateMenuBarDisplay()
    }
    
    private func setupStatusItem() {
        // 确保在主线程执行
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.setupStatusItem()
            }
            return
        }

        // 检查是否已经创建过状态项
        guard statusItem == nil else { return }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let statusItem = statusItem else {
            NSLog("MenuBarManager: Failed to create status item")
            return
        }

        // 设置初始图标
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "计时器")
            button.image?.size = NSSize(width: 16, height: 16)
            button.image?.isTemplate = true
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp])

            // 设置初始标题，使用等宽字体
            let initialAttributedString = NSAttributedString(
                string: "00:00",
                attributes: [
                    .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
                ]
            )
            button.attributedTitle = initialAttributedString
        }

        NSLog("MenuBarManager: Menu bar status item created successfully")
    }
    
    private func setupTimerObservers() {
        guard let timerModel = timerModel else { return }
        
        // 监听计时器状态变化
        timerModel.$timerState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuBarDisplay()
            }
            .store(in: &cancellables)
        
        // 监听时间变化
        timerModel.$timeRemaining
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuBarDisplay()
            }
            .store(in: &cancellables)
        
        // 监听正计时时间变化
        timerModel.$currentTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuBarDisplay()
            }
            .store(in: &cancellables)
        
        // 监听模式变化
        timerModel.$currentMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuBarDisplay()
            }
            .store(in: &cancellables)
    }
    
    private func updateMenuBarDisplay() {
        guard let statusItem = statusItem,
              let button = statusItem.button,
              let timerModel = timerModel else { return }
        
        let timeString = formatTimeForMenuBar()
        
        // 更新图标（根据状态变化）
        let iconName: String
        switch timerModel.timerState {
        case .idle:
            iconName = "timer"
        case .running:
            iconName = "play.circle"
        case .paused:
            iconName = "pause.circle"
        case .completed:
            iconName = "checkmark.circle"
        }
        
        button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "计时器")
        button.image?.size = NSSize(width: 16, height: 16)
        button.image?.isTemplate = true
        
        // 更新标题文本，使用等宽字体
        let attributedString = NSAttributedString(
            string: timeString,
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            ]
        )
        button.attributedTitle = attributedString
        
        // 设置工具提示
        button.toolTip = "计时器 - \(timerModel.currentMode.rawValue) - \(getStateDescription())"
    }
    
    private func formatTimeForMenuBar() -> String {
        guard let timerModel = timerModel else { return "00:00" }
        
        let time: TimeInterval
        switch timerModel.currentMode {
        case .singlePomodoro, .pureRest, .custom:
            // 倒计时模式
            if timerModel.timerState == .idle {
                // 空闲时显示设定的总时间
                time = timerModel.totalTime
            } else {
                // 运行或暂停时显示剩余时间
                time = timerModel.timeRemaining
            }
        case .countUp:
            // 正计时模式
            if timerModel.timerState == .idle {
                // 空闲时显示00:00
                time = 0
            } else {
                // 运行或暂停时显示已计时时间
                time = timerModel.currentTime
            }
        }
        
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func getStateDescription() -> String {
        guard let timerModel = timerModel else { return "未知" }
        
        switch timerModel.timerState {
        case .idle:
            return "空闲"
        case .running:
            return "运行中"
        case .paused:
            return "已暂停"
        case .completed:
            return "已完成"
        }
    }
    
    @objc private func statusItemClicked() {
        NSLog("MenuBarManager: Status item clicked")

        // 首先激活应用
        NSApp.activate(ignoringOtherApps: true)

        // 使用多种策略尝试显示窗口
        if !tryShowExistingWindow() {
            NSLog("MenuBarManager: No existing window found, attempting to create new window")
            tryCreateNewWindow()
        }
    }

    /// 尝试显示现有窗口
    private func tryShowExistingWindow() -> Bool {
        // 策略1: 查找主应用窗口（改进的过滤逻辑）
        let mainWindows = findMainApplicationWindows()

        NSLog("MenuBarManager: Found \(mainWindows.count) main windows")

        // 首先尝试找到可见的窗口
        if let visibleWindow = mainWindows.first(where: { $0.isVisible && !$0.isMiniaturized }) {
            NSLog("MenuBarManager: Found visible window: \(visibleWindow.title)")
            bringWindowToFront(visibleWindow)
            return true
        }

        // 如果没有可见窗口，尝试找到最小化的窗口
        if let minimizedWindow = mainWindows.first(where: { $0.isMiniaturized }) {
            NSLog("MenuBarManager: Found minimized window: \(minimizedWindow.title)")
            minimizedWindow.deminiaturize(nil)
            bringWindowToFront(minimizedWindow)
            return true
        }

        // 如果有任何主窗口（即使不可见），尝试显示它
        if let anyMainWindow = mainWindows.first {
            NSLog("MenuBarManager: Found hidden window: \(anyMainWindow.title)")
            // 强制显示隐藏的窗口
            anyMainWindow.setIsVisible(true)
            bringWindowToFront(anyMainWindow)
            return true
        }

        // 如果智能提醒窗口正在显示，尝试通过通知来显示主窗口
        let smartReminderWindows = NSApp.windows.filter { window in
            window.title.contains("智能提醒") || window.className.contains("SmartReminder")
        }

        if !smartReminderWindows.isEmpty {
            NSLog("MenuBarManager: Smart reminder window is showing, trying to show main window")
            // 发送通知请求显示主窗口
            NotificationCenter.default.post(name: .init("ShowMainWindowFromMenuBar"), object: nil)
            return true
        }

        return false
    }

    /// 查找主应用窗口（改进的过滤逻辑）
    private func findMainApplicationWindows() -> [NSWindow] {
        return NSApp.windows.filter { window in
            // 更严格的过滤条件
            let className = window.className
            let windowTitle = window.title

            // 排除系统窗口
            let isSystemWindow = className.contains("NSStatusBarWindow") ||
                               className.contains("NSMenuWindow") ||
                               className.contains("NSPopover") ||
                               className.contains("NSAlert") ||
                               className.contains("NSPanel")

            // 排除智能提醒窗口
            let isSmartReminderWindow = windowTitle.contains("智能提醒") ||
                                      className.contains("SmartReminder")

            // 检查窗口是否属于我们的应用主窗口
            let isMainWindow = window.canBecomeMain &&
                             (windowTitle.contains("LifeTimer") ||
                              className.contains("AppKitWindow"))

            NSLog("MenuBarManager: Window check - \(className), title: '\(windowTitle)', canBecomeMain: \(window.canBecomeMain), isSystemWindow: \(isSystemWindow), isSmartReminderWindow: \(isSmartReminderWindow), isMainWindow:\(isMainWindow)")

            return isMainWindow && !isSystemWindow && !isSmartReminderWindow
        }
    }

    /// 将窗口置于前台
    private func bringWindowToFront(_ window: NSWindow) {
        // 使用多种方法确保窗口显示
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        // 确保窗口在所有空间中可见
        if #available(macOS 10.9, *) {
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        }

        // 强制激活应用并将窗口置于前台
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKey()
        }
    }

    /// 尝试创建新窗口
    private func tryCreateNewWindow() {
        var success = false

        // 策略1: 使用AppDelegate的方法
        if let appDelegate = NSApp.delegate {
            NSLog("MenuBarManager: Trying AppDelegate method")
            success = appDelegate.applicationShouldHandleReopen?(NSApp, hasVisibleWindows: false) ?? false
            if success {
                NSLog("MenuBarManager: AppDelegate method succeeded")
                return
            }
        }

        // // 策略2: 发送Cmd+N键盘事件
        // NSLog("MenuBarManager: Trying Cmd+N keyboard event")
        // if sendNewWindowKeyboardEvent() {
        //     success = true
        //     NSLog("MenuBarManager: Keyboard event sent successfully")
        // }

        // // 策略3: 尝试通过菜单项创建新窗口
        // if !success {
        //     NSLog("MenuBarManager: Trying menu item method")
        //     success = tryMenuItemNewWindow()
        // }

        // // 策略4: 最后的备用方案 - 延迟重试
        // if !success {
        //     NSLog("MenuBarManager: All methods failed, scheduling retry")
        //     DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        //         self.retryWindowCreation()
        //     }
        // }
    }

    /// 发送Cmd+N键盘事件
    private func sendNewWindowKeyboardEvent() -> Bool {
        guard let event = NSEvent.keyEvent(
            with: .keyDown,
            location: NSPoint.zero,
            modifierFlags: .command,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "n",
            charactersIgnoringModifiers: "n",
            isARepeat: false,
            keyCode: 45 // 'n' key code
        ) else {
            return false
        }

        NSApp.sendEvent(event)
        return true
    }

    /// 通过菜单项创建新窗口
    private func tryMenuItemNewWindow() -> Bool {
        // 尝试File菜单的New项
        if let fileMenu = NSApp.mainMenu?.item(withTitle: "File"),
           let newMenuItem = fileMenu.submenu?.item(withTitle: "New"),
           let action = newMenuItem.action {
            NSApp.sendAction(action, to: newMenuItem.target, from: nil)
            return true
        }

        // 尝试Window菜单的相关项
        if let windowMenu = NSApp.mainMenu?.item(withTitle: "Window") {
            for item in windowMenu.submenu?.items ?? [] {
                if item.title.contains("New") || item.keyEquivalent == "n" {
                    if let action = item.action {
                        NSApp.sendAction(action, to: item.target, from: nil)
                        return true
                    }
                }
            }
        }

        return false
    }

    /// 重试窗口创建
    private func retryWindowCreation() {
        NSLog("MenuBarManager: Retrying window creation")

        // 再次检查是否有窗口出现
        if tryShowExistingWindow() {
            NSLog("MenuBarManager: Window appeared during retry")
            return
        }

        // 最后的尝试：强制创建SwiftUI窗口
        DispatchQueue.main.async {
            // 这是一个备用方案，通过通知其他组件来创建窗口
            NotificationCenter.default.post(name: .init("ForceCreateWindow"), object: nil)

            // 如果仍然失败，记录错误
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if self.findMainApplicationWindows().isEmpty {
                    NSLog("MenuBarManager: ERROR - Failed to create or show window after all attempts")
                }
            }
        }
    }
}
#else
import SwiftUI
// iOS 版本的 MenuBarManager 空实现
class MenuBarManager: ObservableObject {
    init() {
        // iOS 上不需要菜单栏管理
    }

    func setTimerModel(_ timerModel: TimerModel) {
        // iOS 上不需要实现
    }
}
#endif
