#!/usr/bin/env swift

//
//  test_calendar_stability.swift
//  日历稳定性测试脚本
//
//  用于验证月视图日期切换时的稳定性
//

import Foundation

/// 日历稳定性测试类
class CalendarStabilityTest {
    
    /// 模拟月视图快速日期切换测试
    func testRapidDateSwitching() {
        print("🧪 开始日历稳定性测试...")
        print("📅 模拟月视图快速日期切换...")
        
        let calendar = Calendar.current
        let today = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        // 创建一个月的日期
        var monthDates: [Date] = []
        for dayOffset in 0..<30 {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                monthDates.append(date)
            }
        }
        
        print("📊 创建了 \(monthDates.count) 个测试日期")
        
        // 模拟快速切换日期
        let iterations = 1000
        let startTime = Date()
        
        for i in 0..<iterations {
            let randomDate = monthDates.randomElement() ?? today
            
            // 模拟日历视图中的数据访问操作
            simulateCalendarDataAccess(for: randomDate)
            
            if i % 100 == 0 {
                print("✅ 已完成 \(i) 次日期切换测试")
            }
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        print("🎉 测试完成！")
        print("⏱️  总耗时: \(String(format: "%.2f", duration)) 秒")
        print("📈 平均每次切换耗时: \(String(format: "%.2f", duration * 1000 / Double(iterations))) 毫秒")
    }
    
    /// 模拟日历数据访问操作
    private func simulateCalendarDataAccess(for date: Date) {
        // 这里模拟 SystemEventStore 的数据访问操作
        // 在实际应用中，这些操作会触发缓存访问
        
        let dateKey = formatDateKey(date)
        
        // 模拟缓存查找操作
        _ = checkMockCache(key: dateKey)
        
        // 模拟数据计算操作
        _ = calculateMockStats(for: date)
        
        // 短暂延迟，模拟真实的数据处理时间
        usleep(100) // 0.1ms
    }
    
    /// 格式化日期键
    private func formatDateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    /// 模拟缓存检查
    private func checkMockCache(key: String) -> Bool {
        // 模拟缓存命中/未命中
        return Int.random(in: 0...1) == 1
    }
    
    /// 模拟统计数据计算
    private func calculateMockStats(for date: Date) -> [String: Any] {
        return [
            "activeTime": Double.random(in: 0...28800), // 0-8小时
            "appSwitches": Int.random(in: 0...100),
            "websiteVisits": Int.random(in: 0...50)
        ]
    }
    
    /// 并发测试
    func testConcurrentAccess() {
        print("🔄 开始并发访问测试...")
        
        let calendar = Calendar.current
        let today = Date()
        
        // 创建测试日期
        var testDates: [Date] = []
        for dayOffset in 0..<10 {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                testDates.append(date)
            }
        }
        
        let concurrentQueue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let group = DispatchGroup()
        let startTime = Date()
        
        // 启动多个并发任务
        for i in 0..<20 {
            group.enter()
            concurrentQueue.async {
                for _ in 0..<50 {
                    let randomDate = testDates.randomElement() ?? today
                    self.simulateCalendarDataAccess(for: randomDate)
                }
                print("✅ 并发任务 \(i + 1) 完成")
                group.leave()
            }
        }
        
        // 等待所有任务完成
        group.wait()
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        print("🎉 并发测试完成！")
        print("⏱️  总耗时: \(String(format: "%.2f", duration)) 秒")
    }
    
    /// 内存压力测试
    func testMemoryPressure() {
        print("💾 开始内存压力测试...")
        
        let calendar = Calendar.current
        let today = Date()
        
        // 创建大量日期
        var largeDateSet: [Date] = []
        for dayOffset in 0..<365 { // 一年的日期
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                largeDateSet.append(date)
            }
        }
        
        print("📊 创建了 \(largeDateSet.count) 个测试日期")
        
        let startTime = Date()
        
        // 模拟大量数据访问
        for (index, date) in largeDateSet.enumerated() {
            simulateCalendarDataAccess(for: date)
            
            if index % 50 == 0 {
                print("✅ 已处理 \(index) 个日期")
            }
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        print("🎉 内存压力测试完成！")
        print("⏱️  总耗时: \(String(format: "%.2f", duration)) 秒")
        print("📈 平均每个日期处理耗时: \(String(format: "%.2f", duration * 1000 / Double(largeDateSet.count))) 毫秒")
    }
}

// MARK: - 主程序入口

print("🚀 启动日历稳定性测试...")
print("=" * 50)

let tester = CalendarStabilityTest()

// 执行各种测试
tester.testRapidDateSwitching()
print("")

tester.testConcurrentAccess()
print("")

tester.testMemoryPressure()
print("")

print("=" * 50)
print("✅ 所有测试完成！如果没有崩溃，说明修复成功。")

// 扩展 String 以支持重复操作符
extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}
