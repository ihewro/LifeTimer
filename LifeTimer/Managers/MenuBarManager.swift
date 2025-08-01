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
        // 清理订阅
        cancellables.removeAll()

        // 清理状态栏项
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil

        #if DEBUG
        print("MenuBarManager: 已清理资源")
        #endif
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

        // 清除之前的订阅，避免重复订阅
        cancellables.removeAll()

        // 监听计时器状态变化
        timerModel.$timerState
            .receive(on: DispatchQueue.main)
            .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main) // 防抖处理
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.updateMenuBarDisplay()
            }
            .store(in: &cancellables)

        // 监听时间变化
        timerModel.$timeRemaining
            .receive(on: DispatchQueue.main)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main) // 防抖处理
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.updateMenuBarDisplay()
            }
            .store(in: &cancellables)

        // 监听正计时时间变化
        timerModel.$currentTime
            .receive(on: DispatchQueue.main)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main) // 防抖处理
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.updateMenuBarDisplay()
            }
            .store(in: &cancellables)

        // 监听模式变化
        timerModel.$currentMode
            .receive(on: DispatchQueue.main)
            .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main) // 防抖处理
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.updateMenuBarDisplay()
            }
            .store(in: &cancellables)
    }
    
    private func updateMenuBarDisplay() {
        // 确保在主线程执行
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.updateMenuBarDisplay()
            }
            return
        }

        guard let statusItem = statusItem,
              let button = statusItem.button,
              let timerModel = timerModel else { return }

        // 防止在对象释放过程中更新UI
        guard !cancellables.isEmpty else { return }

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

        // 安全地更新UI元素
        autoreleasepool {
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

        // 使用 WindowManager 来处理窗口显示逻辑
        let windowManager = WindowManager.shared
        windowManager.showOrCreateMainWindow()
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
