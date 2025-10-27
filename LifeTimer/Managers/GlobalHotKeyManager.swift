//
//  GlobalHotKeyManager.swift
//  LifeTimer
//
//  Created by Developer on 2025.
//

import SwiftUI
#if canImport(Cocoa)
import Cocoa
import Carbon
#endif

/// 全局快捷键管理器（macOS）
#if os(macOS)
class GlobalHotKeyManager: NSObject {
    static let shared = GlobalHotKeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var hotKeyID = EventHotKeyID(signature: OSType(UInt32(0x4C544B48)), id: 1) // "LTKH"

    private let enabledKey = "GlobalHotKeyEnabled"
    private let modifierKey = "GlobalHotKeyModifier" // control | option | command

    /// 应用当前设置（在应用启动时调用）
    func applyCurrentSettings() {
        let defaults = UserDefaults.standard
        let enabled = defaults.object(forKey: enabledKey) as? Bool ?? true
        let modifier = defaults.string(forKey: modifierKey) ?? "control"
        registerHotKey(enabled: enabled, modifier: modifier)
    }

    /// 更新注册（设置变更时调用）
    func registerHotKey(enabled: Bool, modifier: String) {
        unregisterHotKey()

        guard enabled else { return }

        let flags = carbonFlags(for: modifier)
        let keyCode = UInt32(kVK_Space)

        var status: OSStatus = noErr

        // 安装事件处理器
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        status = InstallEventHandler(GetApplicationEventTarget(), { (_, eventRef, _) -> OSStatus in
            var hkID = EventHotKeyID()
            GetEventParameter(eventRef, UInt32(kEventParamDirectObject), UInt32(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            if hkID.id == 1 && hkID.signature == OSType(UInt32(0x4C544B48)) { // "LTKH"
                NotificationCenter.default.post(name: Notification.Name("LTGlobalHotKeyShowPopover"), object: nil)
            }
            return noErr
        }, 1, &eventSpec, nil, &eventHandlerRef)

        if status != noErr {
            NSLog("GlobalHotKeyManager: Failed to install event handler")
        }

        // 注册热键
        status = RegisterEventHotKey(keyCode, flags, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status == noErr {
            NSLog("GlobalHotKeyManager: Registered global hotkey (modifier=\(modifier))")
        } else {
            NSLog("GlobalHotKeyManager: Failed to register hotkey, status=\(status)")
        }
    }

    /// 取消注册
    func unregisterHotKey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        // 事件处理器让系统管理，无需显式移除
    }

    private func carbonFlags(for modifier: String) -> UInt32 {
        switch modifier {
        case "control":
            return UInt32(controlKey)
        case "option":
            return UInt32(optionKey)
        case "command":
            return UInt32(cmdKey)
        default:
            return UInt32(controlKey)
        }
    }
}
#else
class GlobalHotKeyManager {
    static let shared = GlobalHotKeyManager()
    func applyCurrentSettings() {}
    func registerHotKey(enabled: Bool, modifier: String) {}
}
#endif