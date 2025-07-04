//
//  MenuBarManager.swift
//  PomodoroTimer
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

            // 设置初始标题
            button.title = "00:00"
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
        
        // 更新标题文本
        button.title = timeString
        
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
        // 激活应用并显示主窗口
        NSApp.activate(ignoringOtherApps: true)
        
        // 如果有窗口，将其置于前台
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
#endif
