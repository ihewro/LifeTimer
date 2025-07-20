import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

extension Color {
    /// 系统背景色 - 在所有平台上提供一致的背景色体验
    static var systemBackground: Color {
        #if os(macOS)
        // 在 macOS 上使用窗口背景色，更接近 iOS 的 systemBackground
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(.systemBackground)
        #endif
    }

    /// 系统分隔符颜色
    static var systemSeparator: Color {
        #if os(macOS)
        return Color(NSColor.separatorColor)
        #else
        return Color(.separator)
        #endif
    }

    /// 控件背景色 - 用于卡片、面板等
    static var controlBackground: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(.secondarySystemBackground)
        #endif
    }
}
