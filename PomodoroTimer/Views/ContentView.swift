//
//  ContentView.swift
//  PomodoroTimer
//
//  Created by Developer on 2024.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var timerModel: TimerModel
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var eventManager: EventManager
    @EnvironmentObject var activityMonitor: ActivityMonitorManager
    
    var body: some View {
        TabView {
            TimerView()
                .tabItem {
                    Image(systemName: "timer")
                    Text("计时器")
                }
            
            CalendarView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("日历")
                }
            
            ActivityStatsView()
                .tabItem {
                    Image(systemName: "chart.bar")
                    Text("活动统计")
                }
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("设置")
                }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 600)
        #endif
    }
}

#Preview {
    ContentView()
        .environmentObject(TimerModel())
        .environmentObject(AudioManager())
        .environmentObject(EventManager())
        .environmentObject(ActivityMonitorManager())
}