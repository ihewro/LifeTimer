//
//  PermissionRequestAlert.swift
//  LifeTimer
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
        VStack(alignment: .leading, spacing: 24) {
            // 图标
            HStack {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)
                    .padding(.bottom, 8)
                Spacer()
            }

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
            Text("您的隐私数据由你自己控制是否同步。")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
            
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

                Button("不再提醒") {
                    activityMonitor.disablePermissionReminder()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.secondary)

                Spacer()
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.systemBackground)
        .navigationTitle("需要辅助功能权限")
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
