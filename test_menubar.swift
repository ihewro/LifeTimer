#!/usr/bin/swift

import Foundation
import Cocoa

// 简单的测试脚本来验证菜单栏功能
print("🔍 检查菜单栏状态项...")

// 检查是否有状态项在运行
let statusBar = NSStatusBar.system
let statusItems = statusBar.value(forKey: "statusItems") as? [NSStatusItem] ?? []

print("📊 当前状态项数量: \(statusItems.count)")

// 查找我们的计时器状态项
for (index, item) in statusItems.enumerated() {
    if let button = item.button {
        let title = button.title
        let image = button.image?.name() ?? "无图标"
        print("📍 状态项 \(index + 1): 标题='\(title)', 图标=\(image)")
        
        // 检查是否是我们的计时器状态项
        if title.contains(":") || image.contains("timer") {
            print("✅ 找到计时器状态项!")
            print("   - 标题: \(title)")
            print("   - 图标: \(image)")
            print("   - 工具提示: \(button.toolTip ?? "无")")
        }
    }
}

print("✨ 测试完成")
