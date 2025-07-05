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
                        .frame(width: 300, height: 300)

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
                            .frame(width: 300, height: 300)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 1), value: timerModel.progress())
                    }

                    // 中心时间显示
                    Button(action: {
                        if timerModel.timerState == .idle {
                            showingTimeEditor = true
                        }
                    }) {
                        VStack(spacing: 8) {
                            Text(timerModel.formattedTime())
                                .font(.system(size: 48, weight: .light, design: .monospaced))
                                .foregroundColor(.primary)

                            if timerModel.currentMode == .countUp {
                                Text("正计时模式")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(timerModel.timerState != .idle)
                }
                
                Spacer()

                // 控制按钮
                VStack(spacing: 12) {
                    // 主控制按钮
                    Button(action: {
                        switch timerModel.timerState {
                        case .idle, .paused:
                            timerModel.startTimer()
                        case .running:
                            timerModel.pauseTimer()
                        case .completed:
                            timerModel.resetTimer()
                        }
                    }) {
                        Text(buttonText)
                            .font(.title2)
                            .fontWeight(.medium)
                            .frame(width: 180, height: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    // 结束按钮（仅在暂停时显示）
                    if timerModel.timerState == .paused {
                        Button(action: {
                            timerModel.resetTimer()
                        }) {
                            Text("结束")
                                .font(.title2)
                                .fontWeight(.medium)
                                .frame(width: 180, height: 44)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
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
            return "暂停"
        case .paused:
            return "继续"
        case .completed:
            return "开始"
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

    // 预设任务类型
    private let presetTasks = ["专注", "学习", "工作", "阅读", "写作", "编程", "设计", "思考", "休息", "运动"]

    // 最近常用任务（这里可以从UserDefaults或其他存储中获取）
    private let recentTasks = ["项目开发", "英语学习", "阅读技术文档", "代码重构"]

    // 过滤最近常用任务
    var filteredRecentTasks: [String] {
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
        !filteredPresetTasks.contains(searchText)
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

#Preview {
    TimerView()
        .environmentObject(TimerModel())
        .environmentObject(AudioManager())
        .environmentObject(EventManager())
}