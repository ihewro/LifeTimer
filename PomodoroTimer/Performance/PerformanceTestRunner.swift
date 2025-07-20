//
//  PerformanceTestRunner.swift
//  PomodoroTimer
//
//  Created by Assistant on 2024
//

import Foundation
import SwiftUI

/// 简单的性能测试运行器，用于验证优化效果
class PerformanceTestRunner {
    
    /// 运行基本的性能测试
    static func runBasicPerformanceTest(eventManager: EventManager, activityMonitor: ActivityMonitorManager) {
        print("🚀 开始基本性能测试...")
        
        // 生成测试日期
        let calendar = Calendar.current
        let today = Date()
        var testDates: [Date] = []
        
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                testDates.append(date)
            }
        }
        
        // 测试单个查询性能
        print("📊 测试单个事件查询性能...")
        let singleQueryStart = CFAbsoluteTimeGetCurrent()
        for date in testDates {
            let _ = eventManager.eventsForDate(date)
        }
        let singleQueryTime = CFAbsoluteTimeGetCurrent() - singleQueryStart
        
        // 测试批量查询性能
        print("📊 测试批量事件查询性能...")
        let batchQueryStart = CFAbsoluteTimeGetCurrent()
        let _ = eventManager.eventsForDates(testDates)
        let batchQueryTime = CFAbsoluteTimeGetCurrent() - batchQueryStart
        
        // 计算性能改进
        let improvement = singleQueryTime > 0 ? ((singleQueryTime - batchQueryTime) / singleQueryTime) * 100 : 0
        
        // 输出结果
        print("\n📈 性能测试结果:")
        print("  测试日期数量: \(testDates.count)")
        print("  单个查询总时间: \(String(format: "%.3f", singleQueryTime * 1000))ms")
        print("  批量查询总时间: \(String(format: "%.3f", batchQueryTime * 1000))ms")
        print("  性能改进: \(String(format: "%.1f", improvement))%")
        
        // 性能评估
        if improvement > 30 {
            print("  ✅ 批量查询优化: 显著改进")
        } else if improvement > 10 {
            print("  ⚠️ 批量查询优化: 有所改进")
        } else {
            print("  ❌ 批量查询优化: 改进有限")
        }
        
        print("✅ 基本性能测试完成!\n")
    }
    
    /// 测试缓存效果
    static func testCacheEffectiveness(eventManager: EventManager) {
        print("🔍 测试缓存效果...")
        
        let testDate = Date()
        
        // 第一次查询（缓存未命中）
        let firstQueryStart = CFAbsoluteTimeGetCurrent()
        let _ = eventManager.eventsForDate(testDate)
        let firstQueryTime = CFAbsoluteTimeGetCurrent() - firstQueryStart
        
        // 第二次查询（缓存命中）
        let secondQueryStart = CFAbsoluteTimeGetCurrent()
        let _ = eventManager.eventsForDate(testDate)
        let secondQueryTime = CFAbsoluteTimeGetCurrent() - secondQueryStart
        
        let cacheImprovement = firstQueryTime > 0 ? ((firstQueryTime - secondQueryTime) / firstQueryTime) * 100 : 0
        
        print("  第一次查询时间: \(String(format: "%.3f", firstQueryTime * 1000))ms")
        print("  第二次查询时间: \(String(format: "%.3f", secondQueryTime * 1000))ms")
        print("  缓存改进: \(String(format: "%.1f", cacheImprovement))%")
        
        if cacheImprovement > 50 {
            print("  ✅ 缓存效果: 优秀")
        } else if cacheImprovement > 20 {
            print("  ⚠️ 缓存效果: 良好")
        } else {
            print("  ❌ 缓存效果: 需要改进")
        }
        
        print("✅ 缓存测试完成!\n")
    }
}

/// SwiftUI 视图扩展，用于在应用中运行性能测试
extension View {
    /// 添加性能测试功能
    func withPerformanceTesting(eventManager: EventManager, activityMonitor: ActivityMonitorManager) -> some View {
        self.onAppear {
            // 延迟执行测试，避免影响应用启动
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                #if DEBUG
                PerformanceTestRunner.runBasicPerformanceTest(
                    eventManager: eventManager,
                    activityMonitor: activityMonitor
                )
                PerformanceTestRunner.testCacheEffectiveness(eventManager: eventManager)
                #endif
            }
        }
    }
}
