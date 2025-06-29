//
//  ActivityStatsView.swift
//  PomodoroTimer
//
//  Created by Assistant on 2024
//

import SwiftUI

/// 活动统计视图
struct ActivityStatsView: View {
    @EnvironmentObject var activityMonitor: ActivityMonitorManager
    @State private var selectedDate = Date()
    @State private var selectedTab = 0
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 顶部状态栏
                statusBar
                
                // 日期选择器
                DatePicker("选择日期", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .padding(.horizontal)
                
                // 标签页
                TabView(selection: $selectedTab) {
                    overviewTab
                        .tabItem {
                            Image(systemName: "chart.pie")
                            Text("概览")
                        }
                        .tag(0)
                    
                    appStatsTab
                        .tabItem {
                            Image(systemName: "app.badge")
                            Text("应用")
                        }
                        .tag(1)
                    
                    websiteStatsTab
                        .tabItem {
                            Image(systemName: "globe")
                            Text("网站")
                        }
                        .tag(2)
                    
                    productivityTab
                        .tabItem {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                            Text("生产力")
                        }
                        .tag(3)
                }
            }
            .navigationTitle("活动统计")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                ActivitySettingsView(activityMonitor: activityMonitor)
            }
        }
    }
    
    // MARK: - 状态栏
    
    private var statusBar: some View {
        HStack {
            Circle()
                .fill(activityMonitor.isMonitoring ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            
            Text(activityMonitor.monitoringStatusDescription)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(activityMonitor.isMonitoring ? "停止监控" : "开始监控") {
                activityMonitor.toggleMonitoring()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - 概览标签页
    
    private var overviewTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                let overview = activityMonitor.getTodayOverview()
                
                // 今日概览卡片
                VStack(alignment: .leading, spacing: 12) {
                    Text("今日概览")
                        .font(.headline)
                    
                    HStack(spacing: 20) {
                        StatCard(
                            title: "活跃时间",
                            value: formatTime(overview.activeTime),
                            icon: "clock",
                            color: .blue
                        )
                        
                        StatCard(
                            title: "应用切换",
                            value: "\(overview.appSwitches)",
                            icon: "arrow.triangle.2.circlepath",
                            color: .orange
                        )
                        
                        StatCard(
                            title: "网站访问",
                            value: "\(overview.websiteVisits)",
                            icon: "globe",
                            color: .green
                        )
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
                
                // 快速应用统计
                quickAppStats
                
                // 快速网站统计
                quickWebsiteStats
            }
            .padding()
        }
    }
    
    // MARK: - 应用统计标签页
    
    private var appStatsTab: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                let appStats = activityMonitor.getAppUsageStats(for: selectedDate)
                
                if appStats.isEmpty {
                    Text("暂无应用使用数据")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(appStats, id: \.appName) { stat in
                        AppStatRow(stat: stat)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - 网站统计标签页
    
    private var websiteStatsTab: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                let websiteStats = activityMonitor.getWebsiteStats(for: selectedDate)
                
                if websiteStats.isEmpty {
                    Text("暂无网站访问数据")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(websiteStats, id: \.domain) { stat in
                        WebsiteStatRow(stat: stat)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - 生产力标签页
    
    private var productivityTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                let analysis = activityMonitor.getProductivityAnalysis(for: selectedDate)
                
                // 生产力得分
                VStack(alignment: .leading, spacing: 12) {
                    Text("生产力分析")
                        .font(.headline)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("生产力得分")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text(analysis.formattedProductivityScore)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(productivityColor(analysis.productivityScore))
                            
                            Text(analysis.productivityLevel)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // 生产力环形图
                        if analysis.totalTime > 0 {
                            ProductivityChart(analysis: analysis)
                                .frame(width: 120, height: 120)
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
                
                // 时间分布
                timeDistributionView(analysis: analysis)
                
                // 建议
                productivitySuggestions(analysis: analysis)
            }
            .padding()
        }
    }
    
    // MARK: - 辅助视图
    
    private var quickAppStats: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("热门应用")
                .font(.headline)
            
            let topApps = Array(activityMonitor.getAppUsageStats(for: selectedDate).prefix(3))
            
            if topApps.isEmpty {
                Text("暂无数据")
                    .foregroundColor(.secondary)
            } else {
                ForEach(topApps, id: \.appName) { stat in
                    HStack {
                        Text(stat.appName)
                            .lineLimit(1)
                        Spacer()
                        Text(stat.formattedTime)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var quickWebsiteStats: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("热门网站")
                .font(.headline)
            
            let topSites = Array(activityMonitor.getWebsiteStats(for: selectedDate).prefix(3))
            
            if topSites.isEmpty {
                Text("暂无数据")
                    .foregroundColor(.secondary)
            } else {
                ForEach(topSites, id: \.domain) { stat in
                    HStack {
                        Text(stat.domain)
                            .lineLimit(1)
                        Spacer()
                        Text("\(stat.visits)次 · \(stat.formattedTime)")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private func timeDistributionView(analysis: ProductivityAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("时间分布")
                .font(.headline)
            
            VStack(spacing: 8) {
                TimeDistributionBar(
                    title: "生产性工作",
                    time: analysis.productiveTime,
                    total: analysis.totalTime,
                    color: .green
                )
                
                TimeDistributionBar(
                    title: "娱乐休闲",
                    time: analysis.entertainmentTime,
                    total: analysis.totalTime,
                    color: .orange
                )
                
                TimeDistributionBar(
                    title: "其他",
                    time: analysis.otherTime,
                    total: analysis.totalTime,
                    color: .gray
                )
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private func productivitySuggestions(analysis: ProductivityAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("建议")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                if analysis.productivityScore < 50 {
                    SuggestionRow(
                        icon: "lightbulb",
                        text: "尝试减少娱乐应用的使用时间",
                        color: .yellow
                    )
                }
                
                if analysis.totalWebsiteVisits > 50 {
                    SuggestionRow(
                        icon: "safari",
                        text: "考虑使用网站屏蔽工具提高专注度",
                        color: .blue
                    )
                }
                
                SuggestionRow(
                    icon: "target",
                    text: "设定每日生产力目标，保持良好习惯",
                    color: .green
                )
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - 辅助方法
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func productivityColor(_ score: Double) -> Color {
        switch score {
        case 80...100:
            return .green
        case 60..<80:
            return .blue
        case 40..<60:
            return .orange
        default:
            return .red
        }
    }
}

// MARK: - 子视图组件

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title2)
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct AppStatRow: View {
    let stat: AppUsageStats
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(stat.appName)
                    .font(.headline)
                
                Text("启动 \(stat.activationCount) 次")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(stat.formattedTime)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                if let lastUsed = stat.lastUsed {
                    Text("最后使用: \(formatRelativeTime(lastUsed))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct WebsiteStatRow: View {
    let stat: WebsiteStats
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(stat.domain)
                    .font(.headline)
                
                Text("访问 \(stat.visits) 次")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(stat.formattedTime)
                .font(.headline)
                .fontWeight(.semibold)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct TimeDistributionBar: View {
    let title: String
    let time: TimeInterval
    let total: TimeInterval
    let color: Color
    
    private var percentage: Double {
        total > 0 ? (time / total) : 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                
                Spacer()
                
                Text(formatTime(time))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("(\(String(format: "%.1f", percentage * 100))%)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * percentage, height: 6)
                }
            }
            .frame(height: 6)
        }
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
}

struct SuggestionRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
            
            Spacer()
        }
    }
}

struct ProductivityChart: View {
    let analysis: ProductivityAnalysis
    
    var body: some View {
        ZStack {
            // 背景圆环
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 12)
            
            // 生产力圆环
            Circle()
                .trim(from: 0, to: analysis.productivityScore / 100)
                .stroke(
                    LinearGradient(
                        colors: [.green, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1), value: analysis.productivityScore)
            
            // 中心文字
            VStack(spacing: 2) {
                Text("\(Int(analysis.productivityScore))")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    ActivityStatsView()
}