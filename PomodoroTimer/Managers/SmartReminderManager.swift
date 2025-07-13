//
//  SmartReminderManager.swift
//  PomodoroTimer
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
    
    /// 是否显示提醒弹窗
    @Published var showingReminderDialog: Bool = false
    
    // MARK: - Private Properties
    
    /// 提醒倒计时器
    private var reminderTimer: Timer?
    
    /// 计时器模型引用
    private weak var timerModel: TimerModel?
    
    /// UserDefaults 存储
    private let userDefaults = UserDefaults.standard
    
    /// 设置键
    private let reminderIntervalKey = "SmartReminderInterval"
    
    /// 应用生命周期监听
    private var appStateObserver: NSObjectProtocol?

    /// Combine订阅管理
    private var cancellables = Set<AnyCancellable>()

    /// 计时器状态监控定时器
    private var stateMonitorTimer: Timer?

    /// 上次检查的计时器状态
    private var lastTimerState: TimerState = .idle
    
    // MARK: - Initialization
    
    init() {
        loadSettings()
        setupAppStateObserver()
    }
    
    deinit {
        stopReminder()
        // 取消所有Combine订阅
        cancellables.removeAll()
        // 停止状态监控定时器
        stateMonitorTimer?.invalidate()
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
        ) { [weak self] _ in
            self?.onTimerCompleted()
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
        stateMonitorTimer?.invalidate()
        stateMonitorTimer = nil
        reminderState = .idle
        remainingTime = 0
        showingReminderDialog = false
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
    private func onTimerCompleted() {
        guard isEnabled else { return }
        startReminderCountdown()
    }

    /// 开始计时器状态监控
    private func startTimerStateMonitoring() {
        guard let timerModel = timerModel else { return }

        // 记录初始状态
        lastTimerState = timerModel.timerState

        // 停止之前的监控定时器
        stateMonitorTimer?.invalidate()

        // 启动状态监控定时器，每秒检查一次
        stateMonitorTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.checkTimerStateChange()
            }
        }
    }

    /// 检查计时器状态变化
    private func checkTimerStateChange() {
        guard let timerModel = timerModel else { return }

        let currentState = timerModel.timerState
        if currentState != lastTimerState {
            onTimerStateChanged(currentState)
            lastTimerState = currentState
        }
    }

    /// 计时器状态变化时的处理
    private func onTimerStateChanged(_ newState: TimerState) {
        guard isEnabled else { return }

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
        showingReminderDialog = true
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
