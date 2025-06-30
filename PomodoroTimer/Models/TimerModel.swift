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
    
    // 设置
    @Published var pomodoroTime: TimeInterval = 25 * 60 // 25分钟
    @Published var shortBreakTime: TimeInterval = 5 * 60 // 5分钟
    @Published var longBreakTime: TimeInterval = 15 * 60 // 15分钟
    
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
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
    
    func startTimer() {
        guard timerState != .running else { return }
        
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
        setupTimer()
    }
    
    func changeMode(_ mode: TimerMode) {
        resetTimer()
        currentMode = mode
        setupTimer()
    }

    func setCustomTime(minutes: Int) {
        guard timerState == .idle else { return }
        currentMode = .custom(minutes: minutes)
        setupTimer()
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
        
        // 发送完成通知
        NotificationCenter.default.post(name: .timerCompleted, object: nil)
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
}

extension Notification.Name {
    static let timerCompleted = Notification.Name("timerCompleted")
}