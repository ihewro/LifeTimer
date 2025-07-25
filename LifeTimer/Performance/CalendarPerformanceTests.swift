//
//  CalendarPerformanceTests.swift
//  LifeTimer
//
//  Created by Assistant on 2024
//

import Foundation
import SwiftUI

/// 日历性能测试和基准测试工具
class CalendarPerformanceTests {
    
    // MARK: - 性能测试方法
    
    /// 测试事件查询性能
    static func testEventQueryPerformance(eventManager: EventManager, testDates: [Date]) -> (averageTime: TimeInterval, maxTime: TimeInterval) {
        var times: [TimeInterval] = []
        
        for date in testDates {
            let startTime = CFAbsoluteTimeGetCurrent()
            let _ = eventManager.eventsForDate(date)
            let endTime = CFAbsoluteTimeGetCurrent()
            
            times.append(endTime - startTime)
        }
        
        let averageTime = times.reduce(0, +) / Double(times.count)
        let maxTime = times.max() ?? 0
        
        return (averageTime: averageTime, maxTime: maxTime)
    }
    
    /// 测试批量事件查询性能
    static func testBatchEventQueryPerformance(eventManager: EventManager, testDates: [Date]) -> TimeInterval {
        let startTime = CFAbsoluteTimeGetCurrent()
        let _ = eventManager.eventsForDates(testDates)
        let endTime = CFAbsoluteTimeGetCurrent()
        
        return endTime - startTime
    }
    
    /// 测试活动监控查询性能
    static func testActivityQueryPerformance(activityMonitor: ActivityMonitorManager, testDates: [Date]) -> (averageTime: TimeInterval, maxTime: TimeInterval) {
        var times: [TimeInterval] = []
        
        for date in testDates {
            let startTime = CFAbsoluteTimeGetCurrent()
            let _ = activityMonitor.getOverview(for: date)
            let _ = activityMonitor.getAppUsageStats(for: date)
            let endTime = CFAbsoluteTimeGetCurrent()
            
            times.append(endTime - startTime)
        }
        
        let averageTime = times.reduce(0, +) / Double(times.count)
        let maxTime = times.max() ?? 0
        
        return (averageTime: averageTime, maxTime: maxTime)
    }
    
    /// 测试批量活动监控查询性能
    static func testBatchActivityQueryPerformance(activityMonitor: ActivityMonitorManager, testDates: [Date]) -> TimeInterval {
        let startTime = CFAbsoluteTimeGetCurrent()
        let _ = activityMonitor.getOverviewForDates(testDates)
        let _ = activityMonitor.getAppUsageStatsForDates(testDates)
        let endTime = CFAbsoluteTimeGetCurrent()
        
        return endTime - startTime
    }
    
    // MARK: - 性能基准测试
    
    /// 运行完整的性能基准测试
    static func runPerformanceBenchmark(eventManager: EventManager, activityMonitor: ActivityMonitorManager) -> PerformanceBenchmarkResult {
        print("🚀 开始日历性能基准测试...")
        
        // 生成测试数据
        let testDates = generateTestDates()
        
        // 测试单个查询性能
        let eventQueryResult = testEventQueryPerformance(eventManager: eventManager, testDates: testDates)
        let activityQueryResult = testActivityQueryPerformance(activityMonitor: activityMonitor, testDates: testDates)
        
        // 测试批量查询性能
        let batchEventQueryTime = testBatchEventQueryPerformance(eventManager: eventManager, testDates: testDates)
        let batchActivityQueryTime = testBatchActivityQueryPerformance(activityMonitor: activityMonitor, testDates: testDates)
        
        // 计算性能改进
        let eventQueryImprovement = calculatePerformanceImprovement(
            singleQueryTime: eventQueryResult.averageTime * Double(testDates.count),
            batchQueryTime: batchEventQueryTime
        )
        
        let activityQueryImprovement = calculatePerformanceImprovement(
            singleQueryTime: activityQueryResult.averageTime * Double(testDates.count),
            batchQueryTime: batchActivityQueryTime
        )
        
        let result = PerformanceBenchmarkResult(
            eventQueryAverage: eventQueryResult.averageTime,
            eventQueryMax: eventQueryResult.maxTime,
            activityQueryAverage: activityQueryResult.averageTime,
            activityQueryMax: activityQueryResult.maxTime,
            batchEventQueryTime: batchEventQueryTime,
            batchActivityQueryTime: batchActivityQueryTime,
            eventQueryImprovement: eventQueryImprovement,
            activityQueryImprovement: activityQueryImprovement,
            testDatesCount: testDates.count
        )
        
        printBenchmarkResults(result)
        return result
    }
    
    // MARK: - 辅助方法
    
    /// 生成测试日期
    private static func generateTestDates() -> [Date] {
        let calendar = Calendar.current
        let today = Date()
        var dates: [Date] = []
        
        // 生成过去30天的日期
        for i in 0..<30 {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                dates.append(date)
            }
        }
        
        return dates
    }
    
    /// 计算性能改进百分比
    private static func calculatePerformanceImprovement(singleQueryTime: TimeInterval, batchQueryTime: TimeInterval) -> Double {
        guard singleQueryTime > 0 else { return 0 }
        return ((singleQueryTime - batchQueryTime) / singleQueryTime) * 100
    }
    
    /// 打印基准测试结果
    private static func printBenchmarkResults(_ result: PerformanceBenchmarkResult) {
        print("\n📊 日历性能基准测试结果")
        print("=" * 50)
        print("测试日期数量: \(result.testDatesCount)")
        print("\n🔍 事件查询性能:")
        print("  单次查询平均时间: \(String(format: "%.3f", result.eventQueryAverage * 1000))ms")
        print("  单次查询最大时间: \(String(format: "%.3f", result.eventQueryMax * 1000))ms")
        print("  批量查询总时间: \(String(format: "%.3f", result.batchEventQueryTime * 1000))ms")
        print("  性能改进: \(String(format: "%.1f", result.eventQueryImprovement))%")
        
        print("\n📱 活动监控查询性能:")
        print("  单次查询平均时间: \(String(format: "%.3f", result.activityQueryAverage * 1000))ms")
        print("  单次查询最大时间: \(String(format: "%.3f", result.activityQueryMax * 1000))ms")
        print("  批量查询总时间: \(String(format: "%.3f", result.batchActivityQueryTime * 1000))ms")
        print("  性能改进: \(String(format: "%.1f", result.activityQueryImprovement))%")
        
        print("\n✅ 基准测试完成!")
        
        // 性能评估
        evaluatePerformance(result)
    }
    
    /// 评估性能表现
    private static func evaluatePerformance(_ result: PerformanceBenchmarkResult) {
        print("\n🎯 性能评估:")
        
        // 事件查询性能评估
        if result.eventQueryAverage < 0.001 { // < 1ms
            print("  ✅ 事件查询性能: 优秀")
        } else if result.eventQueryAverage < 0.005 { // < 5ms
            print("  ⚠️ 事件查询性能: 良好")
        } else {
            print("  ❌ 事件查询性能: 需要优化")
        }
        
        // 批量查询改进评估
        if result.eventQueryImprovement > 50 {
            print("  ✅ 批量查询优化: 显著改进")
        } else if result.eventQueryImprovement > 20 {
            print("  ⚠️ 批量查询优化: 有所改进")
        } else {
            print("  ❌ 批量查询优化: 改进有限")
        }
    }
}

// MARK: - 性能测试结果结构

/// 性能基准测试结果
struct PerformanceBenchmarkResult {
    let eventQueryAverage: TimeInterval
    let eventQueryMax: TimeInterval
    let activityQueryAverage: TimeInterval
    let activityQueryMax: TimeInterval
    let batchEventQueryTime: TimeInterval
    let batchActivityQueryTime: TimeInterval
    let eventQueryImprovement: Double
    let activityQueryImprovement: Double
    let testDatesCount: Int
}

// MARK: - 字符串扩展

extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}
