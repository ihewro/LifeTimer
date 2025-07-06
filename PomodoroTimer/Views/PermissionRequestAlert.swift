//
//  PermissionRequestAlert.swift
//  PomodoroTimer
//
//  Created by Assistant on 2024
//

import SwiftUI
#if canImport(Cocoa)
import Cocoa
#endif

struct PermissionRequestAlert: View {
    @EnvironmentObject var activityMonitor: ActivityMonitorManager
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // 图标
            Image(systemName: "shield.checkered")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            
            // 标题
            Text("需要辅助功能权限")
                .font(.title2)
                .fontWeight(.semibold)
            
            // 说明文字
            VStack(alignment: .leading, spacing: 12) {
                Text("为了提供完整的活动监控功能，应用需要辅助功能权限来：")
                    .font(.body)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                        Text("监控应用切换和使用时间")
                    }
                    
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                        Text("记录浏览器活动和网站访问")
                    }
                    
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                        Text("生成详细的生产力分析报告")
                    }
                }
                .font(.callout)
                .foregroundColor(.secondary)
                .padding(.leading, 8)
            }
            
            // 权限说明
            Text("您的隐私数据将仅在本地存储，不会上传到任何服务器。")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // 按钮组
            HStack(spacing: 12) {
                Button("稍后设置") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                
                Button("打开系统设置") {
                    activityMonitor.openAccessibilitySettings()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                
                Button("检查权限") {
                    activityMonitor.checkPermissions()
                    if activityMonitor.hasPermissions {
                        activityMonitor.handlePermissionGranted()
                        isPresented = false
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .frame(maxWidth: 400)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 10)
    }
}

#if DEBUG
struct PermissionRequestAlert_Previews: PreviewProvider {
    static var previews: some View {
        PermissionRequestAlert(isPresented: .constant(true))
            .environmentObject(ActivityMonitorManager())
    }
}
#endif
