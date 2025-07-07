import Foundation
import AVFoundation
import AudioToolbox
import UserNotifications
import AppKit

// 音效类型枚举
enum SoundEffectType: String, CaseIterable {
    case pomodoroOneMinuteWarning = "pomodoroOneMinuteWarning"
    case pomodoroCompleted = "pomodoroCompleted"
    case breakCompleted = "breakCompleted"

    var displayName: String {
        switch self {
        case .pomodoroOneMinuteWarning:
            return "番茄钟1分钟预警"
        case .pomodoroCompleted:
            return "番茄钟结束"
        case .breakCompleted:
            return "休息结束"
        }
    }
}

// 系统音效选项
struct SystemSoundOption: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let systemSoundID: SystemSoundID

    static let availableSystemSounds: [SystemSoundOption] = [
        // 使用NSSound名称而不是SystemSoundID，更可靠
        SystemSoundOption(id: "basso", name: "Basso", systemSoundID: 0),
        SystemSoundOption(id: "blow", name: "Blow", systemSoundID: 0),
        SystemSoundOption(id: "bottle", name: "Bottle", systemSoundID: 0),
        SystemSoundOption(id: "frog", name: "Frog", systemSoundID: 0),
        SystemSoundOption(id: "funk", name: "Funk", systemSoundID: 0),
        SystemSoundOption(id: "glass", name: "Glass", systemSoundID: 0),
        SystemSoundOption(id: "hero", name: "Hero", systemSoundID: 0),
        SystemSoundOption(id: "morse", name: "Morse", systemSoundID: 0),
        SystemSoundOption(id: "ping", name: "Ping", systemSoundID: 0),
        SystemSoundOption(id: "pop", name: "Pop", systemSoundID: 0),
        SystemSoundOption(id: "purr", name: "Purr", systemSoundID: 0),
        SystemSoundOption(id: "sosumi", name: "Sosumi", systemSoundID: 0),
        SystemSoundOption(id: "submarine", name: "Submarine", systemSoundID: 0),
        SystemSoundOption(id: "tink", name: "Tink", systemSoundID: 0)
    ]

    static func defaultFor(_ type: SoundEffectType) -> SystemSoundOption {
        switch type {
        case .pomodoroOneMinuteWarning:
            return availableSystemSounds.first { $0.id == "tink" } ?? availableSystemSounds[0]
        case .pomodoroCompleted:
            return availableSystemSounds.first { $0.id == "glass" } ?? availableSystemSounds[1]
        case .breakCompleted:
            return availableSystemSounds.first { $0.id == "purr" } ?? availableSystemSounds[2]
        }
    }
}

// 自定义音效文件
struct CustomSoundFile: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let url: URL

    init(url: URL) {
        self.url = url
        self.name = url.deletingPathExtension().lastPathComponent
        self.id = url.path
    }
}

// 音效来源类型
enum SoundSource: Equatable, Hashable {
    case none
    case system(SystemSoundOption)
    case custom(CustomSoundFile)

    var displayName: String {
        switch self {
        case .none:
            return "无"
        case .system(let option):
            return option.name
        case .custom(let file):
            return file.name
        }
    }

    var id: String {
        switch self {
        case .none:
            return "none"
        case .system(let option):
            return "system_\(option.id)"
        case .custom(let file):
            return "custom_\(file.id)"
        }
    }
}

// 音效数据存储结构
private struct SoundSourceData: Codable {
    let isSystem: Bool
    let id: String
    let path: String
}

// 音效管理器
class SoundEffectManager: ObservableObject {
    static let shared = SoundEffectManager()

    // 通知权限状态
    @Published var notificationPermissionGranted: Bool = false

    // 音效选择设置
    @Published var pomodoroOneMinuteWarningSound: SoundSource = .system(SystemSoundOption.defaultFor(.pomodoroOneMinuteWarning)) {
        didSet {
            saveSettings()
            autoPreviewSound(pomodoroOneMinuteWarningSound)
        }
    }
    @Published var pomodoroCompletedSound: SoundSource = .system(SystemSoundOption.defaultFor(.pomodoroCompleted)) {
        didSet {
            saveSettings()
            autoPreviewSound(pomodoroCompletedSound)
        }
    }
    @Published var breakCompletedSound: SoundSource = .system(SystemSoundOption.defaultFor(.breakCompleted)) {
        didSet {
            saveSettings()
            autoPreviewSound(breakCompletedSound)
        }
    }

    // 自定义音效文件夹
    @Published var customSoundFolderPath: String = "" {
        didSet {
            saveSettings()
            loadCustomSounds()
        }
    }
    @Published var customSounds: [CustomSoundFile] = []

    // 音效播放器
    private var soundPlayers: [String: AVAudioPlayer] = [:]

    // 自动试听定时器
    private var previewTimer: Timer?
    private var currentPreviewPlayer: AVAudioPlayer?

    // UserDefaults keys
    private let pomodoroOneMinuteWarningSoundKey = "pomodoroOneMinuteWarningSound"
    private let pomodoroCompletedSoundKey = "pomodoroCompletedSound"
    private let breakCompletedSoundKey = "breakCompletedSound"
    private let customSoundFolderPathKey = "customSoundFolderPath"

    private let userDefaults = UserDefaults.standard
    
    private init() {
        loadSettings()
        loadCustomSounds()
        requestNotificationPermission()
    }

    // MARK: - 设置管理

    private func loadSettings() {
        // 加载自定义文件夹路径
        customSoundFolderPath = userDefaults.string(forKey: customSoundFolderPathKey) ?? ""

        // 加载音效选择
        loadSoundSelection(for: .pomodoroOneMinuteWarning, key: pomodoroOneMinuteWarningSoundKey)
        loadSoundSelection(for: .pomodoroCompleted, key: pomodoroCompletedSoundKey)
        loadSoundSelection(for: .breakCompleted, key: breakCompletedSoundKey)
    }

    private func loadSoundSelection(for type: SoundEffectType, key: String) {
        guard let data = userDefaults.data(forKey: key),
              let soundData = try? JSONDecoder().decode(SoundSourceData.self, from: data) else {
            // 使用默认值
            setSoundSelection(for: type, sound: .system(SystemSoundOption.defaultFor(type)))
            return
        }

        let soundSource: SoundSource
        if soundData.isSystem {
            if soundData.id == "none" {
                soundSource = .none
            } else if let systemSound = SystemSoundOption.availableSystemSounds.first(where: { $0.id == soundData.id }) {
                soundSource = .system(systemSound)
            } else {
                soundSource = .system(SystemSoundOption.defaultFor(type))
            }
        } else {
            let url = URL(fileURLWithPath: soundData.path)
            if FileManager.default.fileExists(atPath: soundData.path) {
                soundSource = .custom(CustomSoundFile(url: url))
            } else {
                soundSource = .system(SystemSoundOption.defaultFor(type))
            }
        }

        setSoundSelection(for: type, sound: soundSource)
    }

    private func setSoundSelection(for type: SoundEffectType, sound: SoundSource) {
        switch type {
        case .pomodoroOneMinuteWarning:
            pomodoroOneMinuteWarningSound = sound
        case .pomodoroCompleted:
            pomodoroCompletedSound = sound
        case .breakCompleted:
            breakCompletedSound = sound
        }
    }
    
    private func saveSettings() {
        userDefaults.set(customSoundFolderPath, forKey: customSoundFolderPathKey)

        // 保存音效选择
        saveSoundSelection(pomodoroOneMinuteWarningSound, key: pomodoroOneMinuteWarningSoundKey)
        saveSoundSelection(pomodoroCompletedSound, key: pomodoroCompletedSoundKey)
        saveSoundSelection(breakCompletedSound, key: breakCompletedSoundKey)
    }

    private func saveSoundSelection(_ sound: SoundSource, key: String) {
        let soundData: SoundSourceData
        switch sound {
        case .none:
            soundData = SoundSourceData(isSystem: true, id: "none", path: "")
        case .system(let option):
            soundData = SoundSourceData(isSystem: true, id: option.id, path: "")
        case .custom(let file):
            soundData = SoundSourceData(isSystem: false, id: file.id, path: file.url.path)
        }

        if let data = try? JSONEncoder().encode(soundData) {
            userDefaults.set(data, forKey: key)
        }
    }

    // MARK: - 自定义音效管理

    func selectCustomSoundFolder() {
        let openPanel = NSOpenPanel()
        openPanel.title = "选择音效文件夹"
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false

        if openPanel.runModal() == .OK {
            if let url = openPanel.url {
                customSoundFolderPath = url.path
            }
        }
    }

    private func loadCustomSounds() {
        customSounds.removeAll()

        guard !customSoundFolderPath.isEmpty,
              FileManager.default.fileExists(atPath: customSoundFolderPath) else {
            return
        }

        let supportedExtensions = ["aiff", "wav", "mp3", "m4a", "aac", "caf"]

        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: customSoundFolderPath)

            for fileName in contents {
                let fileURL = URL(fileURLWithPath: customSoundFolderPath).appendingPathComponent(fileName)
                let fileExtension = fileURL.pathExtension.lowercased()

                if supportedExtensions.contains(fileExtension) {
                    let customSound = CustomSoundFile(url: fileURL)
                    customSounds.append(customSound)
                }
            }

            // 按文件名排序
            customSounds.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        } catch {
            print("Failed to load custom sounds: \(error)")
        }
    }

    // MARK: - 音效播放器设置
    
    private func setupSoundPlayer(for source: SoundSource) -> AVAudioPlayer? {
        switch source {
        case .none:
            // 无音效，不需要播放器
            return nil
        case .system:
            // 系统音效使用AudioServicesPlaySystemSound，不需要AVAudioPlayer
            return nil
        case .custom(let file):
            do {
                let player = try AVAudioPlayer(contentsOf: file.url)
                player.prepareToPlay()
                return player
            } catch {
                print("Failed to setup sound player for \(file.name): \(error)")
                return nil
            }
        }
    }
    
    // MARK: - 音效播放

    func playSound(_ soundType: SoundEffectType) {
        // 获取对应的音效源
        let soundSource: SoundSource
        switch soundType {
        case .pomodoroOneMinuteWarning:
            soundSource = pomodoroOneMinuteWarningSound
        case .pomodoroCompleted:
            soundSource = pomodoroCompletedSound
        case .breakCompleted:
            soundSource = breakCompletedSound
        }

        // 如果是"无"，则不播放
        guard soundSource != .none else { return }

        playSound(soundSource)
    }

    private func playSound(_ source: SoundSource) {
        switch source {
        case .none:
            // 无音效，不播放
            return
        case .system(let option):
            playSystemSoundByName(option.id)
        case .custom(_):
            // 停止之前的播放
            if let existingPlayer = soundPlayers[source.id] {
                existingPlayer.stop()
                existingPlayer.currentTime = 0
                existingPlayer.play()
            } else {
                // 创建新的播放器
                if let player = setupSoundPlayer(for: source) {
                    soundPlayers[source.id] = player
                    player.play()
                }
            }
        }
    }
    
    // MARK: - 音效预览

    func previewSound(_ soundType: SoundEffectType) {
        // 获取对应的音效源
        let soundSource: SoundSource
        switch soundType {
        case .pomodoroOneMinuteWarning:
            soundSource = pomodoroOneMinuteWarningSound
        case .pomodoroCompleted:
            soundSource = pomodoroCompletedSound
        case .breakCompleted:
            soundSource = breakCompletedSound
        }

        // 预览指定音效源
        previewSound(soundSource)
    }

    func previewSound(_ source: SoundSource) {
        // 如果是"无"，则不播放
        guard source != .none else { return }

        // 停止之前的预览
        stopPreview()

        // 播放音效
        switch source {
        case .none:
            return
        case .system(let option):
            playSystemSoundByName(option.id)
        case .custom(_):
            // 创建预览播放器
            if let player = setupSoundPlayer(for: source) {
                currentPreviewPlayer = player
                player.play()
            }
        }

        // 设置5秒后自动停止
        previewTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            self?.stopPreview()
        }
    }

    // 自动试听功能（选择音效时调用）
    private func autoPreviewSound(_ source: SoundSource) {
        // 延迟一点时间再播放，避免界面更新时的冲突
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.previewSound(source)
        }
    }

    // 停止预览
    private func stopPreview() {
        previewTimer?.invalidate()
        previewTimer = nil

        currentPreviewPlayer?.stop()
        currentPreviewPlayer = nil
    }

    // 使用NSSound播放系统音效
    private func playSystemSoundByName(_ soundName: String) {
        // 首先尝试使用正确的NSSound名称
        let nsSoundName: String
        switch soundName {
        case "basso":
            nsSoundName = "Basso"
        case "blow":
            nsSoundName = "Blow"
        case "bottle":
            nsSoundName = "Bottle"
        case "frog":
            nsSoundName = "Frog"
        case "funk":
            nsSoundName = "Funk"
        case "glass":
            nsSoundName = "Glass"
        case "hero":
            nsSoundName = "Hero"
        case "morse":
            nsSoundName = "Morse"
        case "ping":
            nsSoundName = "Ping"
        case "pop":
            nsSoundName = "Pop"
        case "purr":
            nsSoundName = "Purr"
        case "sosumi":
            nsSoundName = "Sosumi"
        case "submarine":
            nsSoundName = "Submarine"
        case "tink":
            nsSoundName = "Tink"
        default:
            nsSoundName = soundName.capitalized
        }

        // 尝试使用NSSound播放系统音效
        if let sound = NSSound(named: nsSoundName) {
            sound.play()
        } else {
            // 如果NSSound找不到，尝试使用一些已知的系统音效ID作为备选
            let fallbackSoundID: SystemSoundID
            switch soundName {
            case "glass":
                fallbackSoundID = 1054
            case "tink":
                fallbackSoundID = 1057
            case "purr":
                fallbackSoundID = 1103
            case "ping":
                fallbackSoundID = 1027
            case "pop":
                fallbackSoundID = 1028
            default:
                fallbackSoundID = 1000 // 默认系统音效
            }
            AudioServicesPlaySystemSound(fallbackSoundID)
        }
    }
    
    // MARK: - 便捷方法
    
    func playPomodoroOneMinuteWarning() {
        playSound(.pomodoroOneMinuteWarning)
    }
    
    func playPomodoroCompleted() {
        playSound(.pomodoroCompleted)
    }
    
    func playBreakCompleted() {
        playSound(.breakCompleted)
    }
    
    // MARK: - 设置访问器

    func getSoundSource(for soundType: SoundEffectType) -> SoundSource {
        switch soundType {
        case .pomodoroOneMinuteWarning:
            return pomodoroOneMinuteWarningSound
        case .pomodoroCompleted:
            return pomodoroCompletedSound
        case .breakCompleted:
            return breakCompletedSound
        }
    }

    func setSoundSource(_ source: SoundSource, for soundType: SoundEffectType) {
        switch soundType {
        case .pomodoroOneMinuteWarning:
            pomodoroOneMinuteWarningSound = source
        case .pomodoroCompleted:
            pomodoroCompletedSound = source
        case .breakCompleted:
            breakCompletedSound = source
        }
    }

    // MARK: - 音效列表获取

    func getAvailableSounds() -> [SoundSource] {
        var sounds: [SoundSource] = []

        // 首先添加"无"选项
        sounds.append(.none)

        // 添加系统音效
        for systemSound in SystemSoundOption.availableSystemSounds {
            sounds.append(.system(systemSound))
        }

        // 添加自定义音效
        for customSound in customSounds {
            sounds.append(.custom(customSound))
        }

        return sounds
    }

    // MARK: - 通知管理

    /// 请求通知权限
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.notificationPermissionGranted = granted
                if let error = error {
                    print("通知权限请求失败: \(error)")
                }
            }
        }
    }

    /// 发送一分钟倒计时警告通知
    func sendOneMinuteWarningNotification() {
        guard notificationPermissionGranted else {
            print("通知权限未授予，无法发送通知")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "还有一分钟即将结束专注 ⚠️"
        content.subtitle = "进行当前工作的收尾流程吧！"
        content.sound = UNNotificationSound.default

        // 立即发送通知
        let request = UNNotificationRequest(
            identifier: "pomodoro_one_minute_warning",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("发送一分钟警告通知失败: \(error)")
            }
        }
    }

    /// 发送番茄钟完成通知
    func sendPomodoroCompletedNotification() {
        guard notificationPermissionGranted else {
            print("通知权限未授予，无法发送通知")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "番茄钟已完成 🍅"
        content.subtitle = "恭喜完成一个专注时段！"
        content.sound = UNNotificationSound.default

        // 立即发送通知
        let request = UNNotificationRequest(
            identifier: "pomodoro_completed",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("发送番茄钟完成通知失败: \(error)")
            }
        }
    }
}
