//
//  MenuBarPopoverView.swift
//  LifeTimer
//
//  Created by Developer on 2024.
//

import SwiftUI
#if canImport(Cocoa)
import Cocoa
#endif
// 轻量按压反馈样式，扩大点击区域并在按下时提供视觉反馈（文件级作用域）
struct PressableIconButtonStyle: ButtonStyle {
    var hitSize: CGFloat = 28
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: hitSize, height: hitSize)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: hitSize / 2)
                    .fill(Color.secondary.opacity(configuration.isPressed ? 0.15 : 0.0))
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}


/// 菜单栏弹窗视图，复用SmartReminderDialog的UI和功能
struct MenuBarPopoverView: View {
    @ObservedObject var timerModel: TimerModel
    @EnvironmentObject var eventManager: EventManager
    @EnvironmentObject var smartReminderManager: SmartReminderManager
    
    @State private var currentTask: String = ""
    @State private var showingTaskSelector = false
    @State private var customMinutes: String = ""
    @FocusState private var isCustomInputFocused: Bool
    // 搜索与联想相关状态
    @State private var searchText: String = ""
    @FocusState private var isTaskSearchFocused: Bool
    // 标记当前聚焦周期内用户是否主动修改过输入框内容（用于决定是否用空字符串触发初始联想）
    @State private var hasUserEditedSearch: Bool = false
    @State private var recentTasks: [String] = []
    @State private var filteredRecentTasks: [String] = []
    @State private var filteredPresetTasks: [String] = []
    @State private var isLoadingSuggestions: Bool = false
    @State private var suggestionsDataTask: Task<Void, Never>? = nil
    @State private var suggestionsSearchTask: Task<Void, Never>? = nil
    @State private var selectedSuggestionIndex: Int? = nil
    @State private var isSuggestionVisible: Bool = false
    // 置顶联想项（例如：当前输入框内容），用于在列表顶部优先显示
    @State private var topSuggestion: String? = nil
    private let presetTasks = ["专注", "学习", "工作", "阅读", "写作", "编程", "设计", "思考", "休息", "运动"]
    
    private var shouldShowCreateOption: Bool {
        // 仅在用户主动编辑过输入框时才显示“创建新任务”选项
        // 若顶部联想项与当前输入一致，则不再重复显示创建项
        let topEqualsSearch = (topSuggestion?.lowercased() == searchText.lowercased())
        return hasUserEditedSearch && !searchText.isEmpty && !topEqualsSearch &&
            !filteredRecentTasks.contains(searchText) &&
            !filteredPresetTasks.contains(searchText) &&
            !recentTasks.contains(searchText)
    }
    
    private var allSuggestions: [String] {
        var items: [String] = []
        if let top = topSuggestion, !top.isEmpty {
            items.append(top)
        }
        let topLower = items.first?.lowercased()
        items += filteredRecentTasks.filter { $0.lowercased() != topLower }
        items += filteredPresetTasks.filter { $0.lowercased() != topLower }
        if shouldShowCreateOption { items.append(searchText) }
        return items
    }
    private var isSuggestionDropdownVisible: Bool {
        // 只有在输入框聚焦且存在内容时才显示下拉（包含置顶联想项）
        isTaskSearchFocused && isSuggestionVisible && (
            ((topSuggestion?.isEmpty == false)) ||
            !filteredRecentTasks.isEmpty || !filteredPresetTasks.isEmpty || shouldShowCreateOption
        )
    }
    
    // 复用配置：标准菜单栏弹窗 / 智能提醒弹窗
    enum Mode {
        case standard
        case reminder
    }
    var mode: Mode = .standard
    
    // 当当前任务为空时的回退任务标题（用于提醒弹窗传入选择任务）
    var defaultTaskFallback: String = ""
    
    // 关闭弹窗的回调
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // 根据计时状态显示不同内容
            if timerModel.timerState == .idle {
                // 未开始计时时的UI
                idleStateView
            } else if timerModel.timerState == .completed {
                // 计时完成后的选择面板
                completedStateView
            } else {
                // 计时中的UI
                runningStateView
            }
        }
        .frame(width: 320)
        .padding(20)
        // .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture {
            if isSuggestionDropdownVisible {
                isSuggestionVisible = false
                isTaskSearchFocused = false
            }
        }
        .onAppear {
            // 初始化当前任务
            currentTask = timerModel.getCurrentDisplayTask(fallback: defaultTaskFallback)
            // 初始化搜索文本与联想数据
            searchText = currentTask
            loadTaskSuggestionData()
            // 默认不聚焦输入框，也不显示下拉
            isTaskSearchFocused = false
            isSuggestionVisible = false
            // 初始认为没有发生用户编辑
            hasUserEditedSearch = false
            DispatchQueue.main.async {
                isTaskSearchFocused = false
            }
        }
        // 当弹窗内选择的任务变化时，同步到计时器模型，保证与主界面一致
        .onChange(of: currentTask) { newTask in
            timerModel.setUserCustomTask(newTask)
        }
        // 当外部（如 TimerView）更新任务时，弹窗也同步显示
        .onChange(of: timerModel.userCustomTaskTitle) { newTitle in
            if !newTitle.isEmpty {
                currentTask = newTitle
            }
        }
        // 添加与主界面一致的键盘快捷键：空格（暂停/继续）、+（增加时间）、-（减少时间）
        .background(
            Group {
                // 空格键：根据当前状态开始/暂停/继续/重置
                Button("Toggle Timer (Space)") {
                    handleSpaceKeyPress()
                }
                .keyboardShortcut(.space, modifiers: [])
                .hidden()

                // 增加当前结束时间（按 + 或 Shift+=）
                Button("Increase Time (+)") {
                    if timerModel.canAdjustTime() {
                        timerModel.adjustCurrentTime(by: 5)
                    }
                }
                .keyboardShortcut("=", modifiers: [])
                .hidden()
                .disabled(!timerModel.canAdjustTime())

                // 减少当前结束时间（按 -）
                Button("Decrease Time (-)") {
                    if timerModel.canAdjustTime() {
                        timerModel.adjustCurrentTime(by: -5)
                    }
                }
                .keyboardShortcut("-", modifiers: [])
                .hidden()
                .disabled(!timerModel.canAdjustTime())
            }
        )
        .onDisappear {
            // 取消未完成的任务，优化内存与资源管理
            suggestionsDataTask?.cancel()
            suggestionsSearchTask?.cancel()
        }
    }
    
    // MARK: - 未开始计时时的视图
    private var idleStateView: some View {
        VStack(spacing: 16) {
            // 标题区域
            VStack(spacing: 6) {
                Text(mode == .reminder ? "⏰ 该开始计时了！" : "⏰ 开始计时")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("选择任务并开始专注")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // 任务输入框
            taskInputSection

            // 专注时间按钮网格
            focusTimeGrid

            // 底部按钮
            HStack(spacing: 12) {
                if mode == .reminder {
                    Button("稍后提醒") {
                        let minutes = Int(smartReminderManager.reminderInterval)
                        smartReminderManager.snoozeReminder(minutes: minutes)
                        onClose()
                    }
                    .buttonStyle(.bordered)

                    Spacer()
                } else {
                    Button("打开主窗口") {
                        openMainWindow()
                    }
                    .buttonStyle(.bordered)

                    Spacer()
                    
                    Button("关闭") {
                        onClose()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
    
    // MARK: - 计时中的视图
    private var runningStateView: some View {
        VStack(spacing: 16) {
            // 标题区域
            VStack(spacing: 6) {
                Text("⏰ 计时进行中")
                    .font(.title2)
                    .fontWeight(.semibold)
                // 运行中任务修改 UI 与初始界面保持一致
                taskInputSection
            }
            // 提升标题区域（包含任务输入与下拉）的层级，确保覆盖后续计时与按钮区域
            .compositingGroup()
            .zIndex(9999)

            // 时间显示 + 调节按钮（与主界面逻辑一致）
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    // 减少时间（左侧）
                    Button(action: {
                        if timerModel.canAdjustTime() {
                            timerModel.adjustCurrentTime(by: -5)
                        }
                    }) {
                        Image(systemName: "minus")
                            .font(.title2)
                            .foregroundColor(.secondary)
                            .opacity(timerModel.canAdjustTime() ? 1.0 : 0.35)
                    }
                    .buttonStyle(PressableIconButtonStyle(hitSize: 28))
                    .disabled(!timerModel.canAdjustTime())

                    // 时间文本
                    Text(timerModel.formattedTime())
                        .font(.system(size: 48, weight: .light, design: .monospaced))
                        .foregroundColor(.primary)

                    // 增加时间（右侧）
                    Button(action: {
                        if timerModel.canAdjustTime() {
                            timerModel.adjustCurrentTime(by: 5)
                        }
                    }) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(.secondary)
                            .opacity(timerModel.canAdjustTime() ? 1.0 : 0.35)
                    }
                    .buttonStyle(PressableIconButtonStyle(hitSize: 28))
                    .disabled(!timerModel.canAdjustTime())
                }

                // 状态指示
                if timerModel.timerState == .paused {
                    Text("已暂停")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(4)
                } else if timerModel.timerState == .running {
                    Text(timerModel.currentMode == .pureRest ? "休息中..." : "专注中...")
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(4)
                }
            }

 

            // 控制按钮
            timerControlButtons

            // 底部按钮
            HStack(spacing: 12) {
                Button("打开主窗口") {
                    openMainWindow()
                }
                .buttonStyle(.bordered)

                Spacer()
                
                Button("关闭") {
                    onClose()
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    // MARK: - 计时完成后的视图（集成原 sheet dialog 功能）
    private var completedStateView: some View {
        VStack(spacing: 16) {
            // 标题
            VStack(spacing: 6) {
                Text("🍅 番茄钟已完成！")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("选择下一步行动")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // 支持在完成界面修改任务
            taskInputSection

            // 继续专注
            VStack(spacing: 12) {
                Text("继续专注")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // 使用上次时长 + 快速选择
                HStack(spacing: 8) {
                    Button(action: {
                        startPomodoro(minutes: Int(timerModel.getCurrentPomodoroTime() / 60))
                    }) {
                        VStack(spacing: 4) {
                            Text("上次时长")
                                .font(.caption)
                                // .foregroundColor(.secondary)
                            Text("\(Int(timerModel.getCurrentPomodoroTime() / 60))分钟")
                                .font(.title3)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    // .buttonStyle(.borderedProminent)
                    .tint(.green)

                    ForEach([10, 15, 30], id: \ .self) { minutes in
                        Button(action: {
                            startPomodoro(minutes: minutes)
                        }) {
                            Text("\(minutes)分钟")
                                .font(.title3)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            Divider()

            // 开始休息
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
                    .padding(.vertical, 10)
                }
                .tint(.blue)
            }

            // 底部按钮：菜单弹窗显示“打开主窗口”与“跳过”，提醒模式保持“稍后决定”
            HStack(spacing: 12) {
                if mode == .reminder {
                    Button("稍后决定") {
                        let minutes = Int(smartReminderManager.reminderInterval)
                        smartReminderManager.snoozeReminder(minutes: minutes)
                        onClose()
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                } else {
                    Button("打开主窗口") {
                        openMainWindow()
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("跳过") {
                        timerModel.skipBreak()
                        onClose()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
    
    // MARK: - 计时控制按钮
    private var timerControlButtons: some View {
        VStack(spacing: 8) {
            // 运行中：与主界面逻辑保持一致
            if timerModel.timerState == .running {
                // 番茄模式运行中：暂停 / 放弃 / 提前结束
                if timerModel.currentMode == .singlePomodoro {
                    HStack(spacing: 8) {
                        Button(action: {
                            timerModel.pauseTimer()
                        }) {
                            Text("暂停")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .controlSize(.regular)

                        Button(action: {
                            timerModel.resetTimer()
                            onClose()
                        }) {
                            Text("放弃")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .controlSize(.regular)

                        Button(action: {
                            timerModel.completeEarly()
                            onClose()
                        }) {
                            Text("提前结束")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .controlSize(.regular)
                    }
                }
                // 正计时运行中：暂停 / 结束
                else if timerModel.currentMode == .countUp {
                    HStack(spacing: 8) {
                        Button(action: {
                            timerModel.pauseTimer()
                        }) {
                            Text("暂停")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .controlSize(.regular)

                        Button(action: {
                            timerModel.stopTimer()
                            onClose()
                        }) {
                            Text("结束")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .controlSize(.regular)
                    }
                }
                // 纯休息运行中：结束
                else if timerModel.currentMode == .pureRest {
                    Button(action: {
                        timerModel.stopTimer()
                        onClose()
                    }) {
                        Text("结束")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .controlSize(.regular)
                }
                // 自定义等其他模式运行中：暂停
                else {
                    Button(action: {
                        timerModel.pauseTimer()
                    }) {
                        Text("暂停")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .controlSize(.regular)
                }
            }
            // 暂停中：继续（与主界面一致）
            else if timerModel.timerState == .paused {
                Button(action: {
                    timerModel.startTimer(with: currentTask)
                    onClose()
                }) {
                    Text("继续")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
            // 其他状态：保持原有逻辑
            else {
                Button(action: {
                    timerModel.resetTimer()
                    onClose()
                }) {
                    Text("停止计时")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
        }
    }
    
    // MARK: - 任务输入框区域
    private var taskInputSection: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 8) {
                // 搜索框（保持系统原生样式）
                TextField("搜索或输入任务", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .controlSize(.large)
                    .focused($isTaskSearchFocused)
                    .overlay(alignment: .trailing) {
                        if isTaskSearchFocused && !searchText.isEmpty {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    searchText = ""
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.trailing, 8)
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                            .onHover { isHovered in
                                #if canImport(Cocoa)
                                if isHovered {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                                #endif
                            }
                        }
                    }
                    .onChange(of: searchText) { newText in
                        // 聚焦状态下的内容变化认为是用户编辑
                        if isTaskSearchFocused {
                            hasUserEditedSearch = true
                        }
                        // 输入防抖 300ms
                        suggestionsSearchTask?.cancel()
                        suggestionsSearchTask = Task { @MainActor in
                            // try? await Task.sleep(nanoseconds: 200_000_000)
                            if !Task.isCancelled {
                                await performTaskSuggestionSearch(searchText: newText, preferredFirst: newText)
                                // 重置键盘选中索引
                                selectedSuggestionIndex = allSuggestions.isEmpty ? nil : 0
                            }
                        }
                    }
                    .onSubmit {
                        confirmSuggestionSelection()
                    }
                    .onChange(of: isTaskSearchFocused) { focused in
                        if focused {
                            // 获得焦点时立即显示联想菜单（通过条件渲染）
                            // 若尚未加载数据，则加载
                            if recentTasks.isEmpty { loadTaskSuggestionData() }
                            // 初始联想
                            suggestionsSearchTask?.cancel()
                            suggestionsSearchTask = Task { @MainActor in
                                // 若用户尚未编辑过输入框，则用空字符串进行联想，以展示全部建议
                                let queryText = hasUserEditedSearch ? searchText : ""
                                await performTaskSuggestionSearch(searchText: queryText, preferredFirst: searchText)
                                selectedSuggestionIndex = allSuggestions.isEmpty ? nil : 0
                                isSuggestionVisible = (!filteredRecentTasks.isEmpty || !filteredPresetTasks.isEmpty || shouldShowCreateOption)
                            }
                        } else {
                            isSuggestionVisible = false
                            // 失焦后重置编辑标记，下一次聚焦仍按“未修改”处理
                            hasUserEditedSearch = false
                        }
                    }
                }

            // 键盘导航（上下选择、回车确认）
            Group {
                Button("Select Up") { moveSuggestionSelection(-1) }
                    .keyboardShortcut(.upArrow, modifiers: [])
                    .hidden()
                    .disabled(!isTaskSearchFocused || allSuggestions.isEmpty)
                Button("Select Down") { moveSuggestionSelection(1) }
                    .keyboardShortcut(.downArrow, modifiers: [])
                    .hidden()
                    .disabled(!isTaskSearchFocused || allSuggestions.isEmpty)
                Button("Confirm Selection") { confirmSuggestionSelection() }
                    .keyboardShortcut(.return, modifiers: [])
                    .hidden()
                    .disabled(!isTaskSearchFocused)
            }
        }
        .overlay(alignment: .topLeading) {
            if isSuggestionDropdownVisible {
                VStack(spacing: 0) {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            // 顶部置顶联想项（当前输入内容），优先显示
                            let hasTop = (topSuggestion?.isEmpty == false)
                            let topOffset = hasTop ? 1 : 0
                            if let top = topSuggestion, !top.isEmpty {
                                let topLower = top.lowercased()
                                let isNewTop = !recentTasks.map { $0.lowercased() }.contains(topLower) &&
                                               !presetTasks.map { $0.lowercased() }.contains(topLower)
                                TaskRowView(task: top, isSelected: selectedSuggestionIndex == 0, isNewTask: isNewTop) {
                                    currentTask = top
                                    searchText = top
                                    isTaskSearchFocused = false
                                    isSuggestionVisible = false
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .padding(.top, 8)
                            }
                            if !filteredRecentTasks.isEmpty {
                                Text("最近常用")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 10)
                                    .padding(.top, 8)
                                    .padding(.bottom, 4)
                                ForEach(Array(filteredRecentTasks.enumerated()), id: \.offset) { idx, task in
                                    let globalIndex = topOffset + idx
                                    TaskRowView(task: task, isSelected: selectedSuggestionIndex == globalIndex, isNewTask: false) {
                                        currentTask = task
                                        searchText = task
                                        isTaskSearchFocused = false
                                        isSuggestionVisible = false
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                }
                            }
                            if !filteredPresetTasks.isEmpty {
                                Text("预设任务")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 10)
                                    .padding(.top, 8)
                                    .padding(.bottom, 4)
                                // 为避免 LazyVStack 重复 ID 警告，这里将 offset 全局平移
                                let presetItems = Array(filteredPresetTasks.enumerated()).map { (offset: topOffset + filteredRecentTasks.count + $0.offset, element: $0.element) }
                                ForEach(presetItems, id: \.offset) { idx, task in
                                    let globalIndex = idx
                                    TaskRowView(task: task, isSelected: selectedSuggestionIndex == globalIndex, isNewTask: false) {
                                        currentTask = task
                                        searchText = task
                                        isTaskSearchFocused = false
                                        isSuggestionVisible = false
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                }
                            }
                            if shouldShowCreateOption {
                                Text("创建新任务")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 10)
                                    .padding(.top, 8)
                                    .padding(.bottom, 4)
                                let createIndex = (topOffset + filteredRecentTasks.count + filteredPresetTasks.count)
                                TaskRowView(task: searchText, isSelected: selectedSuggestionIndex == createIndex, isNewTask: true) {
                                    currentTask = searchText
                                    isTaskSearchFocused = false
                                    isSuggestionVisible = false
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                            }
                        }
                    }
                    // 固定高度，避免被父布局压缩
                    .frame(height: 200)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    GlassEffectBackground(radius: 8)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 4)
                .offset(y: 35)
                .zIndex(1000)
            }
        }
        .popover(isPresented: $showingTaskSelector, arrowEdge: .top) {
            TaskSelectorPopoverView(
                selectedTask: $currentTask, 
                isPresented: $showingTaskSelector
            )
            .environmentObject(eventManager)
        }
        // 确保下拉菜单层级始终在最上面（相对同级元素）
        .zIndex(9999)
    }
    
    // MARK: - 专注时间按钮网格
    private var focusTimeGrid: some View {
        VStack(spacing: 8) {
            Text("选择专注时间")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // 两行两列网格布局
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    focusTimeButton(minutes: 10)
                    focusTimeButton(minutes: 20)
                }
                HStack(spacing: 8) {
                    focusTimeButton(minutes: 30)
                    focusTimeButton(minutes: 40)
                }
            }
        }
    }

    // MARK: - 联想数据与搜索逻辑
    private func loadTaskSuggestionData() {
        // 取消之前的数据任务
        suggestionsDataTask?.cancel()
        suggestionsDataTask = Task { @MainActor in
            await performTaskSuggestionDataLoading()
        }
    }
    
    @MainActor
    private func performTaskSuggestionDataLoading() async {
        isLoadingSuggestions = true
        let recent = await Task.detached { [eventManager] in
            async let recentTasks = eventManager.getRecentTasksAsync(limit: 10)
            let tasks = await recentTasks
            return tasks
        }.value
        recentTasks = recent
        // 初始过滤
        await performTaskSuggestionSearch(searchText: searchText, preferredFirst: searchText)
        isLoadingSuggestions = false
    }
    
    @MainActor
    private func performTaskSuggestionSearch(searchText: String, preferredFirst: String? = nil) async {
        let result = await Task.detached { [recentTasks, presetTasks] in
            if searchText.isEmpty {
                return (recentTasks, presetTasks)
            } else {
                let s = searchText.lowercased()
                let r = recentTasks.filter { $0.lowercased().contains(s) }
                let p = presetTasks.filter { $0.lowercased().contains(s) }
                return (r, p)
            }
        }.value
        let preferred = preferredFirst?.trimmingCharacters(in: .whitespacesAndNewlines)
        let preferredLower = preferred?.lowercased()
        if let preferred = preferred, !preferred.isEmpty {
            topSuggestion = preferred
            if let pLower = preferredLower {
                filteredRecentTasks = result.0.filter { $0.lowercased() != pLower }
                filteredPresetTasks = result.1.filter { $0.lowercased() != pLower }
            } else {
                filteredRecentTasks = result.0
                filteredPresetTasks = result.1
            }
        } else {
            topSuggestion = nil
            filteredRecentTasks = result.0
            filteredPresetTasks = result.1
        }
    }
    
    private func moveSuggestionSelection(_ delta: Int) {
        guard !allSuggestions.isEmpty else { selectedSuggestionIndex = nil; return }
        let count = allSuggestions.count
        let current = selectedSuggestionIndex ?? 0
        var next = current + delta
        if next < 0 { next = count - 1 }
        if next >= count { next = 0 }
        selectedSuggestionIndex = next
    }
    
    private func confirmSuggestionSelection() {
        if let idx = selectedSuggestionIndex, idx < allSuggestions.count {
            let task = allSuggestions[idx]
            currentTask = task
            searchText = task
        } else if !searchText.isEmpty {
            currentTask = searchText
        }
        isTaskSearchFocused = false
        isSuggestionVisible = false
    }
    
    // MARK: - 专注时间按钮
    private func focusTimeButton(minutes: Int) -> some View {
        Button(action: {
            startFocus(minutes: minutes)
        }) {
            VStack(spacing: 4) {
                Text("\(minutes)")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("分钟")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        // .buttonStyle(.borderedProminent)
        .controlSize(.regular)
    }
    
    // MARK: - 操作方法
    
    private func startFocus(minutes: Int) {
        timerModel.resetTimer()
        timerModel.setCustomTime(minutes: minutes)
        timerModel.currentMode = .singlePomodoro
        
        // 使用当前选择的任务，如果为空则使用默认任务
        let taskToUse = currentTask.isEmpty ? defaultTaskFallback : currentTask
        timerModel.startTimer(with: taskToUse)
        
        // 关闭弹窗
        onClose()
    }

    private func startPomodoro(minutes: Int) {
        // 先重置计时器状态，这样setCustomTime才能正常工作
        timerModel.resetTimer()
        timerModel.setCustomTime(minutes: minutes)
        timerModel.currentMode = .singlePomodoro
        let taskToUse = currentTask.isEmpty ? defaultTaskFallback : currentTask
        timerModel.startTimer(with: taskToUse)
        onClose()
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
        onClose()
    }

    /// 处理空格键按下事件（与主界面逻辑保持一致）
    private func handleSpaceKeyPress() {
        switch timerModel.timerState {
        case .idle:
            // 空闲状态：开始计时器
            timerModel.startTimer(with: currentTask)

        case .running:
            // 运行状态：纯休息模式直接结束，其他模式暂停
            if timerModel.currentMode == .pureRest {
                timerModel.stopTimer()
            } else {
                timerModel.pauseTimer()
            }

        case .paused:
            // 暂停状态：继续计时器，并恢复音乐播放
            timerModel.startTimer(with: currentTask)

        case .completed:
            // 完成状态：重置计时器（为下一次做准备）
            timerModel.resetTimer()
        }
    }

    private func openMainWindow() {
        // 打开主窗口
        let windowManager = WindowManager.shared
        windowManager.showOrCreateMainWindow()
        
        // 关闭弹窗
        onClose()
    }
}

// MARK: - 预览
struct MenuBarPopoverView_Previews: PreviewProvider {
    static var previews: some View {
        MenuBarPopoverView(
            timerModel: TimerModel(),
            onClose: {}
        )
        .environmentObject(EventManager())
    }
}
