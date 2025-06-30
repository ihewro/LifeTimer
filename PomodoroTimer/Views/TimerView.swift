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
        GeometryReader { geometry in
            VStack(spacing: 30) {
                // 顶部控制栏
                HStack {
                    // 模式选择下拉菜单
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
                                .font(.headline)
                                .foregroundColor(.primary)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())

                    Spacer()

                    // 右侧控制按钮
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
                .padding(.horizontal)
                
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

                // 主计时器圆环
                ZStack {
                    // 背景圆环
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 8)
                        .frame(width: min(geometry.size.width * 0.7, 300))

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
                            .frame(width: min(geometry.size.width * 0.7, 300))
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
                VStack(spacing: 16) {
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
                            .foregroundColor(.white)
                            .frame(width: 200, height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(Color.brown)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())

                    // 结束按钮（仅在暂停时显示）
                    if timerModel.timerState == .paused {
                        Button(action: {
                            timerModel.resetTimer()
                        }) {
                            Text("结束")
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .frame(width: 200, height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 25)
                                        .stroke(Color.secondary, lineWidth: 1)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                Spacer()
            }
        }
        .background(Color.white)
        .sheet(isPresented: $showingTimeEditor) {
            TimeEditorView(minutes: $editingMinutes) { newMinutes in
                timerModel.setCustomTime(minutes: newMinutes)
            }
        }
        .sheet(isPresented: $showingTaskSelector) {
            TaskSelectorView(selectedTask: $selectedTask)
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
    @State private var tempMinutes: Int
    @State private var inputText: String

    init(minutes: Binding<Int>, onConfirm: @escaping (Int) -> Void) {
        self._minutes = minutes
        self.onConfirm = onConfirm
        self._tempMinutes = State(initialValue: minutes.wrappedValue)
        self._inputText = State(initialValue: String(minutes.wrappedValue))
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("设置时间")
                .font(.headline)
                .padding(.top)

            VStack {
                Button(action: {
                    if tempMinutes < 99 {
                        tempMinutes += 1
                        inputText = String(tempMinutes)
                    }
                }) {
                    Image(systemName: "chevron.up")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                .buttonStyle(PlainButtonStyle())

                HStack {
                    TextField("", text: $inputText)
                        .font(.largeTitle)
                        .fontWeight(.light)
                        .multilineTextAlignment(.center)
                        .frame(minWidth: 60)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onChange(of: inputText) { newValue in
                            // 只允许数字输入
                            let filtered = newValue.filter { $0.isNumber }
                            if filtered != newValue {
                                inputText = filtered
                            }

                            // 更新tempMinutes
                            if let value = Int(filtered), value >= 1, value <= 99 {
                                tempMinutes = value
                            }
                        }

                    Text("分钟")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }

                Button(action: {
                    if tempMinutes > 1 {
                        tempMinutes -= 1
                        inputText = String(tempMinutes)
                    }
                }) {
                    Image(systemName: "chevron.down")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)

            HStack(spacing: 20) {
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 100, height: 44)

                Button("确定") {
                    minutes = tempMinutes
                    onConfirm(tempMinutes)
                    dismiss()
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 100, height: 44)
                .background(Color.brown)
                .foregroundColor(.white)
                .cornerRadius(22)
            }
            .padding(.bottom)
        }
        .frame(width: 300, height: 250)
    }
}

// MARK: - 任务选择器
struct TaskSelectorView: View {
    @Binding var selectedTask: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedTab = 0

    private let commonTasks = ["专注", "学习", "工作", "阅读", "写作", "编程", "设计", "思考"]
    private let recentTasks = ["我", "项目A", "项目B", "学习Swift"]

    var filteredTasks: [String] {
        let tasks = selectedTab == 0 ? recentTasks : commonTasks
        if searchText.isEmpty {
            return tasks
        } else {
            return tasks.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 系统样式的标签切换
                Picker("", selection: $selectedTab) {
                    Text("任务").tag(0)
                    Text("常用专注").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.top)

                // 搜索框
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("搜索", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
                .padding(.top, 16)

                // 任务列表
                List {
                    ForEach(filteredTasks, id: \.self) { task in
                        Button(action: {
                            selectedTask = task
                            dismiss()
                        }) {
                            HStack {
                                Circle()
                                    .stroke(Color.secondary, lineWidth: 1)
                                    .frame(width: 20, height: 20)

                                Text(task)
                                    .foregroundColor(.primary)

                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    // 如果搜索结果为空且有搜索文本，显示"使用当前输入"选项
                    if filteredTasks.isEmpty && !searchText.isEmpty {
                        Button(action: {
                            selectedTask = searchText
                            dismiss()
                        }) {
                            HStack {
                                Circle()
                                    .stroke(Color.secondary, lineWidth: 1)
                                    .frame(width: 20, height: 20)

                                Text("使用 \"\(searchText)\"")
                                    .foregroundColor(.primary)

                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("选择任务")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button("完成") {
                        dismiss()
                    }
                }
                #endif
            }
        }
        .frame(width: 400, height: 500)
    }
}

#Preview {
    TimerView()
        .environmentObject(TimerModel())
        .environmentObject(AudioManager())
        .environmentObject(EventManager())
}