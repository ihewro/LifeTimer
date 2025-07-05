//
//  TimerModel.swift
//  PomodoroTimer
//
//  Created by Developer on 2024.
//

import Foundation
import Combine

enum TimerMode: Equatable, Hashable {
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

    // 设置
    @Published var pomodoroTime: TimeInterval = 25 * 60 { // 25分钟
        didSet {
            if pomodoroTime != oldValue {
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
                notifySettingsChanged()
            }
        }
    }

    // 自动休息设置
    @Published var autoStartBreak: Bool = false {
        didSet {
            if autoStartBreak != oldValue {
                notifySettingsChanged()
            }
        }
    }

    // 跟踪是否是从番茄模式进入的休息
    private var isBreakFromPomodoro: Bool = false

    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // 设置变更通知
    static let settingsChangedNotification = Notification.Name("TimerSettingsChanged")
    
    init() {
        setupTimer()
    }
    
    private func setupTimer() {
        switch currentMode {
        case .singlePomodoro:
            timeRemaining = pomodoroTime
            totalTime = pomodoroTime
        case .pureRest:
            timeRemaining = shortBreakTime
            totalTime = shortBreakTime
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
        }

        timerState = .running

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
    }
    
    func resetTimer() {
        timerState = .idle
        timer?.invalidate()
        timer = nil
        sessionStartTime = nil
        setupTimer()
    }
    
    func changeMode(_ mode: TimerMode) {
        resetTimer()
        currentMode = mode
        isBreakFromPomodoro = false // 重置标志
        setupTimer()
    }

    func setCustomTime(minutes: Int) {
        guard timerState == .idle else { return }

        // 如果当前是番茄模式，只修改番茄时间设置，不切换到自定义模式
        if currentMode == .singlePomodoro {
            pomodoroTime = TimeInterval(minutes * 60)
            setupTimer()
        } else if currentMode == .pureRest {
            // 如果当前是休息模式，只修改休息时间设置
            shortBreakTime = TimeInterval(minutes * 60)
            setupTimer()
        } else {
            // 其他模式才切换到自定义模式
            currentMode = .custom(minutes: minutes)
            setupTimer()
        }
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
        isBreakFromPomodoro = false
        currentMode = .singlePomodoro
        setupTimer()
        timerState = .idle
    }

    // 手动开始休息（用于"开始休息"按钮）
    func startBreakManually() {
        isBreakFromPomodoro = true
        currentMode = .pureRest
        setupTimer()
        timerState = .idle
        startTimer(with: "休息")
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
}

extension Notification.Name {
    static let timerCompleted = Notification.Name("timerCompleted")
}