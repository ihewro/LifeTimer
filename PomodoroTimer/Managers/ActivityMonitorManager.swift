//
//  ActivityMonitorManager.swift
//  PomodoroTimer
//
//  Created by Assistant on 2024
//

import Foundation
import SwiftUI
import Cocoa

/// 活动监控管理器 - 统一管理所有系统监控功能
class ActivityMonitorManager: ObservableObject {
    @Published var isMonitoring = false
    @Published var hasPermissions = false
    @Published var permissionStatus: PermissionStatus = .unknown
    
    private let systemEventMonitor = SystemEventMonitor()
    private let eventStore = SystemEventStore.shared
    
    enum PermissionStatus {
        case unknown
        case granted
        case denied
        case needsRequest
    }
    
    init() {
        checkPermissions()
    }
    
    /// 检查所需权限
    func checkPermissions() {
        let hasAccessibility = AXIsProcessTrusted()
        
        if hasAccessibility {
            permissionStatus = .granted
            hasPermissions = true
        } else {
            permissionStatus = .needsRequest
            hasPermissions = false
        }
    }
    
    /// 请求权限
    func requestPermissions() {
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
    }
    
    /// 开始监控
    func startMonitoring() {
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
    }
    
    /// 停止监控
    func stopMonitoring() {
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
    }
    
    /// 切换监控状态
    func toggleMonitoring() {
        
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
    }
    
    /// 获取当前应用
    var currentApp: String {
        return systemEventMonitor.currentApp
    }
    
    /// 获取今日统计概览
    func getTodayOverview() -> (activeTime: TimeInterval, appSwitches: Int, websiteVisits: Int) {
        return eventStore.getTodayOverview()
    }
    
    /// 获取应用使用统计
    func getAppUsageStats(for date: Date = Date()) -> [AppUsageStats] {
        return eventStore.getAppUsageStats(for: date)
    }
    
    /// 获取网站访问统计
    func getWebsiteStats(for date: Date = Date()) -> [WebsiteStats] {
        return eventStore.getWebsiteStats(for: date)
    }
    
    /// 清除历史数据
    func clearHistoryData() {
        eventStore.clearAllEvents()
    }
    
    /// 清除指定天数之前的数据
    func clearOldData(olderThanDays days: Int) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        eventStore.clearEventsBefore(cutoffDate)
    }
    
    /// 导出数据
    func exportData() -> String? {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            let data = try encoder.encode(eventStore.events)
            return String(data: data, encoding: .utf8)
        } catch {
            print("导出数据失败: \(error)")
            return nil
        }
    }
    
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
    
    /// 获取监控状态描述
    var monitoringStatusDescription: String {
        if isMonitoring {
            return "监控中 - \(currentApp.isEmpty ? "无活跃应用" : currentApp)"
        } else {
            return "未监控"
        }
    }
}

// MARK: - 权限管理扩展

extension ActivityMonitorManager {
    /// 打开系统偏好设置的辅助功能页面
    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
    
    /// 检查是否为沙盒应用
    var isSandboxed: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }
    
    /// 获取应用权限建议
    var permissionAdvice: String {
        if isSandboxed {
            return "由于沙盒限制，某些监控功能可能受限。建议在系统偏好设置中手动授予辅助功能权限。"
        } else {
            return "请在系统偏好设置 > 安全性与隐私 > 辅助功能中，允许此应用控制您的电脑。"
        }
    }
}

// MARK: - 统计分析扩展

extension ActivityMonitorManager {
    /// 获取生产力分析
    func getProductivityAnalysis(for date: Date = Date()) -> ProductivityAnalysis {
        let appStats = getAppUsageStats(for: date)
        let websiteStats = getWebsiteStats(for: date)
        
        // 简单的生产力分类（可以根据需要扩展）
        let productiveApps = ["Xcode", "Visual Studio Code", "Terminal", "Finder", "TextEdit", "Pages", "Numbers", "Keynote"]
        let entertainmentApps = ["Safari", "Chrome", "Firefox", "Music", "TV", "Photos", "Games"]
        
        var productiveTime: TimeInterval = 0
        var entertainmentTime: TimeInterval = 0
        var otherTime: TimeInterval = 0
        
        for stat in appStats {
            if productiveApps.contains(where: { stat.appName.contains($0) }) {
                productiveTime += stat.totalTime
            } else if entertainmentApps.contains(where: { stat.appName.contains($0) }) {
                entertainmentTime += stat.totalTime
            } else {
                otherTime += stat.totalTime
            }
        }
        
        let totalTime = productiveTime + entertainmentTime + otherTime
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
    }
}

/// 生产力分析结果
struct ProductivityAnalysis {
    let productiveTime: TimeInterval
    let entertainmentTime: TimeInterval
    let otherTime: TimeInterval
    let productivityScore: Double // 0-100
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
        case 80...100:
            return "非常高效"
        case 60..<80:
            return "高效"
        case 40..<60:
            return "中等"
        case 20..<40:
            return "较低"
        default:
            return "需要改进"
        }
    }
}