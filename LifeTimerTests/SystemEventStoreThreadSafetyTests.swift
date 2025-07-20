//
//  SystemEventStoreThreadSafetyTests.swift
//  LifeTimerTests
//
//  Created by Assistant on 2024
//

import XCTest
@testable import LifeTimer

/// 测试 SystemEventStore 的线程安全性，特别是在月视图日期切换时的稳定性
class SystemEventStoreThreadSafetyTests: XCTestCase {
    
    var eventStore: SystemEventStore!
    
    override func setUp() {
        super.setUp()
        eventStore = SystemEventStore.shared
        
        // 清除所有事件，确保测试环境干净
        eventStore.clearAllEvents()
        
        // 添加一些测试数据
        setupTestData()
    }
    
    override func tearDown() {
        // 清理测试数据
        eventStore.clearAllEvents()
        super.tearDown()
    }
    
    /// 设置测试数据
    private func setupTestData() {
        let calendar = Calendar.current
        let today = Date()
        
        // 为过去30天创建测试事件
        for dayOffset in 0..<30 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            
            // 每天创建几个应用激活事件
            let apps = ["Xcode", "Safari", "Terminal", "Finder", "Mail"]
            for (index, appName) in apps.enumerated() {
                let eventTime = calendar.date(byAdding: .hour, value: index, to: date) ?? date
                let event = SystemEvent(
                    type: .appActivated,
                    timestamp: eventTime,
                    appName: appName,
                    data: [:]
                )
                eventStore.saveEvent(event)
            }
        }
        
        // 等待数据保存完成
        Thread.sleep(forTimeInterval: 0.1)
    }
    
    /// 测试并发访问应用统计缓存的线程安全性
    func testConcurrentAppStatsAccess() {
        let expectation = XCTestExpectation(description: "并发访问应用统计缓存")
        let calendar = Calendar.current
        let today = Date()
        
        // 创建多个日期用于测试
        var testDates: [Date] = []
        for dayOffset in 0..<10 {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                testDates.append(date)
            }
        }
        
        let concurrentQueue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let group = DispatchGroup()
        
        // 模拟多个线程同时访问缓存
        for i in 0..<20 {
            group.enter()
            concurrentQueue.async {
                let randomDate = testDates.randomElement() ?? today
                
                // 随机执行不同的操作
                switch i % 4 {
                case 0:
                    // 获取单个日期的应用统计
                    let _ = self.eventStore.getAppUsageStats(for: randomDate)
                case 1:
                    // 批量获取应用统计
                    let _ = self.eventStore.getAppUsageStatsForDates([randomDate])
                case 2:
                    // 获取概览统计
                    let _ = self.eventStore.getOverview(for: randomDate)
                case 3:
                    // 获取事件
                    let _ = self.eventStore.getEvents(for: randomDate)
                default:
                    break
                }
                
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    /// 测试快速日期切换时的稳定性（模拟月视图日期切换）
    func testRapidDateSwitching() {
        let expectation = XCTestExpectation(description: "快速日期切换测试")
        let calendar = Calendar.current
        let today = Date()
        
        // 创建一个月的日期
        var monthDates: [Date] = []
        for dayOffset in 0..<30 {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                monthDates.append(date)
            }
        }
        
        let testQueue = DispatchQueue(label: "test.rapid.switching")
        
        testQueue.async {
            // 模拟用户快速切换日期
            for _ in 0..<100 {
                let randomDate = monthDates.randomElement() ?? today
                
                // 模拟月视图中的数据加载操作
                let _ = self.eventStore.getAppUsageStats(for: randomDate)
                let _ = self.eventStore.getOverview(for: randomDate)
                let _ = self.eventStore.getEvents(for: randomDate)
                
                // 短暂延迟，模拟真实的用户操作
                usleep(1000) // 1ms
            }
            
            DispatchQueue.main.async {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 30.0)
    }
    
    /// 测试批量查询的线程安全性
    func testBatchQueryThreadSafety() {
        let expectation = XCTestExpectation(description: "批量查询线程安全测试")
        let calendar = Calendar.current
        let today = Date()
        
        // 创建多个日期范围
        var dateRanges: [[Date]] = []
        for weekOffset in 0..<4 {
            var weekDates: [Date] = []
            for dayOffset in 0..<7 {
                let totalOffset = weekOffset * 7 + dayOffset
                if let date = calendar.date(byAdding: .day, value: -totalOffset, to: today) {
                    weekDates.append(date)
                }
            }
            dateRanges.append(weekDates)
        }
        
        let concurrentQueue = DispatchQueue(label: "test.batch.concurrent", attributes: .concurrent)
        let group = DispatchGroup()
        
        // 多个线程同时执行批量查询
        for dateRange in dateRanges {
            group.enter()
            concurrentQueue.async {
                // 批量获取事件
                let _ = self.eventStore.getEventsForDates(dateRange)
                
                // 批量获取应用统计
                let _ = self.eventStore.getAppUsageStatsForDates(dateRange)
                
                // 批量获取概览统计
                let _ = self.eventStore.getOverviewForDates(dateRange)
                
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 15.0)
    }
    
    /// 测试缓存清理时的线程安全性
    func testCacheInvalidationThreadSafety() {
        let expectation = XCTestExpectation(description: "缓存清理线程安全测试")
        let calendar = Calendar.current
        let today = Date()
        
        let concurrentQueue = DispatchQueue(label: "test.cache.invalidation", attributes: .concurrent)
        let group = DispatchGroup()
        
        // 同时进行数据访问和缓存清理
        for i in 0..<50 {
            group.enter()
            concurrentQueue.async {
                let randomDate = calendar.date(byAdding: .day, value: -i % 10, to: today) ?? today
                
                if i % 5 == 0 {
                    // 每5次操作清理一次缓存
                    self.eventStore.saveEvent(SystemEvent(
                        type: .appActivated,
                        timestamp: randomDate,
                        appName: "TestApp",
                        data: [:]
                    ))
                } else {
                    // 访问数据
                    let _ = self.eventStore.getAppUsageStats(for: randomDate)
                }
                
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 20.0)
    }
    
    /// 性能测试：验证线程安全修改不会显著影响性能
    func testPerformanceWithThreadSafety() {
        let calendar = Calendar.current
        let today = Date()
        
        // 创建测试日期
        var testDates: [Date] = []
        for dayOffset in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                testDates.append(date)
            }
        }
        
        measure {
            // 测试批量查询性能
            let _ = eventStore.getAppUsageStatsForDates(testDates)
            let _ = eventStore.getEventsForDates(testDates)
            let _ = eventStore.getOverviewForDates(testDates)
        }
    }
}
