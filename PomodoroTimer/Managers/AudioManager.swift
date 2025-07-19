//
//  AudioManager.swift
//  PomodoroTimer
//
//  Created by Developer on 2024.
//

import Foundation
import AVFoundation
import SwiftUI

enum PlaybackMode {
    case preview    // 试听模式（10秒）
    case timer      // 计时器模式（循环播放）
}

class AudioManager: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentTrack: AudioTrack?
    @Published var selectedTrack: AudioTrack? {  // 当前选中的音乐（用于计时器播放）
        didSet {
            // 只在初始化完成后才保存设置
            if isInitialized {
                saveSettings()
            }
        }
    }
    @Published var tracks: [AudioTrack] = []
    @Published var bgmFolderPath: String = ""
    @Published var volume: Float = 0.5

    private var audioPlayer: AVAudioPlayer?
    private var currentTrackIndex = 0
    private var previewTimer: Timer?
    private var currentPlaybackMode: PlaybackMode = .timer
    private var isInitialized = false
    
    override init() {
        super.init()
        setupAudioSession()
        loadSettings()
        isInitialized = true
    }
    
    private func setupAudioSession() {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
        #endif
        // macOS doesn't need AVAudioSession setup
    }
    
    func setBGMFolderPath(_ path: String) {
        bgmFolderPath = path
        loadTracksFromFolder()
        saveSettings()
    }
    
    private func loadTracksFromFolder() {
        guard !bgmFolderPath.isEmpty else { return }
        
        let fileManager = FileManager.default
        let url = URL(fileURLWithPath: bgmFolderPath)
        
        do {
            let files = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            let audioFiles = files.filter { file in
                let ext = file.pathExtension.lowercased()
                return ["mp3", "m4a", "wav", "aac", "flac"].contains(ext)
            }
            
            tracks = audioFiles.map { url in
                AudioTrack(
                    name: url.deletingPathExtension().lastPathComponent,
                    url: url,
                    duration: getAudioDuration(url: url)
                )
            }.sorted { $0.name < $1.name }
            
        } catch {
            print("Failed to load tracks: \(error)")
        }
    }
    
    private func getAudioDuration(url: URL) -> TimeInterval {
        do {
            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            return audioPlayer.duration
        } catch {
            return 0
        }
    }
    
    // 试听播放（10秒）
    func previewTrack(_ track: AudioTrack) {
        stopPlayback() // 停止当前播放
        selectedTrack = track // 设置为选中状态（会自动保存设置）

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: track.url)
            audioPlayer?.delegate = self
            audioPlayer?.volume = volume
            audioPlayer?.numberOfLoops = 0 // 不循环
            audioPlayer?.play()

            currentTrack = track
            isPlaying = true
            currentPlaybackMode = .preview

            // 10秒后自动停止
            previewTimer?.invalidate()
            previewTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { _ in
                DispatchQueue.main.async {
                    self.stopPreview()
                }
            }

            if let index = tracks.firstIndex(where: { $0.id == track.id }) {
                currentTrackIndex = index
            }
        } catch {
            print("Failed to preview track: \(error)")
        }
    }

    // 计时器播放（循环）
    func playTrackForTimer(_ track: AudioTrack) {
        stopPlayback() // 停止当前播放

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: track.url)
            audioPlayer?.delegate = self
            audioPlayer?.volume = volume
            audioPlayer?.numberOfLoops = -1 // 无限循环
            audioPlayer?.play()

            currentTrack = track
            selectedTrack = track
            isPlaying = true
            currentPlaybackMode = .timer

            if let index = tracks.firstIndex(where: { $0.id == track.id }) {
                currentTrackIndex = index
            }
        } catch {
            print("Failed to play track for timer: \(error)")
        }
    }

    // 停止试听
    private func stopPreview() {
        previewTimer?.invalidate()
        previewTimer = nil

        if currentPlaybackMode == .preview {
            audioPlayer?.stop()
            audioPlayer = nil
            currentTrack = nil
            isPlaying = false
            // 保持selectedTrack不变，表示该音乐仍被选中
        }
    }
    
    func pausePlayback() {
        audioPlayer?.pause()
        isPlaying = false
    }

    func resumePlayback() {
        // 只有在计时器模式下才允许恢复播放
        if currentPlaybackMode == .timer {
            audioPlayer?.play()
            isPlaying = true
        }
    }

    func stopPlayback() {
        previewTimer?.invalidate()
        previewTimer = nil
        audioPlayer?.stop()
        audioPlayer = nil
        currentTrack = nil
        isPlaying = false
        currentPlaybackMode = .timer
    }

    // 清除选中状态（静音）
    func clearSelection() {
        stopPlayback()
        selectedTrack = nil // 会自动保存设置
    }

    // 计时器开始时播放选中的音乐
    func startTimerPlayback() {
        guard let track = selectedTrack else { return }
        playTrackForTimer(track)
    }

    // 计时器暂停时暂停音乐
    func pauseTimerPlayback() {
        if currentPlaybackMode == .timer {
            pausePlayback()
        }
    }

    // 计时器恢复时恢复音乐
    func resumeTimerPlayback() {
        if currentPlaybackMode == .timer && selectedTrack != nil {
            resumePlayback()
        }
    }

    // 计时器停止时停止音乐
    func stopTimerPlayback() {
        if currentPlaybackMode == .timer {
            stopPlayback()
        }
    }
    
    func nextTrack() {
        guard !tracks.isEmpty else { return }
        currentTrackIndex = (currentTrackIndex + 1) % tracks.count
        playTrackForTimer(tracks[currentTrackIndex])
    }

    func previousTrack() {
        guard !tracks.isEmpty else { return }
        currentTrackIndex = currentTrackIndex > 0 ? currentTrackIndex - 1 : tracks.count - 1
        playTrackForTimer(tracks[currentTrackIndex])
    }
    
    func setVolume(_ newVolume: Float) {
        volume = max(0, min(1, newVolume))
        audioPlayer?.volume = volume
        saveSettings()
    }
    
    func selectBGMFolder() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                setBGMFolderPath(url.path)
            }
        }
        #endif
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(bgmFolderPath, forKey: "BGMFolderPath")
        UserDefaults.standard.set(volume, forKey: "AudioVolume")

        // 保存选中的音乐
        if let selectedTrack = selectedTrack {
            UserDefaults.standard.set(selectedTrack.name, forKey: "SelectedTrackName")
        } else {
            UserDefaults.standard.removeObject(forKey: "SelectedTrackName")
        }
    }

    private func loadSettings() {
        bgmFolderPath = UserDefaults.standard.string(forKey: "BGMFolderPath") ?? ""
        volume = UserDefaults.standard.float(forKey: "AudioVolume")
        if volume == 0 { volume = 0.5 } // 默认音量

        if !bgmFolderPath.isEmpty {
            loadTracksFromFolder()

            // 恢复选中的音乐
            if let selectedTrackName = UserDefaults.standard.string(forKey: "SelectedTrackName") {
                selectedTrack = tracks.first { $0.name == selectedTrackName }
            }
        }
    }
}

extension AudioManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            nextTrack()
        }
    }
}

struct AudioTrack: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let url: URL
    let duration: TimeInterval
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}