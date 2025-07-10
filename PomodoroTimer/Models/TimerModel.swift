//
//  TimerModel.swift
//  PomodoroTimer
//
//  Created by Developer on 2024.
//

import Foundation
import Combine

enum TimerMode: Equatable, Hashable, CaseIterable {
    case singlePomodoro
    case pureRest
    case countUp
    case custom(minutes: Int)

    var rawValue: String {
        switch self {
        case .singlePomodoro:
            return "单次番茄"
        case .pureRest:
            return "纯休息"
        case .countUp:
            return "正计时"
        case .custom(let minutes):
            return "自定义 \(minutes)分钟"
        }
    }

    static var allCases: [TimerMode] {
        return [.singlePomodoro, .pureRest, .countUp]
    }
}

enum TimerState {
    case idle
    case running
    case paused
    case completed
}

class TimerModel: ObservableObject {
    @Published var currentMode: TimerMode = .singlePomodoro
    @Published var timerState: TimerState = .idle
    @Published var timeRemaining: TimeInterval = 25 * 60 // 默认25分钟
    @Published var totalTime: TimeInterval = 25 * 60
    @Published var currentTime: TimeInterval = 0 // 用于正计时模式

    // 计时器会话记录
    @Published var sessionStartTime: Date?
    @Published var sessionTask: String = ""

    // 用户自定义的任务标题（在计时会话期间保持）
    @Published var userCustomTaskTitle: String = ""
    @Published var hasUserSetCustomTask: Bool = false

    // 音频管理器引用（用于计时器联动）
    weak var audioManager: AudioManager?

    // 音效管理器引用
    private let soundEffectManager = SoundEffectManager.shared

    // 设置（永久保存的默认值）
    @Published var pomodoroTime: TimeInterval = 25 * 60 { // 25分钟
        didSet {
            if pomodoroTime != oldValue {
                saveSettings()
                notifySettingsChanged()
                // 如果当前是番茄模式且处于idle状态，更新时间
                if currentMode == .singlePomodoro && timerState == .idle {
                    setupTimer()
                }
            }
        }
    }
    @Published var shortBreakTime: TimeInterval = 5 * 60 { // 5分钟
        didSet {
            if shortBreakTime != oldValue {
                saveSettings()
                notifySettingsChanged()
                // 如果当前是休息模式且处于idle状态，更新时间
                if currentMode == .pureRest && timerState == .idle {
                    setupTimer()
                }
            }
        }
    }
    @Published var longBreakTime: TimeInterval = 15 * 60 { // 15分钟
        didSet {
            if longBreakTime != oldValue {
                saveSettings()
                notifySettingsChanged()
            }
        }
    }

    // 当前会话的临时时间设置（不会保存到设置中）
    private var currentSessionPomodoroTime: TimeInterval?
    private var currentSessionBreakTime: TimeInterval?

    // 自动休息设置
    @Published var autoStartBreak: Bool = false {
        didSet {
            if autoStartBreak != oldValue {
                saveSettings()
                notifySettingsChanged()
            }
        }
    }

    // 跟踪是否是从番茄模式进入的休息
    var isBreakFromPomodoro: Bool = false

    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let userDefaults = UserDefaults.standard

    // 设置变更通知
    static let settingsChangedNotification = Notification.Name("TimerSettingsChanged")

    // UserDefaults 键
    private let pomodoroTimeKey = "PomodoroTime"
    private let shortBreakTimeKey = "ShortBreakTime"
    private let longBreakTimeKey = "LongBreakTime"
    private let autoStartBreakKey = "AutoStartBreak"

    init() {
        loadSettings()
        setupTimer()
    }
    
    private func setupTimer() {
        switch currentMode {
        case .singlePomodoro:
            // 使用当前会话的临时时间，如果没有则使用默认设置
            let sessionTime = currentSessionPomodoroTime ?? pomodoroTime
            timeRemaining = sessionTime
            totalTime = sessionTime
        case .pureRest:
            // 使用当前会话的临时时间，如果没有则使用默认设置
            let sessionTime = currentSessionBreakTime ?? shortBreakTime
            timeRemaining = sessionTime
            totalTime = sessionTime
        case .countUp:
            currentTime = 0
            totalTime = 0
        case .custom(let minutes):
            let customTime = TimeInterval(minutes * 60)
            timeRemaining = customTime
            totalTime = customTime
        }
    }
    
    func startTimer(with task: String = "") {
        guard timerState != .running else { return }

        // 记录会话开始时间（只在从idle状态开始时记录）
        if timerState == .idle {
            sessionStartTime = Date()
            sessionTask = task
            // 如果用户设置了自定义任务，使用自定义任务
            if hasUserSetCustomTask {
                sessionTask = userCustomTaskTitle
            }
        }

        timerState = .running

        // 开始计时器时播放音乐（仅在番茄模式和正计时模式）
        if currentMode == .singlePomodoro || currentMode == .countUp {
            audioManager?.startTimerPlayback()
        }

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                self.updateTimer()
            }
        }
    }
    
    func pauseTimer() {
        timerState = .paused
        timer?.invalidate()
        timer = nil

        // 暂停计时器时暂停音乐
        audioManager?.pauseTimerPlayback()
    }

    func resetTimer() {
        timerState = .idle
        timer?.invalidate()
        timer = nil
        sessionStartTime = nil

        // 重置用户自定义任务状态
        hasUserSetCustomTask = false
        userCustomTaskTitle = ""

        setupTimer()

        // 重置计时器时停止音乐
        audioManager?.stopTimerPlayback()
    }
    
    func changeMode(_ mode: TimerMode) {
        resetTimer()
        currentMode = mode
        isBreakFromPomodoro = false // 重置标志
        resetSessionTimes() // 重置临时时间设置
        setupTimer()
    }

    func setCustomTime(minutes: Int) {
        guard timerState == .idle else { return }

        // 如果当前是番茄模式，只修改当前会话的临时时间，不影响永久设置
        if currentMode == .singlePomodoro {
            currentSessionPomodoroTime = TimeInterval(minutes * 60)
            setupTimer()
        } else if currentMode == .pureRest {
            // 如果当前是休息模式，只修改当前会话的临时时间，不影响永久设置
            currentSessionBreakTime = TimeInterval(minutes * 60)
            setupTimer()
        } else {
            // 其他模式才切换到自定义模式
            currentMode = .custom(minutes: minutes)
            setupTimer()
        }
    }

    /// 重置当前会话的临时时间设置，回到默认设置
    func resetSessionTimes() {
        currentSessionPomodoroTime = nil
        currentSessionBreakTime = nil
    }

    /// 获取当前实际使用的番茄钟时间（包括临时调整）
    func getCurrentPomodoroTime() -> TimeInterval {
        return currentSessionPomodoroTime ?? pomodoroTime
    }

    /// 获取当前实际使用的休息时间（包括临时调整）
    func getCurrentBreakTime() -> TimeInterval {
        return currentSessionBreakTime ?? shortBreakTime
    }

    func stopTimer() {
        // 手动停止计时器
        if currentMode == .countUp && timerState == .running {
            completeTimer()
        } else if currentMode == .pureRest && timerState == .running && isBreakFromPomodoro {
            // 如果是从番茄模式进入的休息，结束后返回番茄模式
            isBreakFromPomodoro = false
            returnToPomodoroMode()
        } else {
            resetTimer()
        }
    }
    
    private func updateTimer() {
        switch currentMode {
        case .singlePomodoro, .pureRest, .custom:
            if timeRemaining > 0 {
                timeRemaining -= 1

                // 番茄钟模式下，剩余1分钟时播放预警音效和发送通知
                if currentMode == .singlePomodoro && timeRemaining == 60 {
                    soundEffectManager.playPomodoroOneMinuteWarning()
                    soundEffectManager.sendOneMinuteWarningNotification()
                }
            } else {
                completeTimer()
            }
        case .countUp:
            currentTime += 1
        }
    }
    
    private func completeTimer() {
        timerState = .completed
        timer?.invalidate()
        timer = nil

        // 停止BGM音乐播放
        audioManager?.stopTimerPlayback()

        // 播放完成音效和发送通知
        switch currentMode {
        case .singlePomodoro:
            soundEffectManager.playPomodoroCompleted()
            soundEffectManager.sendPomodoroCompletedNotification()
        case .pureRest:
            soundEffectManager.playBreakCompleted()
        case .custom, .countUp:
            // 自定义模式和正计时模式不播放特定音效
            break
        }

        // 发送完成通知，包含会话信息
        let userInfo: [String: Any] = [
            "mode": currentMode,
            "startTime": sessionStartTime ?? Date(),
            "endTime": Date(),
            "task": sessionTask
        ]
        NotificationCenter.default.post(name: .timerCompleted, object: self, userInfo: userInfo)

        // 自动休息逻辑
        if autoStartBreak {
            if currentMode == .singlePomodoro {
                // 番茄完成后自动开始休息
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.startBreakAutomatically()
                }
            } else if currentMode == .pureRest {
                // 休息完成后自动回到番茄模式
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.returnToPomodoroMode()
                }
            }
        } else {
            // 即使没有开启自动休息，休息完成后也应该回到番茄模式
            if currentMode == .pureRest && isBreakFromPomodoro {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.returnToPomodoroMode()
                }
            }
        }
    }

    // 自动开始休息
    func startBreakAutomatically() {
        isBreakFromPomodoro = true
        currentMode = .pureRest
        setupTimer()
        timerState = .idle
        // 立即开始休息计时
        startTimer(with: "休息")
    }

    // 回到番茄模式
    func returnToPomodoroMode() {
        // 先停止当前计时器和清理状态
        timer?.invalidate()
        timer = nil

        // 设置状态和模式
        timerState = .idle
        isBreakFromPomodoro = false
        currentMode = .singlePomodoro

        // 最后设置时间显示
        setupTimer()

        // 停止音乐播放
        audioManager?.stopTimerPlayback()
    }

    // 手动开始休息（用于"开始休息"按钮）
    func startBreakManually() {
        isBreakFromPomodoro = true
        currentMode = .pureRest
        setupTimer()
        timerState = .idle
        startTimer(with: "休息")
    }
    
    // 设置用户自定义任务标题
    func setUserCustomTask(_ task: String) {
        userCustomTaskTitle = task
        hasUserSetCustomTask = true
    }

    // 获取当前应该显示的任务标题
    func getCurrentDisplayTask(fallback: String) -> String {
        // 如果计时器正在运行或暂停，且用户设置了自定义任务，返回自定义任务
        if hasUserSetCustomTask {
            return userCustomTaskTitle
        }
        // 否则返回fallback任务
        return fallback
    }

    // 格式化时间显示
    func formattedTime() -> String {
        let time: TimeInterval
        switch currentMode {
        case .singlePomodoro, .pureRest, .custom:
            time = timeRemaining
        case .countUp:
            time = currentTime
        }

        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // 计算进度（用于圆形进度条）
    func progress() -> Double {
        switch currentMode {
        case .singlePomodoro, .pureRest, .custom:
            guard totalTime > 0 else { return 0 }
            return (totalTime - timeRemaining) / totalTime
        case .countUp:
            return 0 // 正计时模式不显示进度
        }
    }

    // 获取时间状态信息（用于hover显示）
    func getTimeStatusInfo() -> String {
        guard currentMode == .singlePomodoro else { return "" }

        switch timerState {
        case .idle:
            // 未开始时显示预计的开始-结束时间
            let now = Date()
            let expectedEndTime = now.addingTimeInterval(totalTime)
            return formatTimeRange(start: now, end: expectedEndTime)
        case .paused:
            return "" // 暂停状态不在hover中显示，直接在UI中显示
        case .running:
            guard let startTime = sessionStartTime else { return "" }
            let expectedEndTime = startTime.addingTimeInterval(totalTime)
            return formatTimeRange(start: startTime, end: expectedEndTime)
        case .completed:
            return ""
        }
    }

    // 格式化时间范围显示
    private func formatTimeRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let startString = formatter.string(from: start)
        let endString = formatter.string(from: end)
        return "\(startString) - \(endString)"
    }

    // 动态调整当前计时时间（仅在番茄模式运行时可用）
    func adjustCurrentTime(by minutes: Int) {
        guard currentMode == .singlePomodoro && timerState == .running else { return }

        let adjustment = TimeInterval(minutes * 60)
        let newTimeRemaining = timeRemaining + adjustment

        // 防止时间调整到负值
        guard newTimeRemaining > 0 else { return }

        timeRemaining = newTimeRemaining
        totalTime += adjustment
    }

    // 检查是否可以进行时间调整
    func canAdjustTime() -> Bool {
        return currentMode == .singlePomodoro && timerState == .running
    }

    // 提前结束当前番茄钟（将已计时的时间作为完整的番茄时间）
    func completeEarly() {
        guard currentMode == .singlePomodoro && timerState == .running else { return }

        // 计算已经过去的时间
        let elapsedTime = totalTime - timeRemaining

        // 更新总时间为已计时的时间
        totalTime = elapsedTime
        timeRemaining = 0

        // 完成计时器
        completeTimer()
    }

    // 跳过休息，直接回到番茄模式的未开始状态
    func skipBreak() {
        returnToPomodoroMode()
    }

    // MARK: - 设置变更通知

    private func notifySettingsChanged() {
        NotificationCenter.default.post(name: TimerModel.settingsChangedNotification, object: self)
    }

    // MARK: - 设置持久化

    private func saveSettings() {
        userDefaults.set(pomodoroTime, forKey: pomodoroTimeKey)
        userDefaults.set(shortBreakTime, forKey: shortBreakTimeKey)
        userDefaults.set(longBreakTime, forKey: longBreakTimeKey)
        userDefaults.set(autoStartBreak, forKey: autoStartBreakKey)
    }

    private func loadSettings() {
        // 加载时间设置，如果没有保存的值则使用默认值
        let savedPomodoroTime = userDefaults.double(forKey: pomodoroTimeKey)
        if savedPomodoroTime > 0 {
            pomodoroTime = savedPomodoroTime
        }

        let savedShortBreakTime = userDefaults.double(forKey: shortBreakTimeKey)
        if savedShortBreakTime > 0 {
            shortBreakTime = savedShortBreakTime
        }

        let savedLongBreakTime = userDefaults.double(forKey: longBreakTimeKey)
        if savedLongBreakTime > 0 {
            longBreakTime = savedLongBreakTime
        }

        // 加载自动休息设置
        if userDefaults.object(forKey: autoStartBreakKey) != nil {
            autoStartBreak = userDefaults.bool(forKey: autoStartBreakKey)
        }
    }
}

extension Notification.Name {
    static let timerCompleted = Notification.Name("timerCompleted")
}