//
//  AppIconManager.swift
//  LifeTimer
//
//  Created by Developer on 2025.
//

import SwiftUI
#if canImport(Cocoa)
import Cocoa
#endif

class AppIconManager: ObservableObject {
    static let shared = AppIconManager()
    
    @Published var currentIconPath: String = ""
    
    private let userDefaults = UserDefaults.standard
    private let currentIconPathKey = "CurrentAppIconPath"
    
    init() {
        loadCurrentIconPath()
    }
    
    /// 选择新的应用图标
    func selectIcon() {
        #if canImport(Cocoa)
        let panel = NSOpenPanel()
        panel.title = "选择应用图标"
        panel.message = "选择一个图片文件作为应用图标"
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .bmp]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                setIcon(from: url.path)
            }
        }
        #endif
    }
    
    /// 设置应用图标
    func setIcon(from imagePath: String) {
        #if canImport(Cocoa)
        guard let image = NSImage(contentsOfFile: imagePath) else {
            print("无法加载图片: \(imagePath)")
            return
        }
        
        // 调整图片大小为合适的应用图标尺寸
        let iconSize = NSSize(width: 512, height: 512)
        let resizedImage = resizeImage(image, to: iconSize)
        
        // 设置应用图标
        NSApplication.shared.applicationIconImage = resizedImage
        
        // 保存当前图标路径
        currentIconPath = imagePath
        saveCurrentIconPath()
        
        print("应用图标已更新: \(imagePath)")
        #endif
    }
    
    /// 重置为默认图标
    func resetToDefault() {
        #if canImport(Cocoa)
            // 如果默认图标不存在，使用应用包中的图标
            NSApplication.shared.applicationIconImage = nil
            currentIconPath = ""
            saveCurrentIconPath()
        #endif
    }
    
    /// 调整图片大小
    private func resizeImage(_ image: NSImage, to size: NSSize) -> NSImage {
        #if canImport(Cocoa)
        let resizedImage = NSImage(size: size)
        resizedImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size))
        resizedImage.unlockFocus()
        return resizedImage
        #else
        return image
        #endif
    }
    
    /// 保存当前图标路径
    private func saveCurrentIconPath() {
        userDefaults.set(currentIconPath, forKey: currentIconPathKey)
    }
    
    /// 加载当前图标路径
    private func loadCurrentIconPath() {
        currentIconPath = userDefaults.string(forKey: currentIconPathKey) ?? ""
        
        // 如果有保存的图标路径，在应用启动时恢复
        if !currentIconPath.isEmpty && FileManager.default.fileExists(atPath: currentIconPath) {
            setIcon(from: currentIconPath)
        } else if currentIconPath.isEmpty {
            // 如果没有设置过自定义图标，使用默认图标
            resetToDefault()
        }
    }
}
