//
//  TimerView.swift
//  PomodoroTimer
//
//  Created by Developer on 2024.
//

import SwiftUI

struct TimerView: View {
    @EnvironmentObject var timerModel: TimerModel
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var eventManager: EventManager
    @EnvironmentObject var smartReminderManager: SmartReminderManager
    @State private var showingModeSelector = false
    @State private var showingTimeEditor = false
    @State private var showingTaskSelector = false
    @Binding var selectedTask: String
    @State private var editingMinutes = 30
    @State private var isHoveringTimeCircle = false
    @State private var showingCompletionDialog = false
    @State private var customMinutes: String = ""
    @State private var windowWidth: CGFloat = 800 // 跟踪窗口宽度

    // MARK: - 智能提醒状态显示
    private var smartReminderStatusView: some View {
        Group {
            // 当窗口宽度小于 900px 时隐藏智能提醒状态显示
            if windowWidth >= 700 && smartReminderManager.isEnabled && smartReminderManager.reminderState == .counting {
                HStack(spacing: 6) {
                    Image(systemName: "bell")
                        .font(.caption)
                        .foregroundColor(.orange)

                    Text("\(smartReminderManager.formatRemainingTime())后提醒")
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
            } else {
                // 空白占位，保持布局一致
                Spacer()
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 30) {
            Spacer()

            // 任务标题
            Button(action: {
                showingTaskSelector = true
            }) {
                HStack {
                    Text(timerModel.getCurrentDisplayTask(fallback: selectedTask))
                        .font(.title3)
                        .foregroundColor(.primary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.bottom, 0)
            .popover(isPresented: $showingTaskSelector, arrowEdge: .bottom) {
                TaskSelectorPopoverView(selectedTask: $selectedTask, isPresented: $showingTaskSelector)
            }

                // 主计时器圆环
                ZStack {
                    // 背景圆环
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 6)
                        .frame(width: 400, height: 400)

                    // 进度圆环
                    if timerModel.currentMode != .countUp {
                        Circle()
                            .trim(from: 0, to: timerModel.progress())
                            .stroke(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .frame(width: 400, height: 400)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 1), value: timerModel.progress())
                    }

                    // 中心时间显示区域
                    ZStack {
                        // 时间显示按钮（绝对居中，不受其他元素影响）
                        Button(action: {
                            // 正计时模式下不允许编辑时间
                            if timerModel.timerState == .idle && timerModel.currentMode != .countUp {
                                // 根据当前模式获取对应的分钟数
                                switch timerModel.currentMode {
                                case .singlePomodoro:
                                    editingMinutes = Int(timerModel.pomodoroTime / 60)
                                case .pureRest:
                                    editingMinutes = Int(timerModel.shortBreakTime / 60)
                                case .custom(let minutes):
                                    editingMinutes = minutes
                                case .countUp:
                                    break // 不应该到这里
                                }
                                showingTimeEditor = true
                            }
                        }) {
                            Text(timerModel.formattedTime())
                                .font(.system(size: 58, weight: .light, design: .monospaced))
                                .foregroundColor(Color.primary) // 强制使用系统标签颜色（黑色）
                                .multilineTextAlignment(.center)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .popover(isPresented: $showingTimeEditor, arrowEdge: .bottom) {
                            TimeEditorPopoverView(minutes: $editingMinutes) { newMinutes in
                                timerModel.setCustomTime(minutes: newMinutes)
                                showingTimeEditor = false
                            }
                        }

                        // 其他信息显示区域（使用绝对定位，不影响时间居中）
                        VStack(spacing: 4) {
                            // 正计时模式标识
                            if timerModel.currentMode == .countUp {
                                Text("正计时模式")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }

                            // 状态信息显示
                            VStack {
                                // 暂停状态显示
                                if timerModel.timerState == .paused {
                                    Text("已暂停")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.top, 8)
                                }
                                // 时间状态信息（仅在番茄模式hover时显示）
                                else if isHoveringTimeCircle && timerModel.currentMode == .singlePomodoro && timerModel.timerState != .paused {
                                    let timeInfo = timerModel.getTimeStatusInfo()
                                    if !timeInfo.isEmpty {
                                        Text(timeInfo)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .transition(.opacity)
                                            .multilineTextAlignment(.center)
                                            .padding(.top, 8)
                                    }
                                }
                            }
                        }
                        .position(x: 150, y: 200) // 绝对定位在时间下方，不影响时间居中

                        // 左侧减号按钮（在圆圈内部，距离时间合适的位置）
                        if isHoveringTimeCircle && timerModel.canAdjustTime() {
                            Button(action: {
                                timerModel.adjustCurrentTime(by: -5)
                            }) {
                                Image(systemName: "minus")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(TimeAdjustButtonStyle())
                            .transition(.opacity)
                            .position(x: 30, y: 150) // 绝对位置：左侧，垂直居中
                        }

                        // 右侧加号按钮（在圆圈内部，距离时间合适的位置）
                        if isHoveringTimeCircle && timerModel.canAdjustTime() {
                            Button(action: {
                                timerModel.adjustCurrentTime(by: 5)
                            }) {
                                Image(systemName: "plus")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(TimeAdjustButtonStyle())
                            .transition(.opacity)
                            .position(x: 270, y: 150) // 绝对位置：右侧，垂直居中
                        }
                    }
                    .frame(width: 300, height: 300) // 限制在圆圈内部
                }
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isHoveringTimeCircle = hovering
                    }
                }
                
                // Spacer()

                // 控制按钮
                VStack(spacing: 12) {
                    // 番茄模式运行时的三按钮布局
                    if timerModel.currentMode == .singlePomodoro && timerModel.timerState == .running {
                        HStack(spacing: 12) {
                            // 暂停按钮 - 黄色背景
                            Button(action: {
                                timerModel.pauseTimer()
                            }) {
                                Text("暂停")
                                    .frame(width: 80)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .tint(.orange)

                            // 放弃按钮 - 橙色背景
                            Button(action: {
                                timerModel.resetTimer()
                            }) {
                                Text("放弃")
                                    .frame(width: 80)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .tint(.red)

                            // 提前结束按钮 - 灰色背景
                            Button(action: {
                                timerModel.completeEarly()
                            }) {
                                Text("提前结束")
                                    .frame(width: 80)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .tint(.gray)
                        }
                    }
                    // 番茄模式暂停时只显示继续按钮
                    else if timerModel.currentMode == .singlePomodoro && timerModel.timerState == .paused {
                        Button(action: {
                            timerModel.startTimer(with: selectedTask)
                            smartReminderManager.onUserStartedTimer()
                        }) {
                            Text("继续")
                                .frame(width: 180)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(.blue)
                    }
                    // 番茄完成后只显示开始休息和跳过休息按钮
                    else if timerModel.timerState == .completed && timerModel.currentMode == .singlePomodoro {
                        HStack(spacing: 12) {
                            // 开始休息按钮
                            Button(action: {
                                timerModel.startBreakManually()
                            }) {
                                Text("开始休息")
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .tint(.green)

                            // 跳过休息按钮
                            Button(action: {
                                timerModel.skipBreak()
                            }) {
                                Text("跳过休息")
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .tint(.gray)
                        }
                    }
                    // 其他情况的按钮布局
                    else {
                        // 正计时模式运行时的双按钮布局
                        if timerModel.currentMode == .countUp && timerModel.timerState == .running {
                            HStack(spacing: 12) {
                                // 暂停按钮
                                Button(action: {
                                    timerModel.pauseTimer()
                                }) {
                                    Text("暂停")
                                        .frame(width: 80)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                                .tint(.yellow)

                                // 结束按钮
                                Button(action: {
                                    timerModel.stopTimer()
                                }) {
                                    Text("结束")
                                        .frame(width: 80)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                                .tint(.secondary)
                            }
                        }
                        // 其他情况的单按钮布局
                        else {
                            Button(action: {
                                switch timerModel.timerState {
                                case .idle:
                                    timerModel.startTimer(with: selectedTask)
                                    smartReminderManager.onUserStartedTimer()
                                case .paused:
                                    timerModel.startTimer(with: selectedTask)
                                    smartReminderManager.onUserStartedTimer()
                                    // 恢复计时器时也恢复音乐播放
                                    audioManager.resumeTimerPlayback()
                                case .running:
                                    // 休息模式下运行时直接结束，其他模式暂停
                                    if timerModel.currentMode == .pureRest {
                                        timerModel.stopTimer()
                                    } else {
                                        timerModel.pauseTimer()
                                    }
                                case .completed:
                                    timerModel.resetTimer()
                                }
                            }) {
                                Text(buttonText)
                                    .frame(width: 180)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .tint(buttonColor)
                        }
                    }
                }            .padding(.top, 20)


                Spacer()
            }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.systemBackground)
        .onAppear {
            // 初始化窗口宽度
            windowWidth = geometry.size.width
        }
        .onChange(of: geometry.size.width) { newWidth in
            // 响应窗口宽度变化
            windowWidth = newWidth
        }
        // 添加空格键支持
        .background(
            Button("Toggle Timer") {
                handleSpaceKeyPress()
            }
            .keyboardShortcut(.space, modifiers: [])
            .hidden()
        )
        .onAppear {
            // 设置TimerModel对AudioManager的引用
            timerModel.audioManager = audioManager

            // 设置智能提醒管理器的依赖
            smartReminderManager.setTimerModel(timerModel)

            // 只有在计时器空闲状态且用户未设置自定义任务时，才从最近事件设置默认任务
            if timerModel.timerState == .idle && !timerModel.hasUserSetCustomTask {
                setDefaultTaskFromRecentEvent()
            }
        }
        .onChange(of: timerModel.timerState) { newState in
            // 监听番茄钟完成状态
            // 只有在未开启自动休息时才显示完成弹窗
            if newState == .completed && timerModel.currentMode == .singlePomodoro && !timerModel.autoStartBreak {
                showingCompletionDialog = true
            }

        }
        .onChange(of: selectedTask) { newTask in
            // 用户修改任务时，设置自定义任务到TimerModel
            // TimerModel会自动处理运行时的任务切换逻辑
            timerModel.setUserCustomTask(newTask)
        }
        .toolbar {
            // 左侧：智能提醒状态显示
            ToolbarItemGroup(placement: .navigation) {
                smartReminderStatusView
            }

            // 中间：模式选择 Picker
            ToolbarItemGroup(placement: .principal) {
                Picker("模式", selection: Binding(
                    get: { timerModel.currentMode },
                    set: { timerModel.changeMode($0) }
                )) {
                    ForEach(TimerMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 400)
                .disabled(timerModel.timerState == .running) // 计时器运行时禁用模式切换
            }

            // 右侧：音频控制菜单
            ToolbarItemGroup() {
                Spacer()
                Menu {
                    // 静音选项
                    Button(action: {
                        audioManager.clearSelection()
                    }) {
                        HStack {
                            Image(systemName: "speaker.slash")
                            Text("静音")
                            if audioManager.selectedTrack == nil {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }

                    if !audioManager.tracks.isEmpty {
                        Divider()

                        // 音乐列表
                        ForEach(audioManager.tracks) { track in
                            Button(action: {
                                // 根据计时器状态决定行为
                                if timerModel.timerState == .running &&
                                   (timerModel.currentMode == .singlePomodoro || timerModel.currentMode == .countUp) {
                                    // 计时器运行中：立即切换音乐并开始播放
                                    audioManager.selectedTrack = track
                                    audioManager.startTimerPlayback()
                                } else {
                                    // 计时器未运行：试听功能
                                    audioManager.previewTrack(track)
                                }
                            }) {
                                HStack {
                                    Image(systemName: getTrackIcon(for: track))
                                    Text(track.name)
                                        .lineLimit(1)
                                    if audioManager.selectedTrack?.id == track.id {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } else {
                        Divider()
                        Button(action: {
                            // 这里可以打开设置页面或显示提示
                        }) {
                            HStack {
                                Image(systemName: "gear")
                                Text("请在设置中配置音乐文件夹")
                            }
                        }
                        .disabled(true)
                    }
                } label: {
                    Image(systemName: getAudioButtonIcon())
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        // 番茄钟完成选择弹窗
        .sheet(isPresented: $showingCompletionDialog) {
            PomodoroCompletionDialog(
                isPresented: $showingCompletionDialog,
                timerModel: timerModel,
                smartReminderManager: smartReminderManager,
                selectedTask: selectedTask
            )
        }
        } // GeometryReader 结束
    }

    private var buttonText: String {
        switch timerModel.timerState {
        case .idle:
            return "开始"
        case .running:
            // 休息模式下显示"结束"，其他模式显示"暂停"
            return timerModel.currentMode == .pureRest ? "结束" : "暂停"
        case .paused:
            return "继续"
        case .completed:
            return "开始"
        }
    }

    // 获取音频按钮图标
    private func getAudioButtonIcon() -> String {
        if audioManager.isPlaying {
            return "speaker.wave.2"
        } else if audioManager.selectedTrack != nil {
            return "speaker"
        } else {
            return "speaker.slash"
        }
    }

    // 获取音乐项图标
    private func getTrackIcon(for track: AudioTrack) -> String {
        if audioManager.currentTrack?.id == track.id && audioManager.isPlaying {
            return "speaker.wave.2"
        } else {
            return "music.note"
        }
    }

    private var buttonColor: Color {
        switch timerModel.timerState {
        case .idle, .completed:
            return .accentColor // 开始按钮使用系统强调色
        case .running:
            // 休息模式下显示"结束"，其他模式显示"暂停"
            return timerModel.currentMode == .pureRest ? .secondary : .yellow
        case .paused:
            return .green // 继续按钮是绿色
        }
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        return "\(minutes)"
    }

    /// 从最近的事件中设置默认任务
    private func setDefaultTaskFromRecentEvent() {
        // 获取最近的已完成事件
        let recentEvents = eventManager.events
            .filter { $0.isCompleted }
            .sorted { $0.startTime > $1.startTime }

        // 如果有最近的事件，使用其标题作为默认任务
        if let mostRecentEvent = recentEvents.first {
            selectedTask = mostRecentEvent.title
        }
    }
    
    /// 处理空格键按下事件
    private func handleSpaceKeyPress() {
        switch timerModel.timerState {
        case .idle:
            // 空闲状态：开始计时器
            timerModel.startTimer(with: selectedTask)
            smartReminderManager.onUserStartedTimer()

        case .running:
            // 运行状态：纯休息模式直接结束，其他模式暂停
            if timerModel.currentMode == .pureRest {
                timerModel.stopTimer()
            } else {
                timerModel.pauseTimer()
            }

        case .paused:
            // 暂停状态：继续计时器
            timerModel.startTimer(with: selectedTask)
            smartReminderManager.onUserStartedTimer()
            // 恢复计时器时也恢复音乐播放
            audioManager.resumeTimerPlayback()

        case .completed:
            // 完成状态：重置计时器（为下一次做准备）
            timerModel.resetTimer()
        }
    }
}

// MARK: - 时间编辑器 Popover
struct TimeEditorPopoverView: View {
    @Binding var minutes: Int
    let onConfirm: (Int) -> Void
    @State private var tempMinutes: Int
    @State private var inputText: String
    @FocusState private var isInputFocused: Bool

    init(minutes: Binding<Int>, onConfirm: @escaping (Int) -> Void) {
        self._minutes = minutes
        self.onConfirm = onConfirm
        self._tempMinutes = State(initialValue: minutes.wrappedValue)
        self._inputText = State(initialValue: String(minutes.wrappedValue))
    }

    var body: some View {
        VStack(spacing: 16) {
            // 当前时间显示
            Text("\(tempMinutes) 分钟")
                .font(.title2)
                .fontWeight(.medium)

            // 数字输入框和调整按钮
            HStack(spacing: 8) {
                // 数字输入框
                TextField("分钟", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .multilineTextAlignment(.center)
                    .focused($isInputFocused)
                    .onSubmit {
                        validateAndUpdateMinutes()
                    }
                    .onChange(of: inputText) { newValue in
                        // 实时验证输入
                        if let value = Int(newValue), value >= 1, value <= 99 {
                            tempMinutes = value
                        }
                    }

                // 减少按钮
                Button(action: {
                    adjustMinutes(by: -1)
                }) {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .frame(width: 28, height: 28)

                // 增加按钮
                Button(action: {
                    adjustMinutes(by: 1)
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .frame(width: 28, height: 28)
            }

            // 按钮区域
            HStack(spacing: 12) {
                Button("取消") {
                    // Popover 会自动关闭，不需要调用 dismiss
                }
                .controlSize(.small)

                Button("确定") {
                    validateAndUpdateMinutes()
                    minutes = tempMinutes
                    onConfirm(tempMinutes)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(16)
        .frame(width: 220)
        .onAppear {
            // 确保输入框显示正确的初始值
            inputText = String(tempMinutes)
        }
    }

    // 验证并更新分钟数
    private func validateAndUpdateMinutes() {
        if let value = Int(inputText) {
            let clampedValue = max(1, min(99, value))
            tempMinutes = clampedValue
            inputText = String(clampedValue)
        } else {
            // 如果输入无效，恢复到当前值
            inputText = String(tempMinutes)
        }
    }

    // 调整分钟数
    private func adjustMinutes(by delta: Int) {
        let newValue = max(1, min(99, tempMinutes + delta))
        tempMinutes = newValue
        inputText = String(newValue)
    }
}

// MARK: - 原时间编辑器（保留作为备用）
struct TimeEditorView: View {
    @Binding var minutes: Int
    let onConfirm: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var tempMinutes: Double

    init(minutes: Binding<Int>, onConfirm: @escaping (Int) -> Void) {
        self._minutes = minutes
        self.onConfirm = onConfirm
        self._tempMinutes = State(initialValue: Double(minutes.wrappedValue))
    }

    var body: some View {
        VStack(spacing: 20) {
            // 标题
            Text("设置时间")
                .font(.headline)
                .padding(.top, 20)

            // 时间设置区域
            VStack(spacing: 16) {
                // 当前时间显示
                Text("\(Int(tempMinutes)) 分钟")
                    .font(.title)
                    .fontWeight(.medium)

                // 滑块控制
                VStack(spacing: 8) {
                    Slider(value: $tempMinutes, in: 1...99, step: 1)
                        .frame(width: 200)

                    // 刻度标签
                    HStack {
                        Text("1")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("25")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("50")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("99")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 200)
                }

                // 步进器控制
                Stepper(value: $tempMinutes, in: 1...99, step: 1) {
                    Text("精确调整")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(width: 200)
            }
            .padding(.vertical, 16)

            // 按钮区域
            HStack(spacing: 12) {
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("确定") {
                    let newMinutes = Int(tempMinutes)
                    minutes = newMinutes
                    onConfirm(newMinutes)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(.bottom, 20)
        }
        .frame(width: 280, height: 280)
    }
}

// MARK: - 任务选择器 Popover
struct TaskSelectorPopoverView: View {
    @Binding var selectedTask: String
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @EnvironmentObject var eventManager: EventManager

    // 预设任务类型
    private let presetTasks = ["专注", "学习", "工作", "阅读", "写作", "编程", "设计", "思考", "休息", "运动"]

    // 从事件历史中获取最近常用任务
    var recentTasksFromHistory: [String] {
        let allTitles = eventManager.events.map { $0.title }
        let uniqueTitles = Array(Set(allTitles))

        // 按使用频率排序，取前10个
        let taskFrequency = Dictionary(grouping: allTitles, by: { $0 })
            .mapValues { $0.count }

        return uniqueTitles
            .sorted { taskFrequency[$0] ?? 0 > taskFrequency[$1] ?? 0 }
            .prefix(10)
            .map { $0 }
    }

    // 过滤最近常用任务
    var filteredRecentTasks: [String] {
        let recentTasks = recentTasksFromHistory
        if searchText.isEmpty {
            return recentTasks
        } else {
            return recentTasks.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    // 过滤预设任务
    var filteredPresetTasks: [String] {
        if searchText.isEmpty {
            return presetTasks
        } else {
            return presetTasks.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    // 检查是否需要显示"创建新任务"选项
    var shouldShowCreateOption: Bool {
        !searchText.isEmpty &&
        !filteredRecentTasks.contains(searchText) &&
        !filteredPresetTasks.contains(searchText) &&
        !recentTasksFromHistory.contains(searchText)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 搜索框
            TextField("搜索或输入新任务", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            // 任务列表
            List {
                // 最近常用分组
                if !filteredRecentTasks.isEmpty {
                    Section("最近常用") {
                        ForEach(filteredRecentTasks, id: \.self) { task in
                            TaskRowView(task: task, isSelected: task == selectedTask) {
                                selectedTask = task
                                isPresented = false
                            }
                        }
                    }
                }

                // 预设任务分组
                if !filteredPresetTasks.isEmpty {
                    Section("预设任务") {
                        ForEach(filteredPresetTasks, id: \.self) { task in
                            TaskRowView(task: task, isSelected: task == selectedTask) {
                                selectedTask = task
                                isPresented = false
                            }
                        }
                    }
                }

                // 创建新任务选项
                if shouldShowCreateOption {
                    Section("创建新任务") {
                        TaskRowView(task: searchText, isSelected: false, isNewTask: true) {
                            selectedTask = searchText
                            isPresented = false
                        }
                    }
                }
            }
            .listStyle(SidebarListStyle())
        }
        .frame(width: 280, height: 320)
    }
}

// MARK: - 任务行视图
struct TaskRowView: View {
    let task: String
    let isSelected: Bool
    let isNewTask: Bool
    let onTap: () -> Void

    init(task: String, isSelected: Bool, isNewTask: Bool = false, onTap: @escaping () -> Void) {
        self.task = task
        self.isSelected = isSelected
        self.isNewTask = isNewTask
        self.onTap = onTap
    }

    var body: some View {
        HStack(spacing: 12) {
            // 选择指示器
            ZStack {
                Circle()
                    .foregroundColor(isSelected ? Color.accentColor : Color.clear)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.5), lineWidth: 1)
                    )
                    .frame(width: 16, height: 16)

                if isSelected {
                    Circle()
                        .foregroundColor(Color.white)
                        .frame(width: 6, height: 6)
                }
            }

            // 任务名称
            HStack(spacing: 8) {
                if isNewTask {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 16))
                }

                Text(isNewTask ? "创建 \"\(task)\"" : task)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - 时间调整按钮样式
struct TimeAdjustButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 32, height: 32)
            .background(
                Circle()
                    .fill(Color.secondary.opacity(configuration.isPressed ? 0.3 : 0.1))
                    .overlay(
                        Circle()
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - 统一按钮样式
struct UnifiedButtonStyle: ButtonStyle {
    let color: Color
    let isProminent: Bool

    init(color: Color = .accentColor, isProminent: Bool = false) {
        self.color = color
        self.isProminent = isProminent
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13)) // 使用系统默认文字大小
            .fontWeight(.medium)
            .padding(.vertical, 6) // 上下padding 12pt
            .padding(.horizontal, 24) // 左右padding 24pt
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
            )
            .foregroundColor(.white) // 文字始终为白色
            .opacity(configuration.isPressed ? 0.7 : 1.0) // 系统原生的按下效果
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - 原生按钮样式（类似 UIButton 效果）
struct NativeButtonStyle: ButtonStyle {
    let color: Color
    let isProminent: Bool

    init(color: Color = .accentColor, isProminent: Bool = false) {
        self.color = color
        self.isProminent = isProminent
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13))
            .fontWeight(.medium)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: configuration.isPressed ? color.opacity(0.8) : color.opacity(0.9), location: 0),
                                .init(color: configuration.isPressed ? color.opacity(0.6) : color.opacity(0.7), location: 1)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: Color.black.opacity(0.2), location: 0),
                                        .init(color: Color.black.opacity(0.1), location: 1)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.5
                            )
                    )
                    .shadow(
                        color: Color.black.opacity(configuration.isPressed ? 0.1 : 0.2),
                        radius: configuration.isPressed ? 1 : 2,
                        x: 0,
                        y: configuration.isPressed ? 0.5 : 1
                    )
            )
            .foregroundColor(.white)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - 番茄钟完成选择弹窗
struct PomodoroCompletionDialog: View {
    @Binding var isPresented: Bool
    @ObservedObject var timerModel: TimerModel
    @ObservedObject var smartReminderManager: SmartReminderManager
    let selectedTask: String

    @State private var customMinutes: String = ""
    @FocusState private var isCustomInputFocused: Bool

    var body: some View {
        VStack(spacing: 24) {
            // 标题
            VStack(spacing: 8) {
                Text("🍅 番茄钟已完成！")
                    .font(.title)
                    .fontWeight(.semibold)

                Text("选择下一步行动")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }

            // 选项区域
            VStack(spacing: 16) {
                // 继续专注选项
                VStack(spacing: 12) {
                    Text("继续专注")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 12) {
                        // 使用上次时长
                        Button(action: {
                            startPomodoro(minutes: Int(timerModel.getCurrentPomodoroTime() / 60))
                        }) {
                            VStack(spacing: 4) {
                                Text("上次时长")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(Int(timerModel.getCurrentPomodoroTime() / 60))分钟")
                                    .font(.title3)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)

                        // 快速选择时长
                        ForEach([10, 15, 30], id: \.self) { minutes in
                            Button(action: {
                                startPomodoro(minutes: minutes)
                            }) {
                                Text("\(minutes)分钟")
                                    .font(.title3)
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    // 自定义时长
                    HStack(spacing: 8) {
                        Text("自定义:")
                            .font(.subheadline)

                        TextField("分钟", text: $customMinutes)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                            .focused($isCustomInputFocused)
                            .onSubmit {
                                startCustomPomodoro()
                            }

                        Button("开始") {
                            startCustomPomodoro()
                        }
                        .buttonStyle(.bordered)
                        .disabled(customMinutes.isEmpty || Int(customMinutes) == nil)
                    }
                }

                Divider()

                // 开始休息选项
                VStack(spacing: 12) {
                    Text("开始休息")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button(action: {
                        startBreak()
                    }) {
                        HStack {
                            Image(systemName: "cup.and.saucer")
                            Text("休息 \(Int(timerModel.getCurrentBreakTime() / 60)) 分钟")
                                .font(.title3)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
            }

            // 底部按钮
            HStack(spacing: 12) {
                Button("稍后决定") {
                    isPresented = false
                }
                .buttonStyle(.bordered)

                Spacer()
            }
        }
        .padding(24)
        .frame(width: 480)
        .background(Color.systemBackground)
        .cornerRadius(16)
        .shadow(radius: 20)
    }

    private func startPomodoro(minutes: Int) {
        // 先重置计时器状态，这样setCustomTime才能正常工作
        timerModel.resetTimer()
        timerModel.setCustomTime(minutes: minutes)
        timerModel.currentMode = .singlePomodoro
        timerModel.startTimer(with: selectedTask)
        smartReminderManager.onUserStartedTimer()
        isPresented = false
    }

    private func startCustomPomodoro() {
        guard let minutes = Int(customMinutes), minutes > 0, minutes <= 99 else { return }
        startPomodoro(minutes: minutes)
    }

    private func startBreak() {
        timerModel.isBreakFromPomodoro = true
        timerModel.currentMode = .pureRest
        timerModel.resetTimer()
        timerModel.startTimer()
        smartReminderManager.onUserStartedTimer()
        isPresented = false
    }
}

#Preview {
    TimerView(selectedTask: .constant("预览任务"))
        .environmentObject(TimerModel())
        .environmentObject(AudioManager())
        .environmentObject(EventManager())
        .environmentObject(SmartReminderManager())
}
