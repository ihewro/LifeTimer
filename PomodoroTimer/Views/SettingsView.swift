//
//  SettingsView.swift
//  PomodoroTimer
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
                    NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("复制路径") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(path, forType: .string)
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

    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // 顶部标签栏
            topTabBar

            Divider()

            // 内容区域
            contentView
        }
        .frame(minWidth: 600, minHeight: 500)
    }

    private var topTabBar: some View {
        HStack(spacing: 0) {
            SettingsTabButton(
                title: "计时",
                icon: "timer",
                isSelected: selectedTab == 0,
                action: { selectedTab = 0 }
            )

            SettingsTabButton(
                title: "活动监控",
                icon: "chart.bar",
                isSelected: selectedTab == 1,
                action: { selectedTab = 1 }
            )

            SettingsTabButton(
                title: "关于",
                icon: "info.circle",
                isSelected: selectedTab == 2,
                action: { selectedTab = 2 }
            )

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor))
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
                            title: "短休息",
                            time: Binding(
                                get: { timerModel.shortBreakTime },
                                set: { timerModel.shortBreakTime = $0 }
                            )
                        )
                        .padding(.horizontal, 20)

                        TimeSettingRow(
                            title: "长休息",
                            time: Binding(
                                get: { timerModel.longBreakTime },
                                set: { timerModel.longBreakTime = $0 }
                            )
                        )
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 12)
                    .background(Color(NSColor.controlBackgroundColor))
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
                            NavigationLink("音乐列表 (\(audioManager.tracks.count)首)") {
                                MusicListView()
                                    .environmentObject(audioManager)
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.vertical, 12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .padding(.horizontal, 20)
                }

                // 统计信息
                VStack(alignment: .leading, spacing: 12) {
                    Text("统计信息")
                        .font(.headline)
                        .padding(.horizontal, 20)

                    VStack(spacing: 12) {
                        StatisticRow(
                            title: "今日完成番茄",
                            value: "\(eventManager.completedPomodorosToday())个"
                        )
                        .padding(.horizontal, 20)

                        StatisticRow(
                            title: "今日专注时间",
                            value: formatTotalTime(eventManager.totalFocusTimeToday())
                        )
                        .padding(.horizontal, 20)

                        NavigationLink("查看详细统计") {
                            StatisticsView()
                                .environmentObject(eventManager)
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .padding(.horizontal, 20)
                }

                // 数据文件路径
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
                    }
                    .padding(.vertical, 12)
                    .background(Color(NSColor.controlBackgroundColor))
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
                            title: "短休息",
                            time: Binding(
                                get: { timerModel.shortBreakTime },
                                set: { timerModel.shortBreakTime = $0 }
                            )
                        )
                        .padding(.horizontal, 20)

                        TimeSettingRow(
                            title: "长休息",
                            time: Binding(
                                get: { timerModel.longBreakTime },
                                set: { timerModel.longBreakTime = $0 }
                            )
                        )
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 20)
        }
    }

    private var audioSettingsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
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
                            NavigationLink("音乐列表 (\(audioManager.tracks.count)首)") {
                                MusicListView()
                                    .environmentObject(audioManager)
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.vertical, 12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 20)
        }
    }

    private var statisticsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("统计信息")
                        .font(.headline)
                        .padding(.horizontal, 20)

                    VStack(spacing: 12) {
                        StatisticRow(
                            title: "今日完成番茄",
                            value: "\(eventManager.completedPomodorosToday())个"
                        )
                        .padding(.horizontal, 20)

                        StatisticRow(
                            title: "今日专注时间",
                            value: formatTotalTime(eventManager.totalFocusTimeToday())
                        )
                        .padding(.horizontal, 20)

                        NavigationLink("查看详细统计") {
                            StatisticsView()
                                .environmentObject(eventManager)
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 12)
                    .background(Color(NSColor.controlBackgroundColor))
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
                            Text("1.0.0")
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 20)

                        Button("反馈建议") {
                            // 打开邮件或反馈页面
                        }
                        .padding(.horizontal, 20)

                        Button("重置数据") {
                            // 重置所有数据
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 12)
                    .background(Color(NSColor.controlBackgroundColor))
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
                audioManager.playTrack(track)
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