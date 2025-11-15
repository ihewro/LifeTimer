//
//  SettingsView.swift
//  LifeTimer
//
//  Created by Developer on 2024.
//

import SwiftUI

/// 数据文件路径显示组件
struct DataFileRow: View {
    let title: String
    let path: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Button("在Finder中显示") {
                    let url = URL(fileURLWithPath: path)
#if os(macOS)
                    NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
#endif
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("复制路径") {
#if os(macOS)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(path, forType: .string)
#endif
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Text(path)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)
                .textSelection(.enabled)
        }
    }
}

/// 顶部标签按钮组件
struct SettingsTabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .accentColor : .secondary)

                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            .frame(width: 60, height: 50)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}



struct SettingsView: View {
    @EnvironmentObject var timerModel: TimerModel
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var eventManager: EventManager
    @EnvironmentObject var activityMonitor: ActivityMonitorManager
    @EnvironmentObject var smartReminderManager: SmartReminderManager
    @EnvironmentObject var syncManager: SyncManager
    @Environment(\.openURL) private var openURL

    @StateObject private var soundEffectManager = SoundEffectManager.shared
    @StateObject private var appIconManager = AppIconManager.shared

    @State private var selectedTab = 0
    @State private var showingClearAllDataAlert = false
    @State private var showingExportSheet = false
    @State private var showingImportSheet = false
    @State private var exportedData: Data? = nil
    @State private var importResult: String = ""
    @State private var showingImportResult = false

    // 右侧侧边栏状态
    @State private var showingRightSidebar = false
    @State private var rightSidebarContent: RightSidebarContent = .musicList

    // 全局快捷键与 Dock 图标设置
    @AppStorage("GlobalHotKeyEnabled") private var globalHotKeyEnabled: Bool = true
    @AppStorage("GlobalHotKeyModifier") private var globalHotKeyModifier: String = "control" // control | option | command
    @AppStorage("ShowDockIcon") private var showDockIcon: Bool = true

    @AppStorage("ShortcutsEnabled") private var shortcutsEnabled: Bool = false

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // 主内容区域
                contentView
                    .frame(
                        minWidth: showingRightSidebar ?
                            max(400, geometry.size.width - sidebarWidth(for: geometry.size.width)) : 600,
                        minHeight: 500,
                        maxHeight: .infinity
                    )
                    .frame(
                        width: showingRightSidebar ?
                            max(400, geometry.size.width - sidebarWidth(for: geometry.size.width)) : nil
                    )
                    .onChange(of: globalHotKeyEnabled) { newValue in
#if os(macOS)
                        GlobalHotKeyManager.shared.registerHotKey(
                            enabled: newValue,
                            modifier: globalHotKeyModifier
                        )
#endif
                    }
                    .onChange(of: globalHotKeyModifier) { newValue in
#if os(macOS)
                        GlobalHotKeyManager.shared.registerHotKey(
                            enabled: globalHotKeyEnabled,
                            modifier: newValue
                        )
#endif
                    }
                    .onChange(of: showDockIcon) { newValue in
#if os(macOS)
                        NSApp.setActivationPolicy(newValue ? .regular : .accessory)
                        // 解决切换为隐藏 Dock 图标时窗口跑到后面的情况：
                        // 重新激活应用并将主窗口置顶。
                        if !newValue {
                            DispatchQueue.main.async {
                                NSApp.activate(ignoringOtherApps: true)
                                WindowManager.shared.showOrCreateMainWindow()
                            }
                        }
#endif
                    }

                // 右侧侧边栏
                if showingRightSidebar {
                    rightSidebarView
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.3), value: showingRightSidebar)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .toolbar {
            // 左侧：设置标签 Picker
            ToolbarItem(placement: .principal) {
                Picker("", selection: $selectedTab) {
                    Text("计时").tag(0)
                    Text("活动").tag(1)
                    Text("关于").tag(2)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 300)
                .frame(width: 210)
            }

        }
            .alert("清除所有数据", isPresented: $showingClearAllDataAlert) {
                Button("取消", role: .cancel) { }
                Button("确认清除", role: .destructive) {
                    clearAllData()
                }
            } message: {
                Text("此操作将清除所有计时器历史记录和活动监控数据，且无法恢复。确定要继续吗？")
            }
            .fileExporter(
                isPresented: $showingExportSheet,
                document: exportedData != nil ? ExportDocument(data: exportedData!) : nil,
                contentType: .json,
                defaultFilename: "PomodoroTimer_Export_\(formatDateForFilename(Date()))"
            ) { result in
                switch result {
                case .success(let url):
                    importResult = "数据已成功导出到: \(url.lastPathComponent)"
                    showingImportResult = true
                case .failure(let error):
                    importResult = "导出失败: \(error.localizedDescription)"
                    showingImportResult = true
                }
            }
            .fileImporter(
                isPresented: $showingImportSheet,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImportResult(result)
            }
            .alert("导入结果", isPresented: $showingImportResult) {
                Button("确定") { }
            } message: {
                Text(importResult)
            }
    }

    /// 测试智能提醒弹窗
    private func testSmartReminder() {
        // 手动触发智能提醒显示
        smartReminderManager.testShowReminder()
    }

    /// 测试通知（番茄钟1分钟预警）
    private func testOneMinuteWarningNotification() {
        soundEffectManager.sendOneMinuteWarningNotification()
    }

    /// 测试通知（番茄钟结束）
    private func testPomodoroCompletedNotification() {
        soundEffectManager.sendPomodoroCompletedNotification()
    }

    private var contentView: some View {
        Group {
            switch selectedTab {
            case 0:
                combinedTimerSettingsView
            case 1:
                activityMonitorSettingsView
            case 2:
                aboutView
            default:
                combinedTimerSettingsView
            }
        }
    }

    private var combinedTimerSettingsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 时间设置
                VStack(alignment: .leading, spacing: 12) {
                    Text("时间设置")
                        .font(.headline)
                        .padding(.horizontal, 20)

                    VStack(spacing: 12) {
                        TimeSettingRow(
                            title: "番茄时间",
                            time: Binding(
                                get: { timerModel.pomodoroTime },
                                set: { timerModel.pomodoroTime = $0 }
                            )
                        )
                        .padding(.horizontal, 20)

                        TimeSettingRow(
                            title: "休息时间",
                            time: Binding(
                                get: { timerModel.shortBreakTime },
                                set: { timerModel.shortBreakTime = $0 }
                            )
                        )
                        .padding(.horizontal, 20)

                        // 自动休息设置
                        HStack {
                            Text("番茄结束后自动进入休息")
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { timerModel.autoStartBreak },
                                set: { timerModel.autoStartBreak = $0 }
                            ))
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 12)
                    .background(Color.systemBackground)
                    .cornerRadius(8)
                    .padding(.horizontal, 20)
                }

                // 智能提醒设置
                VStack(alignment: .leading, spacing: 12) {
                    Text("智能提醒")
                        .font(.headline)
                        .padding(.horizontal, 20)

                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("提醒间隔时间")
                                Text("设置为0表示关闭智能提醒")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            HStack(spacing: 4) {
                                TextField("5.0", value: Binding(
                                    get: { smartReminderManager.reminderInterval },
                                    set: { smartReminderManager.reminderInterval = max(0, $0) }
                                ), format: .number.precision(.fractionLength(0...2)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                                .multilineTextAlignment(.trailing)

                                Text("分钟")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                        .padding(.horizontal, 20)

                        // 测试按钮
                        HStack {
                            Text("测试智能提醒弹窗")
                                .font(.subheadline)
                            Spacer()
                            Button("测试显示") {
                                testSmartReminder()
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 12)
                    .background(Color.systemBackground)
                    .cornerRadius(8)
                    .padding(.horizontal, 20)
                }

                // 应用图标设置
                VStack(alignment: .leading, spacing: 12) {
                    Text("应用图标")
                        .font(.headline)
                        .padding(.horizontal, 20)

                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("自定义图标")
                                if !appIconManager.currentIconPath.isEmpty {
                                    Text("当前: \(URL(fileURLWithPath: appIconManager.currentIconPath).lastPathComponent)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("使用默认图标")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            HStack(spacing: 8) {
                                Button("选择图标") {
                                    appIconManager.selectIcon()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                if !appIconManager.currentIconPath.isEmpty {
                                    Button("重置默认") {
                                        appIconManager.resetToDefault()
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 12)
                    .background(Color.systemBackground)
                    .cornerRadius(8)
                .padding(.horizontal, 20)
                }

                // 全局快捷键设置
                VStack(alignment: .leading, spacing: 12) {
                    Text("全局快捷键")
                        .font(.headline)
                        .padding(.horizontal, 20)

                    VStack(spacing: 12) {
                        HStack {
                            Text("启用 Ctrl+Space 唤起菜单栏弹窗")
                            Spacer()
                            Toggle("", isOn: $globalHotKeyEnabled)
                        }
                        .padding(.horizontal, 20)

                        HStack {
                            Text("修饰键")
                            Spacer()
                            Picker("", selection: $globalHotKeyModifier) {
                                Text("Control").tag("control")
                                Text("Option").tag("option")
                                Text("Command").tag("command")
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 240)
                            .disabled(!globalHotKeyEnabled)
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 12)
                    .background(Color.systemBackground)
                    .cornerRadius(8)
                    .padding(.horizontal, 20)
                }

                // Dock 图标设置
                VStack(alignment: .leading, spacing: 12) {
                    Text("Dock 图标")
                        .font(.headline)
                        .padding(.horizontal, 20)

                    VStack(spacing: 12) {
                        HStack {
                            Text("在 Dock 中显示应用图标")
                            Spacer()
                            Toggle("", isOn: $showDockIcon)
                        }
                        .padding(.horizontal, 20)

                        Text("关闭后应用将以菜单栏为主，不在 Dock 显示图标")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 12)
                    .background(Color.systemBackground)
                    .cornerRadius(8)
                    .padding(.horizontal, 20)
                }

                // 音频设置
                VStack(alignment: .leading, spacing: 12) {
                    Text("音频设置")
                        .font(.headline)
                        .padding(.horizontal, 20)

                    VStack(spacing: 16) {
                        // BGM文件夹路径
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("BGM文件夹")
                                Spacer()
                                Button("选择") {
                                    audioManager.selectBGMFolder()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }

                            if !audioManager.bgmFolderPath.isEmpty {
                                Text(audioManager.bgmFolderPath)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.horizontal, 20)

                        // 音量控制
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("音量")
                                Spacer()
                                Text("\(Int(audioManager.volume * 100))%")
                                    .foregroundColor(.secondary)
                            }

                            Slider(
                                value: Binding(
                                    get: { audioManager.volume },
                                    set: { audioManager.setVolume($0) }
                                ),
                                in: 0...1
                            )
                        }
                        .padding(.horizontal, 20)

                        // 音乐列表
                        if !audioManager.tracks.isEmpty {
                            Button("音乐列表 (\(audioManager.tracks.count)首)") {
                                rightSidebarContent = .musicList
                                showingRightSidebar = true
                            }
                            .buttonStyle(.borderless)
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.vertical, 12)
                    .background(Color.systemBackground)
                    .cornerRadius(8)
                    .padding(.horizontal, 20)
                }

                // 音效设置
                VStack(alignment: .leading, spacing: 12) {
                    Text("音效设置")
                        .font(.headline)
                        .padding(.horizontal, 20)

                    VStack(spacing: 16) {
                        // 自定义音效文件夹
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("自定义音效文件夹")
                                Spacer()
                                Button("选择") {
                                    soundEffectManager.selectCustomSoundFolder()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }

                            if !soundEffectManager.customSoundFolderPath.isEmpty {
                                Text(soundEffectManager.customSoundFolderPath)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.horizontal, 20)

                        Divider()
                            .padding(.horizontal, 20)

                        // 番茄钟1分钟预警音效
                        SimpleSoundEffectSettingRow(
                            title: "番茄钟1分钟预警",
                            selectedSound: Binding(
                                get: { soundEffectManager.pomodoroOneMinuteWarningSound },
                                set: { soundEffectManager.pomodoroOneMinuteWarningSound = $0 }
                            ),
                            soundEffectManager: soundEffectManager
                        )
                        .padding(.horizontal, 20)

                        // 番茄钟结束音效
                        SimpleSoundEffectSettingRow(
                            title: "番茄钟结束",
                            selectedSound: Binding(
                                get: { soundEffectManager.pomodoroCompletedSound },
                                set: { soundEffectManager.pomodoroCompletedSound = $0 }
                            ),
                            soundEffectManager: soundEffectManager
                        )
                        .padding(.horizontal, 20)

                        // 休息结束音效
                        SimpleSoundEffectSettingRow(
                            title: "休息结束",
                            selectedSound: Binding(
                                get: { soundEffectManager.breakCompletedSound },
                                set: { soundEffectManager.breakCompletedSound = $0 }
                            ),
                            soundEffectManager: soundEffectManager
                        )
                        .padding(.horizontal, 20)

                        // 测试发送通知
                        HStack {
                            Text("测试通知")
                                .font(.subheadline)
                            Spacer()
                            Button("测试发送") {
                                testOneMinuteWarningNotification()
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.horizontal, 20)

                        // 测试番茄结束通知
                        HStack {
                            Text("番茄结束通知")
                                .font(.subheadline)
                            Spacer()
                            Button("测试发送") {
                                testPomodoroCompletedNotification()
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 12)
                    .background(Color.systemBackground)
                    .cornerRadius(8)
                    .padding(.horizontal, 20)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("快捷指令")
                        .font(.headline)
                        .padding(.horizontal, 20)

                    VStack(spacing: 12) {
                        HStack {
                            Text("是否开启快捷指令")
                            Spacer()
                            Toggle("", isOn: $shortcutsEnabled)
                        }
                        .padding(.horizontal, 20)

                        Text("说明：开启后，请在“快捷指令”App创建一个名称为“LifeTimer”的快捷指令，并根据传入的 input 执行对应的操作：tomato（番茄）、timing（正计时）、rest（休息）、cancel（取消）、complete（结束）")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 12)
                    .background(Color.systemBackground)
                    .cornerRadius(8)
                    .padding(.horizontal, 20)
                }

                // // 统计信息
                // VStack(alignment: .leading, spacing: 12) {
                //     Text("统计信息")
                //         .font(.headline)
                //         .padding(.horizontal, 20)

                //     VStack(spacing: 12) {
                //         StatisticRow(
                //             title: "今日完成番茄",
                //             value: "\(eventManager.completedPomodorosToday())个"
                //         )
                //         .padding(.horizontal, 20)

                //         StatisticRow(
                //             title: "今日专注时间",
                //             value: formatTotalTime(eventManager.totalFocusTimeToday())
                //         )
                //         .padding(.horizontal, 20)

                //         // Button("查看详细统计") {
                //         //     rightSidebarContent = .statistics
                //         //     showingRightSidebar = true
                //         // }
                //         // .buttonStyle(.borderless)
                //         // .foregroundColor(.accentColor)
                //         // .padding(.horizontal, 20)
                //     }
                //     .padding(.vertical, 12)
                //     .background(Color.systemBackground)
                //     .cornerRadius(8)
                //     .padding(.horizontal, 20)
                // }

                // 数据存储
                VStack(alignment: .leading, spacing: 12) {
                    Text("数据存储")
                        .font(.headline)
                        .padding(.horizontal, 20)

                    VStack(spacing: 12) {
                        DataFileRow(
                            title: "事件数据文件",
                            path: eventManager.dataFilePath
                        )
                        .padding(.horizontal, 20)

                        Divider()
                            .padding(.horizontal, 20)

                        // 数据管理按钮
                        HStack(spacing: 12) {
                            Button("导出数据") {
                                exportAllData()
                            }
                            .buttonStyle(.bordered)

                            Button("导入数据") {
                                showingImportSheet = true
                            }
                            .buttonStyle(.bordered)

                            Button("清除所有数据") {
                                showingClearAllDataAlert = true
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 12)
                    .background(Color.systemBackground)
                    .cornerRadius(8)
                    .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 20)
        }
    }

    private var timerSettingsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("时间设置")
                        .font(.headline)
                        .padding(.horizontal, 20)

                    VStack(spacing: 12) {
                        TimeSettingRow(
                            title: "番茄时间",
                            time: Binding(
                                get: { timerModel.pomodoroTime },
                                set: { timerModel.pomodoroTime = $0 }
                            )
                        )
                        .padding(.horizontal, 20)

                        TimeSettingRow(
                            title: "休息时间",
                            time: Binding(
                                get: { timerModel.shortBreakTime },
                                set: { timerModel.shortBreakTime = $0 }
                            )
                        )
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 12)
                    .background(Color.systemBackground)
                    .cornerRadius(8)
                    .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 20)
        }
    }


    private var aboutView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("关于应用")
                        .font(.headline)
                        .padding(.horizontal, 20)

                    VStack(spacing: 12) {
                        HStack {
                            Text("版本")
                            Spacer()
                            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-")
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 20)

                        Button("反馈建议") {
                            if let url = URL(string: "https://github.com/ihewro/LifeTimer") {
                                openURL(url)
                            }
                        }
                        .padding(.horizontal, 20)

                        // Button("重置数据") {
                        //     // 重置所有数据
                        // }
                        // .foregroundColor(.red)
                        // .padding(.horizontal, 20)

                        Button("开源项目") {
                            if let url = URL(string: "https://github.com/ihewro/LifeTimer") {
                                openURL(url)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 12)
                    .background(Color.systemBackground)
                    .cornerRadius(8)
                    .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 20)
        }
    }

    private func formatTotalTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60

        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }

    // MARK: - 活动监控设置视图

    private var activityMonitorSettingsView: some View {
        ActivitySettingsView(activityMonitor: activityMonitor)
    }
}

struct TimeSettingRow: View {
    let title: String
    @Binding var time: TimeInterval

    var body: some View {
        HStack {
            Text(title)
            Spacer()

            Stepper(
                value: Binding(
                    get: { time / 60 },
                    set: { time = $0 * 60 }
                ),
                in: 1...120,
                step: 1
            ) {
                Text("\(Int(time / 60))分钟")
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct StatisticRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

struct MusicListView: View {
    @EnvironmentObject var audioManager: AudioManager

    var body: some View {
        List {
            ForEach(audioManager.tracks) { track in
                MusicTrackRow(track: track)
                    .environmentObject(audioManager)
            }
        }
        .navigationTitle("音乐列表")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct MusicTrackRow: View {
    let track: AudioTrack
    @EnvironmentObject var audioManager: AudioManager

    var isCurrentTrack: Bool {
        audioManager.currentTrack?.id == track.id
    }

    var body: some View {
        Button(action: {
            if isCurrentTrack && audioManager.isPlaying {
                audioManager.pausePlayback()
            } else {
                audioManager.previewTrack(track)
            }
        }) {
            HStack {
                // 播放状态图标
                Image(systemName: playButtonIcon)
                    .font(.title2)
                    .foregroundColor(isCurrentTrack ? .blue : .secondary)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.name)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(track.formattedDuration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isCurrentTrack {
                    Image(systemName: "speaker.wave.2")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var playButtonIcon: String {
        if isCurrentTrack {
            return audioManager.isPlaying ? "pause.circle.fill" : "play.circle.fill"
        } else {
            return "play.circle"
        }
    }
}

struct StatisticsView: View {
    @EnvironmentObject var eventManager: EventManager

    var body: some View {
        List {
            Section("今日统计") {
                StatisticRow(
                    title: "完成番茄",
                    value: "\(eventManager.completedPomodorosToday())个"
                )

                StatisticRow(
                    title: "专注时间",
                    value: formatTime(eventManager.totalFocusTimeToday())
                )

                StatisticRow(
                    title: "平均专注时长",
                    value: averageFocusTime()
                )
            }

            Section("本周统计") {
                StatisticRow(
                    title: "完成番茄",
                    value: "\(weeklyCompletedPomodoros())个"
                )

                StatisticRow(
                    title: "专注时间",
                    value: formatTime(weeklyFocusTime())
                )
            }

            Section("历史记录") {
                ForEach(recentEvents(), id: \.id) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: event.type.icon)
                                .foregroundColor(event.type.color)
                            Text(event.title)
                            Spacer()
                            if event.isCompleted {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }

                        Text("\(formatDate(event.startTime)) · \(event.formattedDuration)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("统计详情")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }

    private func averageFocusTime() -> String {
        let completedPomodoros = eventManager.completedPomodorosToday()
        guard completedPomodoros > 0 else { return "0m" }

        let totalTime = eventManager.totalFocusTimeToday()
        let average = totalTime / Double(completedPomodoros)
        return formatTime(average)
    }

    private func weeklyCompletedPomodoros() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now

        return eventManager.events.filter { event in
            event.type == .pomodoro &&
            event.isCompleted &&
            event.startTime >= weekAgo
        }.count
    }

    private func weeklyFocusTime() -> TimeInterval {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now

        return eventManager.events
            .filter { event in
                event.type == .pomodoro &&
                event.isCompleted &&
                event.startTime >= weekAgo
            }
            .reduce(0) { $0 + $1.duration }
    }

    private func recentEvents() -> [PomodoroEvent] {
        eventManager.events
            .filter { $0.isCompleted }
            .sorted { $0.startTime > $1.startTime }
            .prefix(10)
            .map { $0 }
    }
}





#Preview {
    SettingsView()
        .environmentObject(TimerModel())
        .environmentObject(AudioManager())
        .environmentObject(EventManager())
        .environmentObject(ActivityMonitorManager())
}

// MARK: - 音效设置行组件
struct SoundEffectSettingRow: View {
    let title: String
    @Binding var isEnabled: Bool
    let soundType: SoundEffectType
    let soundEffectManager: SoundEffectManager

    var body: some View {
        HStack {
            Text(title)
            Spacer()

            // 预览按钮
            Button("试听") {
                soundEffectManager.previewSound(soundType)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            // 开关
            Toggle("", isOn: $isEnabled)
        }
    }
}

// MARK: - 简化音效设置行组件
struct SimpleSoundEffectSettingRow: View {
    let title: String
    @Binding var selectedSound: SoundSource
    let soundEffectManager: SoundEffectManager

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)

            Spacer()

            // 音效选择下拉菜单
            Picker("选择音效", selection: $selectedSound) {
                // 无音效选项
                Text("无").tag(SoundSource.none)

                // 系统音效分组
                Section("系统音效") {
                    ForEach(SystemSoundOption.availableSystemSounds) { option in
                        Text(option.name)
                            .tag(SoundSource.system(option))
                    }
                }

                // 自定义音效分组
                if !soundEffectManager.customSounds.isEmpty {
                    Section("自定义音效") {
                        ForEach(soundEffectManager.customSounds) { file in
                            Text(file.name)
                                .tag(SoundSource.custom(file))
                        }
                    }
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 200)
        }
    }
}

// MARK: - SettingsView 数据管理扩展

extension SettingsView {
    /// 导出所有数据
    private func exportAllData() {
        do {
            // 获取活动数据
            let activityData = activityMonitor.exportData()

            // 创建导出数据结构
            let exportData = ExportData(
                events: eventManager.events,
                activityData: activityData
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted

            let data = try encoder.encode(exportData)
            exportedData = data
            showingExportSheet = true

            print("导出数据准备完成，事件数量: \(eventManager.events.count)")

        } catch {
            print("导出数据编码失败: \(error)")
            importResult = "导出失败: \(error.localizedDescription)"
            showingImportResult = true
        }
    }

    /// 清除所有数据
    private func clearAllData() {
        eventManager.clearAllEvents()
        activityMonitor.clearAllData()
        syncManager.clearSyncTimestamp()
        importResult = "所有数据已清除，同步状态已重置"
        showingImportResult = true
    }

    /// 处理导入结果
    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                importResult = "未选择文件"
                showingImportResult = true
                return
            }

            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601

                let importData = try decoder.decode(ExportData.self, from: data)

                // 导入事件数据
                let eventSuccess = true
                if !importData.events.isEmpty {
                    eventManager.events = importData.events
                    eventManager.saveEvents()
                }

                // 导入活动数据
                var activitySuccess = true
                if let activityData = importData.activityData {
                    activitySuccess = activityMonitor.importData(from: activityData)
                }

                if eventSuccess && activitySuccess {
                    importResult = "成功导入 \(importData.events.count) 个事件记录"
                } else {
                    importResult = "部分数据导入失败"
                }

            } catch {
                importResult = "导入失败: \(error.localizedDescription)"
            }

            showingImportResult = true

        case .failure(let error):
            importResult = "文件选择失败: \(error.localizedDescription)"
            showingImportResult = true
        }
    }

    /// 格式化日期用于文件名
    private func formatDateForFilename(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: date)
    }
}

// MARK: - 导出数据结构

struct ExportData: Codable {
    let events: [PomodoroEvent]
    let activityData: Data?
    let exportDate: Date
    let version: String

    init(events: [PomodoroEvent], activityData: Data?) {
        self.events = events
        self.activityData = activityData
        self.exportDate = Date()
        self.version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

// MARK: - 导出文档

import UniformTypeIdentifiers

struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] { [.json] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - 右侧侧边栏相关

/// 右侧侧边栏内容类型
enum RightSidebarContent {
    case musicList
    case statistics
}

extension SettingsView {
    /// 右侧侧边栏视图
    private var rightSidebarView: some View {
        GeometryReader { parentGeometry in
            let sidebarWidth = sidebarWidth(for: parentGeometry.size.width)

            VStack(spacing: 0) {
                // 侧边栏标题栏
                HStack {
                    Text(rightSidebarTitle)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    Button(action: {
                        showingRightSidebar = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.systemBackground)

                Divider()

                // 侧边栏内容
                Group {
                    switch rightSidebarContent {
                    case .musicList:
                        MusicListSidebarView()
                            .environmentObject(audioManager)
                    case .statistics:
                        StatisticsSidebarView()
                            .environmentObject(eventManager)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: sidebarWidth, height: parentGeometry.size.height)
        }
        .background(GlassEffectBackground())
    }

    /// 右侧侧边栏标题
    private var rightSidebarTitle: String {
        switch rightSidebarContent {
        case .musicList:
            return "音乐列表"
        case .statistics:
            return "详细统计"
        }
    }

    /// 计算侧边栏宽度
    private func sidebarWidth(for totalWidth: CGFloat) -> CGFloat {
        // 根据总宽度动态计算侧边栏宽度
        let minSidebarWidth: CGFloat = 300
        let idealSidebarWidth: CGFloat = 300
        let maxSidebarWidth: CGFloat = 400
        let minMainContentWidth: CGFloat = 400

        // 如果总宽度足够，使用理想宽度
        if totalWidth >= minMainContentWidth + idealSidebarWidth {
            return idealSidebarWidth
        }
        // 如果总宽度不够理想宽度，但能容纳最小宽度
        else if totalWidth >= minMainContentWidth + minSidebarWidth {
            return max(minSidebarWidth, totalWidth - minMainContentWidth)
        }
        // 如果总宽度太小，使用最小宽度
        else {
            return minSidebarWidth
        }
    }
}

// MARK: - 音乐列表侧边栏视图

struct MusicListSidebarView: View {
    @EnvironmentObject var audioManager: AudioManager

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(audioManager.tracks) { track in
                    MusicTrackSidebarRow(track: track)
                        .environmentObject(audioManager)
                }
            }
        }
        .background(Color.systemBackground)
    }
}

// MARK: - 统计信息侧边栏组件

struct StatisticSidebarRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct RecentEventSidebarRow: View {
    let event: PomodoroEvent

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: event.type.icon)
                    .foregroundColor(event.type.color)
                    .frame(width: 16)

                Text(event.title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer()

                if event.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }

            Text("\(dateFormatter.string(from: event.startTime)) · \(event.formattedDuration)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.systemBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
                )
        )
    }
}



struct MusicTrackSidebarRow: View {
    let track: AudioTrack
    @EnvironmentObject var audioManager: AudioManager

    var isCurrentTrack: Bool {
        audioManager.currentTrack?.id == track.id
    }

    var body: some View {
        Button(action: {
            if isCurrentTrack && audioManager.isPlaying {
                audioManager.pausePlayback()
            } else {
                audioManager.previewTrack(track)
            }
        }) {
            HStack(spacing: 12) {
                // 播放状态图标
                Image(systemName: playButtonIcon)
                    .font(.title2)
                    .foregroundColor(isCurrentTrack ? .blue : .secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.name)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(track.formattedDuration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isCurrentTrack {
                    Image(systemName: "speaker.wave.2")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            Rectangle()
                .fill(isCurrentTrack ? Color.accentColor.opacity(0.1) : Color.clear)
        )
    }

    private var playButtonIcon: String {
        if isCurrentTrack {
            return audioManager.isPlaying ? "pause.circle.fill" : "play.circle.fill"
        } else {
            return "play.circle"
        }
    }
}

// MARK: - 统计信息侧边栏视图

struct StatisticsSidebarView: View {
    @EnvironmentObject var eventManager: EventManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 今日统计
                VStack(alignment: .leading, spacing: 12) {
                    Text("今日统计")
                        .font(.headline)
                        .padding(.horizontal, 16)

                    VStack(spacing: 8) {
                        StatisticSidebarRow(
                            title: "完成番茄",
                            value: "\(eventManager.completedPomodorosToday())个"
                        )

                        StatisticSidebarRow(
                            title: "专注时间",
                            value: formatTime(eventManager.totalFocusTimeToday())
                        )

                        StatisticSidebarRow(
                            title: "平均专注时长",
                            value: averageFocusTime()
                        )
                    }
                    .padding(.horizontal, 16)
                }

                Divider()
                    .padding(.horizontal, 16)

                // 本周统计
                VStack(alignment: .leading, spacing: 12) {
                    Text("本周统计")
                        .font(.headline)
                        .padding(.horizontal, 16)

                    VStack(spacing: 8) {
                        StatisticSidebarRow(
                            title: "完成番茄",
                            value: "\(weeklyCompletedPomodoros())个"
                        )

                        StatisticSidebarRow(
                            title: "专注时间",
                            value: formatTime(weeklyFocusTime())
                        )
                    }
                    .padding(.horizontal, 16)
                }

                Divider()
                    .padding(.horizontal, 16)

                // 最近记录
                VStack(alignment: .leading, spacing: 12) {
                    Text("最近记录")
                        .font(.headline)
                        .padding(.horizontal, 16)

                    LazyVStack(spacing: 4) {
                        ForEach(recentEvents(), id: \.id) { event in
                            RecentEventSidebarRow(event: event)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 16)
        }
        .background(Color.systemBackground)
    }

    // MARK: - 统计计算方法

    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func averageFocusTime() -> String {
        let completedPomodoros = eventManager.completedPomodorosToday()
        guard completedPomodoros > 0 else { return "0m" }

        let totalTime = eventManager.totalFocusTimeToday()
        let average = totalTime / Double(completedPomodoros)
        return formatTime(average)
    }

    private func weeklyCompletedPomodoros() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now

        return eventManager.events.filter { event in
            event.type == .pomodoro &&
            event.isCompleted &&
            event.startTime >= weekAgo
        }.count
    }

    private func weeklyFocusTime() -> TimeInterval {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now

        return eventManager.events
            .filter { event in
                event.type == .pomodoro &&
                event.isCompleted &&
                event.startTime >= weekAgo
            }
            .reduce(0) { $0 + $1.duration }
    }

    private func recentEvents() -> [PomodoroEvent] {
        eventManager.events
//            .filter { $0.isCompleted }
            .sorted { $0.startTime > $1.startTime }
            .prefix(10)
            .map { $0 }
    }

}
