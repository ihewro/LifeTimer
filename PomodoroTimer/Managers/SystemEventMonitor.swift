//
//  SystemEventMonitor.swift
//  PomodoroTimer
//
//  Created by Assistant on 2024
//

#if canImport(Cocoa)
import Cocoa
#endif
import Foundation
import SwiftUI

/// 系统事件监控器
#if canImport(Cocoa)
class SystemEventMonitor: ObservableObject {
    @Published var currentApp: String = ""
    @Published var isMonitoring = false
    @Published var hasAccessibilityPermission = false
    
    private var appStartTime: Date?
    private var lastActiveApp: String?
    private let eventStore = SystemEventStore.shared
    
    // 浏览器监控相关属性
    private var lastURL: String?
    private var urlStartTime: Date?
    
    init() {
        checkAccessibilityPermission()
    }
    
    /// 开始监控
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        setupAppMonitoring()
        setupSystemMonitoring()
        
        isMonitoring = true
        eventStore.recordEvent(type: .systemWake, data: ["reason": "monitoring_started"])
        
        print("系统事件监控已启动")
    }
    
    /// 停止监控
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        // 记录当前应用的使用时间
        recordCurrentAppUsage()
        
        // 移除所有观察者
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
        
        isMonitoring = false
        eventStore.recordEvent(type: .systemSleep, data: ["reason": "monitoring_stopped"])
        
        print("系统事件监控已停止")
    }
    
    /// 检查辅助功能权限
    func checkAccessibilityPermission() {
        hasAccessibilityPermission = AXIsProcessTrusted()
    }
    
    /// 请求辅助功能权限
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        hasAccessibilityPermission = trusted
    }
    
    // MARK: - Private Methods
    
    private func setupAppMonitoring() {
        // 监控应用激活事件
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAppActivation(notification)
        }
        
        // 监控应用终止事件
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAppTermination(notification)
        }
        
        // 获取当前活跃应用
        if let frontmostApp = NSWorkspace.shared.frontmostApplication {
            let appName = frontmostApp.localizedName ?? "Unknown"
            currentApp = appName
            lastActiveApp = appName
            appStartTime = Date()
        }
    }
    
    private func setupSystemMonitoring() {
        // 监控系统睡眠/唤醒
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleSystemSleep()
        }
        
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleSystemWake()
        }
        
        // 监控屏幕锁定/解锁（使用分布式通知）
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenLocked()
        }
        
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenUnlocked()
        }
    }
    
    private func handleAppActivation(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        
        let appName = app.localizedName ?? "Unknown"
        let bundleIdentifier = app.bundleIdentifier ?? "unknown"
        
        // 记录上一个应用的使用时间
        recordCurrentAppUsage()
        
        // 更新当前应用
        currentApp = appName
        lastActiveApp = appName
        appStartTime = Date()
        
        // 记录应用激活事件
        eventStore.recordEvent(type: .appActivated, data: [
            "app": appName,
            "bundle_id": bundleIdentifier,
            "pid": "\(app.processIdentifier)"
        ])
        
        print("应用激活: \(appName)")
    }
    
    private func handleAppTermination(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        
        let appName = app.localizedName ?? "Unknown"
        let bundleIdentifier = app.bundleIdentifier ?? "unknown"
        
        // 如果终止的是当前应用，记录使用时间
        if appName == lastActiveApp {
            recordCurrentAppUsage()
            currentApp = ""
            lastActiveApp = nil
            appStartTime = nil
        }
        
        // 记录应用终止事件
        eventStore.recordEvent(type: .appTerminated, data: [
            "app": appName,
            "bundle_id": bundleIdentifier,
            "pid": "\(app.processIdentifier)"
        ])
        
        print("应用终止: \(appName)")
    }
    
    private func handleSystemSleep() {
        recordCurrentAppUsage()
        eventStore.recordEvent(type: .systemSleep)
        print("系统进入休眠")
    }
    
    private func handleSystemWake() {
        // 重新开始计时
        if let app = lastActiveApp {
            appStartTime = Date()
        }
        eventStore.recordEvent(type: .systemWake)
        print("系统从休眠中唤醒")
    }
    
    private func handleScreenLocked() {
        recordCurrentAppUsage()
        eventStore.recordEvent(type: .screenLocked)
        print("屏幕已锁定")
    }
    
    private func handleScreenUnlocked() {
        // 重新开始计时
        if let app = lastActiveApp {
            appStartTime = Date()
        }
        eventStore.recordEvent(type: .screenUnlocked)
        print("屏幕已解锁")
    }
    
    private func recordCurrentAppUsage() {
        guard let app = lastActiveApp,
              let startTime = appStartTime else { return }
        
        let duration = Date().timeIntervalSince(startTime)
        
        // 只记录超过5秒的使用时间
        if duration > 5 {
            eventStore.recordEvent(type: .appActivated, data: [
                "app": app,
                "duration": "\(duration)",
                "end_time": ISO8601DateFormatter().string(from: Date())
            ])
        }
    }
}

// MARK: - Browser Monitoring Extension

extension SystemEventMonitor {
    /// 浏览器监控器（需要辅助功能权限）
    func startBrowserMonitoring() {
        guard hasAccessibilityPermission else {
            print("需要辅助功能权限才能监控浏览器")
            return
        }
        
        // 每5秒检查一次浏览器URL
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkBrowserURL()
        }
    }
    
    private func checkBrowserURL() {
        let browsers = ["Safari", "Google Chrome", "Firefox", "Microsoft Edge"]
        
        for browserName in browsers {
            if let url = getCurrentURLFromBrowser(browserName) {
                handleURLChange(url, browser: browserName)
                break
            }
        }
    }
    
    private func getCurrentURLFromBrowser(_ browserName: String) -> String? {
        let script: String
        
        switch browserName {
        case "Safari":
            script = """
            tell application "Safari"
                if it is running then
                    try
                        return URL of current tab of front window
                    end try
                end if
            end tell
            """
        case "Google Chrome":
            script = """
            tell application "Google Chrome"
                if it is running then
                    try
                        return URL of active tab of front window
                    end try
                end if
            end tell
            """
        default:
            return nil
        }
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            let result = scriptObject.executeAndReturnError(&error)
            if error == nil {
                return result.stringValue
            }
        }
        
        return nil
    }
    
    private func handleURLChange(_ url: String, browser: String) {
        if lastURL != url {
            // 记录上一个URL的访问时间
            if let lastURL = lastURL, let startTime = urlStartTime {
                let duration = Date().timeIntervalSince(startTime)
                if duration > 5 { // 只记录停留超过5秒的页面
                    recordURLVisit(url: lastURL, duration: duration, browser: browser)
                }
            }
            
            // 更新当前URL
            lastURL = url
            urlStartTime = Date()
        }
    }
    
    private func recordURLVisit(url: String, duration: TimeInterval, browser: String) {
        let domain = extractDomain(from: url)
        
        eventStore.recordEvent(type: .urlVisit, data: [
            "url": url,
            "domain": domain,
            "duration": "\(duration)",
            "browser": browser
        ])
        
        print("网页访问: \(domain) (\(Int(duration))秒)")
    }
    
    private func extractDomain(from url: String) -> String {
        guard let urlComponents = URLComponents(string: url),
              let host = urlComponents.host else {
            return "unknown"
        }
        
        // 移除www前缀
        if host.hasPrefix("www.") {
            return String(host.dropFirst(4))
        }
        
        return host
    }
}

#else
// iOS版本的简化实现
class SystemEventMonitor: ObservableObject {
    @Published var currentApp: String = "iOS App"
    @Published var isMonitoring = false
    @Published var hasAccessibilityPermission = false
    
    private let eventStore = SystemEventStore.shared
    
    init() {
        // iOS上不需要辅助功能权限
        hasAccessibilityPermission = true
    }
    
    func startMonitoring() {
        isMonitoring = true
        print("iOS上的系统监控功能已禁用")
    }
    
    func stopMonitoring() {
        isMonitoring = false
        print("iOS上的系统监控功能已停止")
    }
    
    func checkAccessibilityPermission() {
        hasAccessibilityPermission = true
    }
    
    func requestAccessibilityPermission() {
        hasAccessibilityPermission = true
    }
}
#endif