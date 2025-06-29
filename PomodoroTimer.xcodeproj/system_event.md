# 系统事件监控实现方案

## 概述

本文档描述如何在macOS应用中实现用户操作系统行为事件记录功能，包括应用程序使用情况、网页访问记录、时间统计等。

## 功能需求

1. **应用程序监控**
   - 记录用户打开/关闭的应用程序
   - 统计每个应用的使用时长
   - 记录应用切换事件

2. **浏览器活动监控**
   - 监控浏览器访问的网页URL
   - 记录页面停留时间
   - 统计网站访问频率

3. **系统活动监控**
   - 记录系统唤醒/休眠事件
   - 监控屏幕锁定/解锁
   - 记录用户活跃/非活跃状态

## 技术实现方案

### 1. 应用程序监控

#### 使用NSWorkspace监控应用切换

```swift
import Cocoa
import Foundation

class SystemEventMonitor: ObservableObject {
    @Published var currentApp: String = ""
    @Published var appUsageStats: [String: TimeInterval] = [:]
    
    private var appStartTime: Date?
    private var lastActiveApp: String?
    
    init() {
        setupAppMonitoring()
    }
    
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
    }
    
    private func handleAppActivation(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        
        let appName = app.localizedName ?? "Unknown"
        
        // 记录上一个应用的使用时间
        if let lastApp = lastActiveApp, let startTime = appStartTime {
            let duration = Date().timeIntervalSince(startTime)
            appUsageStats[lastApp, default: 0] += duration
        }
        
        // 更新当前应用
        currentApp = appName
        lastActiveApp = appName
        appStartTime = Date()
        
        // 记录事件
        recordEvent(type: .appActivated, data: ["app": appName])
    }
    
    private func handleAppTermination(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        
        let appName = app.localizedName ?? "Unknown"
        recordEvent(type: .appTerminated, data: ["app": appName])
    }
}
```

### 2. 浏览器活动监控

#### 通过Accessibility API监控浏览器

```swift
import ApplicationServices

class BrowserMonitor {
    private var currentURL: String?
    private var urlStartTime: Date?
    
    func startMonitoring() {
        // 需要用户授权Accessibility权限
        guard AXIsProcessTrusted() else {
            requestAccessibilityPermission()
            return
        }
        
        // 定时检查浏览器URL
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.checkBrowserURL()
        }
    }
    
    private func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    private func checkBrowserURL() {
        // 获取当前活跃的浏览器应用
        let browsers = ["Safari", "Google Chrome", "Firefox", "Microsoft Edge"]
        
        for browserName in browsers {
            if let url = getCurrentURLFromBrowser(browserName) {
                handleURLChange(url)
                break
            }
        }
    }
    
    private func getCurrentURLFromBrowser(_ browserName: String) -> String? {
        let script = """
        tell application "\(browserName)"
            if it is running then
                try
                    return URL of active tab of front window
                end try
            end if
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            let result = scriptObject.executeAndReturnError(&error)
            return result.stringValue
        }
        
        return nil
    }
    
    private func handleURLChange(_ url: String) {
        if currentURL != url {
            // 记录上一个URL的停留时间
            if let lastURL = currentURL, let startTime = urlStartTime {
                let duration = Date().timeIntervalSince(startTime)
                recordURLVisit(url: lastURL, duration: duration)
            }
            
            // 更新当前URL
            currentURL = url
            urlStartTime = Date()
        }
    }
    
    private func recordURLVisit(url: String, duration: TimeInterval) {
        let event = SystemEvent(
            type: .urlVisit,
            timestamp: Date(),
            data: [
                "url": url,
                "duration": duration,
                "domain": extractDomain(from: url)
            ]
        )
        SystemEventStore.shared.saveEvent(event)
    }
    
    private func extractDomain(from url: String) -> String {
        guard let urlComponents = URLComponents(string: url) else { return "" }
        return urlComponents.host ?? ""
    }
}
```

### 3. 系统活动监控

```swift
class SystemActivityMonitor {
    private var isUserActive = true
    private var lastActivityTime = Date()
    
    func startMonitoring() {
        // 监控系统睡眠/唤醒
        setupPowerNotifications()
        
        // 监控用户活动
        setupUserActivityMonitoring()
        
        // 监控屏幕锁定
        setupScreenLockMonitoring()
    }
    
    private func setupPowerNotifications() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.recordEvent(type: .systemSleep, data: [:])
        }
        
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.recordEvent(type: .systemWake, data: [:])
        }
    }
    
    private func setupUserActivityMonitoring() {
        // 监控鼠标和键盘活动
        let eventMask: CGEventMask = (1 << CGEventType.mouseMoved.rawValue) |
                                    (1 << CGEventType.leftMouseDown.rawValue) |
                                    (1 << CGEventType.keyDown.rawValue)
        
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { _, _, event, refcon in
                let monitor = Unmanaged<SystemActivityMonitor>.fromOpaque(refcon!).takeUnretainedValue()
                monitor.handleUserActivity()
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("Failed to create event tap")
            return
        }
        
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }
    
    private func handleUserActivity() {
        let now = Date()
        let timeSinceLastActivity = now.timeIntervalSince(lastActivityTime)
        
        // 如果超过5分钟没有活动，认为用户不活跃
        if timeSinceLastActivity > 300 && isUserActive {
            isUserActive = false
            recordEvent(type: .userInactive, data: ["inactiveDuration": timeSinceLastActivity])
        } else if !isUserActive {
            isUserActive = true
            recordEvent(type: .userActive, data: [:])
        }
        
        lastActivityTime = now
    }
    
    private func setupScreenLockMonitoring() {
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { _ in
            self.recordEvent(type: .screenLocked, data: [:])
        }
        
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { _ in
            self.recordEvent(type: .screenUnlocked, data: [:])
        }
    }
}
```

### 4. 数据模型和存储

```swift
struct SystemEvent: Codable, Identifiable {
    let id = UUID()
    let type: EventType
    let timestamp: Date
    let data: [String: Any]
    
    enum EventType: String, CaseIterable, Codable {
        case appActivated = "app_activated"
        case appTerminated = "app_terminated"
        case urlVisit = "url_visit"
        case systemSleep = "system_sleep"
        case systemWake = "system_wake"
        case userActive = "user_active"
        case userInactive = "user_inactive"
        case screenLocked = "screen_locked"
        case screenUnlocked = "screen_unlocked"
    }
    
    private enum CodingKeys: String, CodingKey {
        case type, timestamp, data
    }
    
    init(type: EventType, timestamp: Date, data: [String: Any]) {
        self.type = type
        self.timestamp = timestamp
        self.data = data
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(EventType.self, forKey: .type)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        
        // 处理Any类型的data
        if let dataDict = try? container.decode([String: String].self, forKey: .data) {
            data = dataDict
        } else {
            data = [:]
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(timestamp, forKey: .timestamp)
        
        // 简化data编码
        let stringData = data.compactMapValues { "\($0)" }
        try container.encode(stringData, forKey: .data)
    }
}

class SystemEventStore: ObservableObject {
    static let shared = SystemEventStore()
    
    @Published var events: [SystemEvent] = []
    private let fileURL: URL
    
    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = documentsPath.appendingPathComponent("system_events.json")
        loadEvents()
    }
    
    func saveEvent(_ event: SystemEvent) {
        events.append(event)
        saveToFile()
    }
    
    private func saveToFile() {
        do {
            let data = try JSONEncoder().encode(events)
            try data.write(to: fileURL)
        } catch {
            print("Failed to save events: \(error)")
        }
    }
    
    private func loadEvents() {
        do {
            let data = try Data(contentsOf: fileURL)
            events = try JSONDecoder().decode([SystemEvent].self, from: data)
        } catch {
            print("Failed to load events: \(error)")
            events = []
        }
    }
    
    // 统计功能
    func getAppUsageStats(for date: Date) -> [String: TimeInterval] {
        let calendar = Calendar.current
        let dayEvents = events.filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
        
        var stats: [String: TimeInterval] = [:]
        
        for event in dayEvents {
            if event.type == .appActivated,
               let appName = event.data["app"] as? String,
               let duration = event.data["duration"] as? TimeInterval {
                stats[appName, default: 0] += duration
            }
        }
        
        return stats
    }
    
    func getWebsiteStats(for date: Date) -> [String: (visits: Int, totalTime: TimeInterval)] {
        let calendar = Calendar.current
        let dayEvents = events.filter { 
            calendar.isDate($0.timestamp, inSameDayAs: date) && $0.type == .urlVisit
        }
        
        var stats: [String: (visits: Int, totalTime: TimeInterval)] = [:]
        
        for event in dayEvents {
            if let domain = event.data["domain"] as? String,
               let duration = event.data["duration"] as? TimeInterval {
                let current = stats[domain] ?? (visits: 0, totalTime: 0)
                stats[domain] = (visits: current.visits + 1, totalTime: current.totalTime + duration)
            }
        }
        
        return stats
    }
}
```

## 权限要求

### 1. Accessibility权限
- 用于监控浏览器URL和用户活动
- 在系统偏好设置 > 安全性与隐私 > 辅助功能中授权

### 2. 应用权限配置
在`Info.plist`中添加：

```xml
<key>NSAppleEventsUsageDescription</key>
<string>此应用需要访问其他应用以监控使用情况</string>
<key>NSSystemAdministrationUsageDescription</key>
<string>此应用需要系统管理权限以监控系统事件</string>
```

## 集成到现有项目

### 1. 创建监控管理器

```swift
class ActivityMonitorManager: ObservableObject {
    private let systemEventMonitor = SystemEventMonitor()
    private let browserMonitor = BrowserMonitor()
    private let systemActivityMonitor = SystemActivityMonitor()
    
    @Published var isMonitoring = false
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        systemEventMonitor.startMonitoring()
        browserMonitor.startMonitoring()
        systemActivityMonitor.startMonitoring()
        
        isMonitoring = true
    }
    
    func stopMonitoring() {
        // 实现停止监控逻辑
        isMonitoring = false
    }
}
```

### 2. 在主应用中集成

```swift
@main
struct PomodoroTimerApp: App {
    @StateObject private var activityMonitor = ActivityMonitorManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(activityMonitor)
                .onAppear {
                    activityMonitor.startMonitoring()
                }
        }
    }
}
```

## 数据可视化

可以创建统计视图来展示收集的数据：

```swift
struct ActivityStatsView: View {
    @ObservedObject var eventStore = SystemEventStore.shared
    @State private var selectedDate = Date()
    
    var body: some View {
        VStack {
            DatePicker("选择日期", selection: $selectedDate, displayedComponents: .date)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 应用使用统计
                    AppUsageStatsView(date: selectedDate)
                    
                    // 网站访问统计
                    WebsiteStatsView(date: selectedDate)
                }
            }
        }
        .padding()
    }
}
```

## 注意事项

1. **隐私保护**：确保用户了解数据收集范围，提供数据删除选项
2. **性能影响**：监控功能可能影响系统性能，需要优化
3. **权限管理**：需要用户主动授权相关权限
4. **数据安全**：敏感数据应加密存储
5. **合规性**：确保符合相关隐私法规要求

## 扩展功能

1. **智能分类**：自动分类应用和网站（工作、娱乐、学习等）
2. **时间提醒**：基于使用数据设置使用时间提醒
3. **生产力分析**：分析工作效率模式
4. **数据导出**：支持导出数据进行进一步分析
5. **云同步**：支持多设备数据同步

这个实现方案提供了完整的系统事件监控功能，可以根据具体需求进行调整和扩展。