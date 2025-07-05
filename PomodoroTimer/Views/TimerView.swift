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
    @State private var showingModeSelector = false
    @State private var showingTimeEditor = false
    @State private var showingTaskSelector = false
    @State private var selectedTask = "专注"
    @State private var editingMinutes = 30
    @State private var isHoveringTimeCircle = false
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // 任务标题
            Button(action: {
                showingTaskSelector = true
            }) {
                HStack {
                    Text(selectedTask)
                        .font(.title3)
                        .foregroundColor(.primary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.bottom, 20)
            .popover(isPresented: $showingTaskSelector, arrowEdge: .bottom) {
                TaskSelectorPopoverView(selectedTask: $selectedTask, isPresented: $showingTaskSelector)
            }

                // 主计时器圆环
                ZStack {
                    // 背景圆环
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 8)
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
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
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
                                showingTimeEditor = true
                            }
                        }) {
                            Text(timerModel.formattedTime())
                                .font(.system(size: 48, weight: .light, design: .monospaced))
                                .foregroundColor(Color(NSColor.labelColor)) // 强制使用系统标签颜色（黑色）
                                .multilineTextAlignment(.center)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(timerModel.timerState != .idle || timerModel.currentMode == .countUp)

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
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.top, 8)
                                }
                                // 时间状态信息（仅在番茄模式hover时显示）
                                else if isHoveringTimeCircle && timerModel.currentMode == .singlePomodoro && timerModel.timerState != .paused {
                                    let timeInfo = timerModel.getTimeStatusInfo()
                                    if !timeInfo.isEmpty {
                                        Text(timeInfo)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.secondary)
                                            .transition(.opacity)
                                            .multilineTextAlignment(.center)
                                            .padding(.top, 8)
                                    }
                                }
                            }
                        }
                        .position(x: 150, y: 220) // 绝对定位在时间下方，不影响时间居中

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
                            .position(x: 250, y: 150) // 绝对位置：右侧，垂直居中
                        }
                    }
                    .frame(width: 300, height: 300) // 限制在圆圈内部
                }
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isHoveringTimeCircle = hovering
                    }
                }
                
                Spacer()

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
                        // 主控制按钮
                        Button(action: {
                            switch timerModel.timerState {
                            case .idle, .paused:
                                timerModel.startTimer(with: selectedTask)
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

                        // 结束按钮（在正计时运行时显示）
                        if timerModel.currentMode == .countUp && timerModel.timerState == .running {
                            Button(action: {
                                timerModel.stopTimer()
                            }) {
                                Text("结束")
                                    .frame(width: 180)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .tint(.gray)
                        }
                    }
                }

                Spacer()
            }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
        .toolbar {
            // 左侧：模式选择下拉菜单
            ToolbarItem(placement: .navigation) {
                Menu {
                    ForEach(TimerMode.allCases, id: \.self) { mode in
                        Button(action: {
                            timerModel.changeMode(mode)
                        }) {
                            HStack {
                                Text(mode.rawValue)
                                if timerModel.currentMode == mode {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(timerModel.currentMode.rawValue)
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }

            // 中间：占位符确保 toolbar 铺满宽度
            ToolbarItem(placement: .principal) {
                Spacer()
            }

            // 右侧：音频控制按钮
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    if audioManager.isPlaying {
                        audioManager.pausePlayback()
                    } else if audioManager.currentTrack != nil {
                        audioManager.resumePlayback()
                    }
                }) {
                    Image(systemName: audioManager.isPlaying ? "speaker.wave.2" : "speaker.slash")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .sheet(isPresented: $showingTimeEditor) {
            TimeEditorView(minutes: $editingMinutes) { newMinutes in
                timerModel.setCustomTime(minutes: newMinutes)
            }
        }
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

    private var buttonColor: Color {
        switch timerModel.timerState {
        case .idle, .completed:
            return .green // 开始按钮是绿色
        case .running:
            // 休息模式下显示"结束"，其他模式显示"暂停"
            return timerModel.currentMode == .pureRest ? .secondary : .yellow
        case .paused:
            return .blue // 继续按钮是蓝色
        }
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        return "\(minutes)"
    }
}

// MARK: - 时间编辑器
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
            .font(.system(size: NSFont.systemFontSize)) // 使用系统默认文字大小
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
            .font(.system(size: NSFont.systemFontSize))
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

#Preview {
    TimerView()
        .environmentObject(TimerModel())
        .environmentObject(AudioManager())
        .environmentObject(EventManager())
}
