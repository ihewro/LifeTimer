//
//  AudioManager.swift
//  PomodoroTimer
//
//  Created by Developer on 2024.
//

import Foundation
import AVFoundation
import SwiftUI

class AudioManager: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentTrack: AudioTrack?
    @Published var tracks: [AudioTrack] = []
    @Published var bgmFolderPath: String = ""
    @Published var volume: Float = 0.5
    
    private var audioPlayer: AVAudioPlayer?
    private var currentTrackIndex = 0
    
    override init() {
        super.init()
        setupAudioSession()
        loadSettings()
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
    
    func playTrack(_ track: AudioTrack) {
        do {
            audioPlayer?.stop()
            audioPlayer = try AVAudioPlayer(contentsOf: track.url)
            audioPlayer?.delegate = self
            audioPlayer?.volume = volume
            audioPlayer?.numberOfLoops = -1 // 无限循环
            audioPlayer?.play()
            
            currentTrack = track
            isPlaying = true
            
            if let index = tracks.firstIndex(where: { $0.id == track.id }) {
                currentTrackIndex = index
            }
        } catch {
            print("Failed to play track: \(error)")
        }
    }
    
    func pausePlayback() {
        audioPlayer?.pause()
        isPlaying = false
    }
    
    func resumePlayback() {
        audioPlayer?.play()
        isPlaying = true
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        currentTrack = nil
        isPlaying = false
    }
    
    func nextTrack() {
        guard !tracks.isEmpty else { return }
        currentTrackIndex = (currentTrackIndex + 1) % tracks.count
        playTrack(tracks[currentTrackIndex])
    }
    
    func previousTrack() {
        guard !tracks.isEmpty else { return }
        currentTrackIndex = currentTrackIndex > 0 ? currentTrackIndex - 1 : tracks.count - 1
        playTrack(tracks[currentTrackIndex])
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
    }
    
    private func loadSettings() {
        bgmFolderPath = UserDefaults.standard.string(forKey: "BGMFolderPath") ?? ""
        volume = UserDefaults.standard.float(forKey: "AudioVolume")
        if volume == 0 { volume = 0.5 } // 默认音量
        
        if !bgmFolderPath.isEmpty {
            loadTracksFromFolder()
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