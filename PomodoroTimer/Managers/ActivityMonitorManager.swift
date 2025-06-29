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

/// 活动监控管理器 - 统一管理所有系统监控功能
class ActivityMonitorManager: ObservableObject {
    @Published var isMonitoring = false
    @Published var hasPermissions = false
    @Published var permissionStatus: PermissionStatus = .unknown

    #if canImport(Cocoa)
    private let systemEventMonitor = SystemEventMonitor()
    #endif
    private let eventStore = SystemEventStore.shared

    enum PermissionStatus {
        case unknown
        case granted
        case denied
        case needsRequest
    }

    init() {
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
            return
        }

        // 请求辅助功能权限
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)

        // 立即检查一次
        checkPermissions()

        // 延迟再次检查权限状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.checkPermissions()
        }
        #else
        hasPermissions = true
        permissionStatus = .granted
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
        #if canImport(Cocoa)
        return eventStore.getTodayOverview()
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

    /// 获取监控状态描述
    var monitoringStatusDescription: String {
        if isMonitoring {
            return "监控中 - \(currentApp.isEmpty ? "无活跃应用" : currentApp)"
        } else {
            return "未监控"
        }
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

    /// 获取生产力分析
    func getProductivityAnalysis(for date: Date = Date()) -> ProductivityAnalysis {
        #if canImport(Cocoa)
        let appStats = getAppUsageStats(for: date)
        let websiteStats = getWebsiteStats(for: date)

        // 简单的生产力分类（可以根据需要扩展）
        let productiveApps = ["Xcode", "Visual Studio Code", "Terminal", "Finder", "TextEdit", "Pages", "Numbers", "Keynote"]
        let entertainmentApps = ["Safari", "Chrome", "Firefox", "YouTube", "Netflix", "Spotify"]

        let productiveTime = appStats
            .filter { stat in productiveApps.contains(where: { stat.appName.contains($0) }) }
            .reduce(0) { $0 + $1.totalTime }

        let entertainmentTime = appStats
            .filter { stat in entertainmentApps.contains(where: { stat.appName.contains($0) }) }
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
                productiveApps.contains(where: { stat.appName.contains($0) })
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