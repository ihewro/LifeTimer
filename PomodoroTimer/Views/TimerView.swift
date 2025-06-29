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
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 30) {
                // 顶部模式选择器
                HStack {
                    Button(action: {
                        showingModeSelector.toggle()
                    }) {
                        HStack {
                            Text(timerModel.currentMode.rawValue)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Image(systemName: "chevron.down")
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(20)
                    }
                    
                    Spacer()
                    
                    // 音频控制按钮
                    HStack(spacing: 16) {
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
                        
                        Button(action: {
                            // 显示统计信息
                        }) {
                            Image(systemName: "chart.bar")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                        
                        Button(action: {
                            // 静音/取消静音
                        }) {
                            Image(systemName: "bell.slash")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                        
                        Button(action: {
                            // 刷新
                            timerModel.resetTimer()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                        
                        Button(action: {
                            // 更多选项
                        }) {
                            Image(systemName: "ellipsis")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
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
                
                Spacer()
                
                // 控制按钮
                HStack(spacing: 40) {
                    // 重置按钮
                    Button(action: {
                        timerModel.resetTimer()
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title)
                            .foregroundColor(.secondary)
                            .frame(width: 50, height: 50)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
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
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: buttonIcon)
                                .font(.title)
                                .foregroundColor(.white)
                        }
                    }
                    
                    // 跳过按钮
                    Button(action: {
                        timerModel.resetTimer()
                    }) {
                        Image(systemName: "forward.end")
                            .font(.title)
                            .foregroundColor(.secondary)
                            .frame(width: 50, height: 50)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                
                // 今日统计
                VStack(spacing: 8) {
                    Text("今日: 番茄\(eventManager.completedPomodorosToday())个 · \(formatTime(eventManager.totalFocusTimeToday()))分钟 · 智信\(eventManager.completedPomodorosToday())次")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom)
            }
        }
        .sheet(isPresented: $showingModeSelector) {
            ModeSelectionView()
        }
    }
    
    private var buttonIcon: String {
        switch timerModel.timerState {
        case .idle:
            return "play.fill"
        case .running:
            return "pause.fill"
        case .paused:
            return "play.fill"
        case .completed:
            return "checkmark"
        }
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        return "\(minutes)"
    }
}

struct ModeSelectionView: View {
    @EnvironmentObject var timerModel: TimerModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(TimerMode.allCases, id: \.self) { mode in
                    Button(action: {
                        timerModel.changeMode(mode)
                        dismiss()
                    }) {
                        HStack {
                            Text(mode.rawValue)
                                .foregroundColor(.primary)
                            Spacer()
                            if timerModel.currentMode == mode {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("选择模式")
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
        #if os(macOS)
        .frame(width: 300, height: 200)
        #endif
    }
}

#Preview {
    TimerView()
        .environmentObject(TimerModel())
        .environmentObject(AudioManager())
        .environmentObject(EventManager())
}