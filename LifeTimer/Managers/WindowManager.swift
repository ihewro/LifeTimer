//
//  WindowManager.swift
//  LifeTimer
//
//  Created by Developer on 2024.
//

import SwiftUI
#if canImport(Cocoa)
import Cocoa
#endif

/// 主窗口管理器 - 符合 macOS SwiftUI 最佳实践
#if os(macOS)
class WindowManager: ObservableObject {
    static let shared = WindowManager()
    
    private init() {}
    
    /// 主窗口标识符
    static let mainWindowID = "main"
    
    /// 检查是否有可见的主窗口
    var hasVisibleMainWindow: Bool {
        return findMainWindows().contains { window in
            window.isVisible && !window.isMiniaturized
        }
    }
    
    /// 查找所有主窗口（包括隐藏和最小化的）
    func findMainWindows() -> [NSWindow] {
        return NSApp.windows.filter { window in
            // 过滤条件：
            // 1. 可以成为主窗口
            // 2. 不是智能提醒窗口
            // 3. 是 AppKit 窗口（SwiftUI WindowGroup 创建的窗口）
            window.canBecomeMain &&
            !isSmartReminderWindow(window) &&
            isAppKitWindow(window)
        }
    }
    
    /// 显示或创建主窗口
    func showOrCreateMainWindow() {
        NSLog("WindowManager: showOrCreateMainWindow called")
        
        // 首先尝试显示现有的隐藏或最小化窗口
        if showExistingMainWindow() {
            NSLog("WindowManager: Successfully showed existing window")
            return
        }
        
        // 如果没有现有窗口，创建新窗口
        NSLog("WindowManager: No existing window found, creating new window")
        createNewMainWindow()
    }
    
    /// 尝试显示现有的主窗口
    @discardableResult
    private func showExistingMainWindow() -> Bool {
        let mainWindows = findMainWindows()
        
        NSLog("WindowManager: Found \(mainWindows.count) main windows")
        
        // 首先尝试找到可见但不在前台的窗口
        if let visibleWindow = mainWindows.first(where: { $0.isVisible && !$0.isMiniaturized }) {
            NSLog("WindowManager: Found visible window, bringing to front")
            bringWindowToFront(visibleWindow)
            return true
        }
        
        // 然后尝试找到最小化的窗口
        if let minimizedWindow = mainWindows.first(where: { $0.isMiniaturized }) {
            NSLog("WindowManager: Found minimized window, deminiaturizing")
            minimizedWindow.deminiaturize(nil)
            bringWindowToFront(minimizedWindow)
            return true
        }
        
        // 最后尝试找到隐藏的窗口
        if let hiddenWindow = mainWindows.first(where: { !$0.isVisible }) {
            NSLog("WindowManager: Found hidden window, showing")
            hiddenWindow.setIsVisible(true)
            bringWindowToFront(hiddenWindow)
            return true
        }
        
        return false
    }
    
    /// 创建新的主窗口
    private func createNewMainWindow() {
        // 使用 SwiftUI 的 openWindow 环境值来创建新窗口
        // 这需要通过通知系统来实现，因为我们不能直接访问 @Environment
        NotificationCenter.default.post(
            name: .init("CreateNewMainWindow"),
            object: nil
        )
        
        // 备用方案：如果通知系统失败，尝试其他方法
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if !self.hasVisibleMainWindow {
                NSLog("WindowManager: Notification method failed, trying fallback")
                self.createWindowFallback()
            }
        }
    }
    
    /// 备用窗口创建方法
    private func createWindowFallback() {
        // 方法1：尝试通过现有窗口控制器创建新窗口
        if let windowController = NSApp.mainWindow?.windowController {
            NSLog("WindowManager: Trying windowController.newWindowForTab")
            windowController.newWindowForTab(nil)
            return
        }
        
        // 方法2：尝试通过菜单系统创建新窗口
        if let fileMenu = NSApp.mainMenu?.item(withTitle: "File"),
           let newMenuItem = fileMenu.submenu?.item(withTitle: "New") {
            NSLog("WindowManager: Trying File > New menu item")
            NSApp.sendAction(newMenuItem.action!, to: newMenuItem.target, from: nil)
            return
        }
        
        // 方法3：发送标准的新窗口动作
        NSLog("WindowManager: Trying standard newWindow action")
        NSApp.sendAction(Selector(("newWindow:")), to: nil, from: nil)
    }
    
    /// 将窗口带到前台
    private func bringWindowToFront(_ window: NSWindow) {
        DispatchQueue.main.async {
            // 激活应用
            NSApp.activate(ignoringOtherApps: true)
            
            // 显示并聚焦窗口
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            
            NSLog("WindowManager: Window brought to front: \(window.title)")
        }
    }
    
    /// 检查是否是智能提醒窗口
    private func isSmartReminderWindow(_ window: NSWindow) -> Bool {
        return window.title.contains("智能提醒") || 
               window.className.contains("SmartReminder")
    }
    
    /// 检查是否是 AppKit 窗口（SwiftUI WindowGroup 创建的窗口）
    private func isAppKitWindow(_ window: NSWindow) -> Bool {
        return window.className.contains("AppKitWindow")
    }
}

#else
// iOS 版本的空实现
class WindowManager: ObservableObject {
    static let shared = WindowManager()
    
    private init() {}
    
    var hasVisibleMainWindow: Bool { return true }
    
    func showOrCreateMainWindow() {
        // iOS 上不需要实现
    }
}
#endif
