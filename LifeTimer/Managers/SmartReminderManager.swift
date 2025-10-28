//
//  SmartReminderManager.swift
//  LifeTimer
//
//  Created by Developer on 2024.
//

import SwiftUI
import Foundation
import Combine
#if canImport(Cocoa)
import Cocoa
#endif

/// 智能提醒状态
enum SmartReminderState {
    case idle           // 空闲状态，无提醒
    case counting       // 倒计时中
    case showing        // 显示提醒弹窗
}

/// 智能提醒管理器
/// 负责在用户无操作时显示提醒弹窗，引导用户开始计时
class SmartReminderManager: ObservableObject {
    // MARK: - Published Properties
    
    /// 当前提醒状态
    @Published var reminderState: SmartReminderState = .idle
    
    /// 智能提醒间隔时间（分钟），0表示禁用
    @Published var reminderInterval: Double = 5.0 {
        didSet {
            if reminderInterval != oldValue {
                saveSettings()
                if reminderInterval > 0 {
                    // 启用时开始监听
                    startListening()
                    // 如果当前有活跃的提醒倒计时，重新计算剩余时间
                    updateActiveReminderInterval(oldInterval: oldValue)
                } else {
                    // 禁用时停止所有提醒
                    stopReminder()
                }
            }
        }
    }

    /// 是否启用智能提醒功能（计算属性）
    var isEnabled: Bool {
        return reminderInterval > 0
    }
    
    /// 剩余提醒时间（秒）
    @Published var remainingTime: TimeInterval = 0
    
    /// 是否显示提醒弹窗（保留用于兼容性，但在 macOS 上使用独立窗口）
    @Published var showingReminderDialog: Bool = false

    /// 当前选中的任务（用于传递给弹窗）
    private var currentSelectedTask: String = ""
    
    // MARK: - Private Properties
    
    /// 提醒倒计时器
    private var reminderTimer: Timer?
    
    /// 计时器模型引用
    private weak var timerModel: TimerModel?
    
    /// 事件管理器引用
    private weak var eventManager: EventManager?
    
    /// UserDefaults 存储
    private let userDefaults = UserDefaults.standard
    
    /// 设置键
    private let reminderIntervalKey = "SmartReminderInterval"
    
    /// 应用生命周期监听
    private var appStateObserver: NSObjectProtocol?

    /// Combine订阅管理
    private var cancellables = Set<AnyCancellable>()

    
    // MARK: - Initialization
    
    init() {
        loadSettings()
        setupAppStateObserver()

        // 集中化：监听全局“计时开始”事件，统一关闭智能提醒弹窗
        NotificationCenter.default.addObserver(
            forName: .timerDidStart,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onUserStartedTimer()
        }
    }
    
    deinit {
        stopReminder()
        // 取消所有Combine订阅
        cancellables.removeAll()
        // 移除所有通知监听器
        NotificationCenter.default.removeObserver(self)
        if let observer = appStateObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Public Methods
    
    /// 设置计时器模型依赖
    func setTimerModel(_ timerModel: TimerModel) {
        // 如果已经设置过相同的timerModel，不需要重复设置
        if self.timerModel === timerModel {
            return
        }

        self.timerModel = timerModel
        startListening()
    }
    
    /// 设置事件管理器依赖
    func setEventManager(_ eventManager: EventManager) {
        self.eventManager = eventManager
    }

    /// 开始监听计时器状态变化
    func startListening() {
        guard isEnabled, let timerModel = timerModel else { return }

        // 移除之前的监听器，避免重复添加
        NotificationCenter.default.removeObserver(self, name: .timerCompleted, object: nil)

        // 监听计时器完成事件
        NotificationCenter.default.addObserver(
            forName: .timerCompleted,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.onTimerCompleted(notification)
        }

        // 监听计时器状态变化（通过定时检查）
        startTimerStateMonitoring()

        // 只有在空闲状态且没有活跃提醒时，才开始提醒倒计时
        if timerModel.timerState == .idle && reminderState == .idle {
            startReminderCountdown()
        }
    }
    
    /// 停止提醒
    func stopReminder() {
        reminderTimer?.invalidate()
        reminderTimer = nil
        reminderState = .idle
        remainingTime = 0
        showingReminderDialog = false

        // 关闭独立窗口（macOS）
        #if os(macOS)
        SmartReminderWindowManager.shared.closeReminderDialog()
        #endif
    }
    
    /// 用户开始计时时调用（重置提醒状态）
    func onUserStartedTimer() {
        stopReminder()
    }
    
    /// 延迟提醒（用户选择稍后提醒时调用）
    func snoozeReminder(minutes: Int) {
        showingReminderDialog = false
        reminderState = .counting
        remainingTime = TimeInterval(minutes * 60)
        startReminderTimer()

        // 关闭独立窗口（macOS）
        #if os(macOS)
        SmartReminderWindowManager.shared.closeReminderDialog()
        #endif
    }

    /// 设置当前选中的任务（用于传递给弹窗）
    func setCurrentTask(_ task: String) {
        currentSelectedTask = task
    }

    /// 测试方法：手动触发智能提醒弹窗（用于调试和测试）
    func testShowReminder() {
        print("🔔 测试显示智能提醒弹窗")
        showReminder()
    }

    // MARK: - Private Methods
    
    /// 加载设置
    private func loadSettings() {
        // 默认5分钟提醒间隔
        if userDefaults.object(forKey: reminderIntervalKey) != nil {
            reminderInterval = userDefaults.double(forKey: reminderIntervalKey)
        }
    }

    /// 保存设置
    private func saveSettings() {
        userDefaults.set(reminderInterval, forKey: reminderIntervalKey)
    }
    
    /// 设置应用状态监听
    private func setupAppStateObserver() {
        #if canImport(Cocoa)
        // macOS 应用激活/失活监听
        appStateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onAppBecameActive()
        }
        #endif
    }
    
    /// 应用变为活跃状态时的处理
    private func onAppBecameActive() {
        // 如果提醒功能启用且计时器空闲，检查是否需要开始提醒
        guard isEnabled, let timerModel = timerModel, timerModel.timerState == .idle else { return }
        
        if reminderState == .idle {
            startReminderCountdown()
        }
    }
    
    /// 计时器完成时的处理
    private func onTimerCompleted(_ notification: Notification) {
        guard isEnabled else { return }

        // 检查是否是任务切换产生的部分事件
        if let userInfo = notification.userInfo,
           let isPartial = userInfo["isPartial"] as? Bool,
           isPartial {
            // 如果是任务切换产生的部分事件，不启动智能提醒
            print("🔔 智能提醒: 检测到任务切换事件，不启动提醒倒计时")
            return
        }

        // 只有真正的计时完成才启动提醒倒计时
        startReminderCountdown()
    }

    /// 开始计时器状态监控
    private func startTimerStateMonitoring() {
        guard let timerModel = timerModel else { return }

        // 移除之前的事件订阅，避免重复订阅导致多次回调
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()

        // 使用 Combine 事件驱动订阅计时器状态变化，减少不必要的轮询开销
        timerModel.$timerState
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                self?.onTimerStateChanged(newState)
            }
            .store(in: &cancellables)
    }

    

    /// 计时器状态变化时的处理
    private func onTimerStateChanged(_ newState: TimerState) {
        guard isEnabled else { return }

        // 当计时器开始运行时（从任何状态变为running），立即关闭提醒弹窗
        if newState == .running {
            stopReminder()
            return
        }

        // 当计时器变为空闲状态时（包括被重置/放弃），开始提醒倒计时
        if newState == .idle && reminderState == .idle {
            startReminderCountdown()
        }
    }
    
    /// 开始提醒倒计时
    private func startReminderCountdown() {
        guard isEnabled else { return }

        reminderState = .counting
        remainingTime = reminderInterval * 60 // 转换为秒
        startReminderTimer()
    }
    
    /// 启动提醒计时器
    private func startReminderTimer() {
        reminderTimer?.invalidate()
        
        reminderTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateReminderTimer()
            }
        }
    }
    
    /// 更新提醒计时器
    private func updateReminderTimer() {
        guard remainingTime > 0 else {
            showReminder()
            return
        }
        
        remainingTime -= 1
    }
    
    /// 显示提醒弹窗
    private func showReminder() {
        reminderTimer?.invalidate()
        reminderTimer = nil
        reminderState = .showing
        remainingTime = 0

        #if os(macOS)
        // macOS 使用独立窗口
        if let timerModel = timerModel, let eventManager = eventManager {
            SmartReminderWindowManager.shared.showReminderDialog(
                timerModel: timerModel,
                reminderManager: self,
                selectedTask: currentSelectedTask,
                eventManager: eventManager
            )
        }
        #else
        // iOS 使用 sheet
        showingReminderDialog = true
        #endif
    }
    
    /// 格式化剩余时间显示
    func formatRemainingTime() -> String {
        let minutes = Int(remainingTime) / 60
        let seconds = Int(remainingTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// 更新活跃提醒的间隔时间
    private func updateActiveReminderInterval(oldInterval: Double) {
        // 只有在倒计时状态下才需要更新
        guard reminderState == .counting, oldInterval > 0 else { return }

        // 计算已经过去的时间比例
        let oldTotalTime = oldInterval * 60 // 旧的总时间（秒）
        let elapsedTime = oldTotalTime - remainingTime // 已经过去的时间
        let elapsedRatio = elapsedTime / oldTotalTime // 已过去时间的比例

        // 根据比例计算新的剩余时间
        let newTotalTime = reminderInterval * 60 // 新的总时间（秒）
        let newElapsedTime = newTotalTime * elapsedRatio // 新的已过去时间
        let newRemainingTime = newTotalTime - newElapsedTime // 新的剩余时间

        // 确保剩余时间不为负数
        remainingTime = max(0, newRemainingTime)

        // 如果剩余时间为0，立即显示提醒
        if remainingTime <= 0 {
            showReminder()
        }
    }
}
