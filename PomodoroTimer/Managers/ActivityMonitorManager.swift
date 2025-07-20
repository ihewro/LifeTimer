//
//  ActivityMonitorManager.swift
//  PomodoroTimer
//
//  Created by Assistant on 2024
//

import Foundation
import SwiftUI
#if canImport(Cocoa)
import Cocoa
#endif

/// 应用分类配置管理器
class AppCategoryManager: ObservableObject {
    @Published var productiveApps: [String] = []
    @Published var entertainmentApps: [String] = []

    private let userDefaults = UserDefaults.standard
    private let productiveAppsKey = "ProductiveApps"
    private let entertainmentAppsKey = "EntertainmentApps"

    // 默认应用列表
    private let defaultProductiveApps = [
        "Xcode", "Visual Studio Code", "Terminal", "Finder", "TextEdit",
        "Pages", "Numbers", "Keynote", "Code", "IntelliJ IDEA", "PyCharm",
        "WebStorm", "Sublime Text", "Atom", "Vim", "Emacs", "Word", "Excel",
        "PowerPoint", "Notion", "Obsidian", "Bear", "Typora", "MindNode",
        "OmniGraffle", "Sketch", "Figma", "Adobe Photoshop", "Adobe Illustrator"
    ]

    private let defaultEntertainmentApps = [
        "Safari", "Chrome", "Firefox", "YouTube", "Netflix", "Spotify",
        "网易云音乐", "IINA", "VLC", "QuickTime Player", "Steam", "Epic Games",
        "Discord", "Telegram", "WeChat", "QQ", "TikTok", "Instagram",
        "Twitter", "Facebook", "Reddit", "Twitch", "Bilibili", "爱奇艺",
        "腾讯视频", "优酷", "抖音", "小红书", "微博"
    ]

    init() {
        loadConfiguration()
    }

    /// 加载配置
    private func loadConfiguration() {
        if let productiveData = userDefaults.array(forKey: productiveAppsKey) as? [String] {
            productiveApps = productiveData
        } else {
            productiveApps = defaultProductiveApps
            saveConfiguration()
        }

        if let entertainmentData = userDefaults.array(forKey: entertainmentAppsKey) as? [String] {
            entertainmentApps = entertainmentData
        } else {
            entertainmentApps = defaultEntertainmentApps
            saveConfiguration()
        }
    }

    /// 保存配置
    func saveConfiguration() {
        userDefaults.set(productiveApps, forKey: productiveAppsKey)
        userDefaults.set(entertainmentApps, forKey: entertainmentAppsKey)
    }

    /// 添加生产力应用
    func addProductiveApp(_ appName: String) {
        let trimmedName = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty && !productiveApps.contains(trimmedName) else { return }

        // 如果在娱乐应用中，先移除
        if let index = entertainmentApps.firstIndex(of: trimmedName) {
            entertainmentApps.remove(at: index)
        }

        productiveApps.append(trimmedName)
        productiveApps.sort()
        saveConfiguration()
    }

    /// 添加娱乐应用
    func addEntertainmentApp(_ appName: String) {
        let trimmedName = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty && !entertainmentApps.contains(trimmedName) else { return }

        // 如果在生产力应用中，先移除
        if let index = productiveApps.firstIndex(of: trimmedName) {
            productiveApps.remove(at: index)
        }

        entertainmentApps.append(trimmedName)
        entertainmentApps.sort()
        saveConfiguration()
    }

    /// 删除生产力应用
    func removeProductiveApp(at index: Int) {
        guard index < productiveApps.count else { return }
        productiveApps.remove(at: index)
        saveConfiguration()
    }

    /// 删除娱乐应用
    func removeEntertainmentApp(at index: Int) {
        guard index < entertainmentApps.count else { return }
        entertainmentApps.remove(at: index)
        saveConfiguration()
    }

    /// 重置为默认设置
    func resetToDefaults() {
        productiveApps = defaultProductiveApps
        entertainmentApps = defaultEntertainmentApps
        saveConfiguration()
    }

    /// 检查应用是否为生产力应用
    func isProductiveApp(_ appName: String) -> Bool {
        return productiveApps.contains(where: { appName.contains($0) })
    }

    /// 检查应用是否为娱乐应用
    func isEntertainmentApp(_ appName: String) -> Bool {
        return entertainmentApps.contains(where: { appName.contains($0) })
    }
}

/// 活动监控管理器 - 统一管理所有系统监控功能
class ActivityMonitorManager: ObservableObject {
    @Published var isMonitoring = false
    @Published var hasPermissions = false
    @Published var permissionStatus: PermissionStatus = .unknown
    @Published var showPermissionAlert = false

    // 应用分类管理器
    let appCategoryManager = AppCategoryManager()

    // 自动启动监控设置
    @Published var autoStartMonitoring: Bool = true {
        didSet {
            if autoStartMonitoring != oldValue {
                saveSettings()
            }
        }
    }

    // 启动时提示权限设置
    @Published var showPermissionReminderOnStartup: Bool = true {
        didSet {
            if showPermissionReminderOnStartup != oldValue {
                saveSettings()
            }
        }
    }

    #if canImport(Cocoa)
    private let systemEventMonitor = SystemEventMonitor()
    #endif
    private let eventStore = SystemEventStore.shared
    private let userDefaults = UserDefaults.standard

    // UserDefaults 键
    private let autoStartMonitoringKey = "AutoStartMonitoring"
    private let showPermissionReminderOnStartupKey = "ShowPermissionReminderOnStartup"

    enum PermissionStatus {
        case unknown
        case granted
        case denied
        case needsRequest
    }

    init() {
        loadSettings()
        #if canImport(Cocoa)
        checkPermissions()
        #else
        // iOS上默认有权限
        hasPermissions = true
        permissionStatus = .granted
        #endif
    }

    /// 检查所需权限
    func checkPermissions() {
        #if canImport(Cocoa)
        let hasAccessibility = AXIsProcessTrusted()

        if hasAccessibility {
            permissionStatus = .granted
            hasPermissions = true
        } else {
            permissionStatus = .needsRequest
            hasPermissions = false
        }
        #else
        hasPermissions = true
        permissionStatus = .granted
        #endif
    }

    /// 请求权限
    func requestPermissions() {
        #if canImport(Cocoa)
        // 先检查当前权限状态，避免不必要的提示
        let currentlyTrusted = AXIsProcessTrusted()

        if currentlyTrusted {
            // 如果已经有权限，直接更新状态
            permissionStatus = .granted
            hasPermissions = true
            handlePermissionGranted()
            return
        }

        // 请求辅助功能权限
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)

        // 立即检查一次
        checkPermissions()

        // 延迟再次检查权限状态，并在获得权限后自动启动
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.checkPermissions()
            if self.hasPermissions {
                self.handlePermissionGranted()
            }
        }

        // 再次延迟检查，确保权限状态正确更新
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.checkPermissions()
            if self.hasPermissions {
                self.handlePermissionGranted()
            }
        }
        #else
        hasPermissions = true
        permissionStatus = .granted
        handlePermissionGranted()
        #endif
    }

    /// 开始监控
    func startMonitoring() {
        #if canImport(Cocoa)
        guard hasPermissions else {
            print("缺少必要权限，无法开始监控")
            return
        }

        guard !isMonitoring else {
            print("监控已在运行中")
            return
        }

        systemEventMonitor.startMonitoring()

        // 如果有辅助功能权限，启动浏览器监控
        if AXIsProcessTrusted() {
            systemEventMonitor.startBrowserMonitoring()
        }

        isMonitoring = true

        // 记录监控开始事件
        eventStore.recordEvent(type: .userActive, data: [
            "action": "monitoring_started",
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])

        print("活动监控已启动")
        #else
        isMonitoring = true
        print("iOS上的活动监控功能已启用")
        #endif
    }

    /// 停止监控
    func stopMonitoring() {
        #if canImport(Cocoa)
        guard isMonitoring else {
            print("监控未在运行")
            return
        }

        systemEventMonitor.stopMonitoring()
        isMonitoring = false

        // 记录监控停止事件
        eventStore.recordEvent(type: .userInactive, data: [
            "action": "monitoring_stopped",
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])

        print("活动监控已停止")
        #else
        isMonitoring = false
        print("iOS上的活动监控功能已停止")
        #endif
    }

    /// 切换监控状态
    func toggleMonitoring() {
        #if canImport(Cocoa)
        if isMonitoring {
            stopMonitoring()
        } else {
            // 每次都重新检查权限
            checkPermissions()

            if hasPermissions {
                startMonitoring()
            } else {
                // 请求权限
                requestPermissions()

                // 权限请求后立即尝试启动监控
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if self.hasPermissions {
                        self.startMonitoring()
                    } else {
                        // 如果仍然没有权限，再次延迟检查
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.checkPermissions()
                            if self.hasPermissions {
                                self.startMonitoring()
                            }
                        }
                    }
                }
            }
        }
        #else
        // iOS 版本的简化实现
        isMonitoring.toggle()
        print("iOS版本监控状态切换为: \(isMonitoring)")
        #endif
    }

    /// 获取当前应用
    var currentApp: String {
        #if canImport(Cocoa)
        return systemEventMonitor.currentApp
        #else
        return "iOS应用"
        #endif
    }

    /// 获取今日统计概览
    func getTodayOverview() -> (activeTime: TimeInterval, appSwitches: Int, websiteVisits: Int) {
        return getOverview(for: Date())
    }

    /// 获取指定日期的统计概览
    func getOverview(for date: Date) -> (activeTime: TimeInterval, appSwitches: Int, websiteVisits: Int) {
        #if canImport(Cocoa)
        return eventStore.getOverview(for: date)
        #else
        return (activeTime: 3600, appSwitches: 10, websiteVisits: 5)
        #endif
    }

    /// 获取应用使用统计
    func getAppUsageStats(for date: Date = Date()) -> [AppUsageStats] {
        #if canImport(Cocoa)
        return eventStore.getAppUsageStats(for: date)
        #else
        // iOS 版本返回模拟数据
        return [
            AppUsageStats(appName: "iOS应用1", totalTime: 3600, activationCount: 5, lastUsed: Date()),
            AppUsageStats(appName: "iOS应用2", totalTime: 1800, activationCount: 3, lastUsed: Date()),
            AppUsageStats(appName: "iOS应用3", totalTime: 900, activationCount: 2, lastUsed: Date())
        ]
        #endif
    }

    /// 获取指定日期的系统事件（用于时间轴生成）
    func getSystemEvents(for date: Date) -> [SystemEvent] {
        #if canImport(Cocoa)
        return eventStore.getEvents(for: date)
        #else
        // iOS 版本返回空数组
        return []
        #endif
    }

    /// 获取网站访问统计
    func getWebsiteStats(for date: Date = Date()) -> [WebsiteStats] {
        #if canImport(Cocoa)
        return eventStore.getWebsiteStats(for: date)
        #else
        // iOS 版本返回模拟数据
        return [
            WebsiteStats(domain: "example.com", visits: 10, totalTime: 1800, lastVisited: Date()),
            WebsiteStats(domain: "github.com", visits: 8, totalTime: 1200, lastVisited: Date()),
            WebsiteStats(domain: "stackoverflow.com", visits: 5, totalTime: 900, lastVisited: Date())
        ]
        #endif
    }

    /// 清除历史数据
    func clearHistoryData() {
        #if canImport(Cocoa)
        eventStore.clearAllEvents()
        #else
        // iOS 版本暂不支持此功能
        print("iOS版本暂不支持清除历史数据功能")
        #endif
    }

    /// 清除指定天数之前的数据
    func clearOldData(olderThanDays days: Int) {
        #if canImport(Cocoa)
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        eventStore.clearEventsBefore(cutoffDate)
        #else
        print("iOS版本清理 \(days) 天前的数据")
        #endif
    }

    /// 导出数据
    func exportData() -> Data? {
        #if canImport(Cocoa)
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted

            return try encoder.encode(eventStore.events)
        } catch {
            print("导出数据失败: \(error)")
            return nil
        }
        #else
        // iOS 版本返回模拟数据
        let mockData = ["message": "iOS版本暂不支持导出功能"]
        return try? JSONSerialization.data(withJSONObject: mockData)
        #endif
    }

    /// 导入数据
    func importData(from data: Data) -> Bool {
        #if canImport(Cocoa)
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let importedEvents = try decoder.decode([SystemEvent].self, from: data)

            // 清除现有数据
            eventStore.clearAllEvents()

            // 导入新数据
            for event in importedEvents {
                eventStore.recordEvent(type: event.type, data: event.data)
            }

            print("成功导入 \(importedEvents.count) 条记录")
            return true
        } catch {
            print("导入数据失败: \(error)")
            return false
        }
        #else
        print("iOS版本暂不支持导入功能")
        return false
        #endif
    }

    /// 清除所有数据
    func clearAllData() {
        #if canImport(Cocoa)
        eventStore.clearAllEvents()
        print("已清除所有活动监控数据")
        #else
        print("iOS版本暂不支持清除数据功能")
        #endif
    }

    /// 获取监控状态描述
    var monitoringStatusDescription: String {
        if isMonitoring {
            return "监控中 - \(currentApp.isEmpty ? "无活跃应用" : currentApp)"
        } else {
            return "未监控"
        }
    }

    /// 获取数据存储路径
    var dataStoragePath: String {
        #if canImport(Cocoa)
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent("system_events.json")
        return fileURL.path
        #else
        return "iOS沙盒文档目录/system_events.json"
        #endif
    }

    // MARK: - 自动启动逻辑

    /// 应用启动时的自动监控逻辑
    func handleAppLaunch() {
        #if canImport(Cocoa)
        // 检查权限状态
        checkPermissions()

        // 如果启用了自动启动监控
        if autoStartMonitoring {
            if hasPermissions {
                // 有权限，直接开始监控
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.startMonitoring()
                }
            } else {
                // 没有权限，检查是否需要显示权限请求提示
                if showPermissionReminderOnStartup {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.showPermissionAlert = true
                    }
                }
            }
        }
        #else
        // iOS版本直接启动
        if autoStartMonitoring {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.startMonitoring()
            }
        }
        #endif
    }

    /// 权限授予后的自动启动逻辑
    func handlePermissionGranted() {
        if autoStartMonitoring && !isMonitoring {
            startMonitoring()
        }
    }

    /// 用户选择不再提醒权限
    func disablePermissionReminder() {
        showPermissionReminderOnStartup = false
        showPermissionAlert = false
    }

    // MARK: - 设置持久化

    private func saveSettings() {
        userDefaults.set(autoStartMonitoring, forKey: autoStartMonitoringKey)
        userDefaults.set(showPermissionReminderOnStartup, forKey: showPermissionReminderOnStartupKey)
    }

    private func loadSettings() {
        // 加载自动启动设置，默认为true
        if userDefaults.object(forKey: autoStartMonitoringKey) != nil {
            autoStartMonitoring = userDefaults.bool(forKey: autoStartMonitoringKey)
        }

        // 加载权限提醒设置，默认为true
        if userDefaults.object(forKey: showPermissionReminderOnStartupKey) != nil {
            showPermissionReminderOnStartup = userDefaults.bool(forKey: showPermissionReminderOnStartupKey)
        }
    }

    /// 获取数据文件大小
    var dataFileSize: String {
        #if canImport(Cocoa)
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent("system_events.json")

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            if let fileSize = attributes[.size] as? Int64 {
                return ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
            }
        } catch {
            return "未知"
        }
        return "0 KB"
        #else
        return "未知"
        #endif
    }
}

// MARK: - 跨平台扩展

extension ActivityMonitorManager {
    /// 获取权限状态描述
    var permissionStatusDescription: String {
        switch permissionStatus {
        case .unknown:
            return "检查权限中..."
        case .granted:
            return "权限已授予"
        case .denied:
            return "权限被拒绝"
        case .needsRequest:
            return "需要请求权限"
        }
    }

    /// 获取应用权限建议
    var permissionAdvice: String {
        #if canImport(Cocoa)
        if isSandboxed {
            return "由于沙盒限制，某些监控功能可能受限。建议在系统偏好设置中手动授予辅助功能权限。"
        } else {
            return "请在系统偏好设置 > 安全性与隐私 > 辅助功能中，允许此应用控制您的电脑。"
        }
        #else
        return "iOS版本不需要额外权限配置。"
        #endif
    }

    /// 打开系统设置
    func openAccessibilitySettings() {
        #if canImport(Cocoa)
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
        #else
        print("iOS版本不支持打开辅助功能设置")
        #endif
    }

    /// 获取生产力分析（优化版本）
    func getProductivityAnalysis(for date: Date = Date()) -> ProductivityAnalysis {
        #if canImport(Cocoa)
        let appStats = getAppUsageStats(for: date)
        let websiteStats = getWebsiteStats(for: date)

        // 使用配置管理器中的应用分类
        let productiveTime = appStats
            .filter { stat in appCategoryManager.isProductiveApp(stat.appName) }
            .reduce(0) { $0 + $1.totalTime }

        let entertainmentTime = appStats
            .filter { stat in appCategoryManager.isEntertainmentApp(stat.appName) }
            .reduce(0) { $0 + $1.totalTime }

        let totalTime = appStats.reduce(0) { $0 + $1.totalTime }
        let otherTime = totalTime - productiveTime - entertainmentTime

        let productivityScore = totalTime > 0 ? (productiveTime / totalTime) * 100 : 0

        return ProductivityAnalysis(
            productiveTime: productiveTime,
            entertainmentTime: entertainmentTime,
            otherTime: otherTime,
            productivityScore: productivityScore,
            topProductiveApp: appStats.first { stat in
                appCategoryManager.isProductiveApp(stat.appName)
            }?.appName ?? "无",
            totalWebsiteVisits: websiteStats.reduce(0) { $0 + $1.visits }
        )
        #else
        return ProductivityAnalysis(
            productiveTime: 3600, // 1小时默认值
            entertainmentTime: 1800, // 30分钟默认值
            otherTime: 900, // 15分钟默认值
            productivityScore: 75.0, // 默认分数
            topProductiveApp: "iOS应用",
            totalWebsiteVisits: 10
        )
        #endif
    }

    // MARK: - 批量查询优化方法

    /// 批量获取多个日期的概览统计
    func getOverviewForDates(_ dates: [Date]) -> [Date: (activeTime: TimeInterval, appSwitches: Int, websiteVisits: Int)] {
        #if canImport(Cocoa)
        return eventStore.getOverviewForDates(dates)
        #else
        // iOS 版本返回模拟数据
        var result: [Date: (activeTime: TimeInterval, appSwitches: Int, websiteVisits: Int)] = [:]
        for date in dates {
            result[date] = (activeTime: 3600, appSwitches: 10, websiteVisits: 5)
        }
        return result
        #endif
    }

    /// 批量获取多个日期的应用使用统计（优化版本）
    func getAppUsageStatsForDates(_ dates: [Date]) -> [Date: [AppUsageStats]] {
        #if canImport(Cocoa)
        // 使用 SystemEventStore 的批量查询方法，避免频繁的单独调用
        return eventStore.getAppUsageStatsForDates(dates)
        #else
        // iOS 版本返回模拟数据
        var result: [Date: [AppUsageStats]] = [:]
        for date in dates {
            result[date] = [
                AppUsageStats(appName: "iOS应用1", totalTime: 3600, activationCount: 5, lastUsed: date),
                AppUsageStats(appName: "iOS应用2", totalTime: 1800, activationCount: 3, lastUsed: date)
            ]
        }
        return result
        #endif
    }

    #if canImport(Cocoa)
    /// 检查是否为沙盒应用
    var isSandboxed: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }
    #endif
}

/// 生产力分析结果
struct ProductivityAnalysis {
    let productiveTime: TimeInterval
    let entertainmentTime: TimeInterval
    let otherTime: TimeInterval
    let productivityScore: Double
    let topProductiveApp: String
    let totalWebsiteVisits: Int

    var totalTime: TimeInterval {
        return productiveTime + entertainmentTime + otherTime
    }

    var formattedProductivityScore: String {
        return String(format: "%.1f%%", productivityScore)
    }

    var productivityLevel: String {
        switch productivityScore {
        case 80...:
            return "非常高效"
        case 60..<80:
            return "高效"
        case 40..<60:
            return "一般"
        case 20..<40:
            return "较低"
        default:
            return "需要改进"
        }
    }
}