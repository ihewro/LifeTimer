import SwiftUI
import Foundation

struct MonthSidebarStats: View {
    @Binding var selectedDate: Date
    @EnvironmentObject var eventManager: EventManager
    @EnvironmentObject var activityMonitor: ActivityMonitorManager

    @State private var isLoading = false
    @State private var activeDays: Int = 0
    @State private var totalActiveTime: TimeInterval = 0
    @State private var pomodoroSessions: Int = 0
    @State private var topApps: [AppUsageStats] = []
    @State private var dataTask: Task<Void, Never>?

    private let calendar = Calendar.current

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if isLoading {
                    loadingView
                } else {
                    activityOverview
                    monthTopAppsSection
                    Spacer()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .onAppear { loadMonthStatsAsync() }
        .onChange(of: selectedDate) { _ in loadMonthStatsAsync() }
        .onDisappear { dataTask?.cancel() }
    }

    // MARK: - UI Sections

    private var activityOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("活动概览")
                .font(.subheadline)
                .fontWeight(.medium)

            HStack(spacing: 12) {
                statTile(title: "活跃天数", value: "\(activeDays)", systemImage: "calendar")
                statTile(title: "活跃时长", value: formatTime(totalActiveTime), systemImage: "clock")
                statTile(title: "番茄会话", value: "\(pomodoroSessions)", systemImage: "timer")
            }
        }
    }

    private var monthTopAppsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("热门应用")
                .font(.subheadline)
                .fontWeight(.medium)

            if topApps.isEmpty {
                Text("暂无数据")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(Array(topApps.prefix(5)), id: \.appName) { app in
                    HStack {
                        Text(app.appName)
                            .font(.callout)
                            .lineLimit(1)
                        Spacer()
                        Text(formatTime(app.totalTime))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(" · \(app.activationCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.08))
                    )
                }
            }
        }
    }

    private func statTile(title: String, value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private var loadingView: some View {
        VStack(spacing: 10) {
            ProgressView()
                .scaleEffect(0.8)
            Text("加载中…")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    // MARK: - Data Loading

    private func monthDates(for date: Date) -> [Date] {
        guard let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: date)),
              let dayCount = calendar.range(of: .day, in: .month, for: date)?.count else {
            return []
        }
        return (0..<(dayCount)).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: firstDay)
        }
    }

    private func loadMonthStatsAsync() {
        dataTask?.cancel()
        isLoading = true
        let dates = monthDates(for: selectedDate)

        dataTask = Task { [dates] in
            // 批量获取概览与应用使用数据
            let overviewByDate = activityMonitor.getOverviewForDates(dates)
            let eventsByDate = eventManager.eventsForDates(dates)
            let appsByDate = activityMonitor.getAppUsageStatsForDates(dates)

            // 活跃天数与活跃时长
            var activeDayCount = 0
            var totalTime: TimeInterval = 0
            for d in dates {
                if let ov = overviewByDate[d] {
                    totalTime += ov.activeTime
                    if ov.activeTime > 0 { activeDayCount += 1 }
                }
            }

            // 番茄会话总数
            let sessions = eventsByDate.values.reduce(0) { partial, events in
                partial + events.filter { $0.type == .pomodoro }.count
            }

            // 汇总热门应用
            var merged: [String: (time: TimeInterval, count: Int)] = [:]
            for (_, apps) in appsByDate {
                for app in apps {
                    let cur = merged[app.appName] ?? (0, 0)
                    merged[app.appName] = (cur.time + app.totalTime, cur.count + app.activationCount)
                }
            }
            let mergedApps = merged.map { (name, v) in
                AppUsageStats(appName: name, totalTime: v.time, activationCount: v.count, lastUsed: Date())
            }.sorted { $0.totalTime > $1.totalTime }

            if Task.isCancelled { return }
            await MainActor.run {
                activeDays = activeDayCount
                totalActiveTime = totalTime
                pomodoroSessions = sessions
                topApps = Array(mergedApps.prefix(5))
                isLoading = false
            }
        }
    }

    // MARK: - Helpers
    private func formatTime(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 { return "\(hours)h\(minutes)m" } else { return "\(minutes)m" }
    }
}