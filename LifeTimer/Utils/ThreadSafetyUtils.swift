//
//  ThreadSafetyUtils.swift
//  LifeTimer
//
//  Created by Assistant on 2025-08-01.
//

import Foundation
import SwiftUI

/// 线程安全工具类，用于防止崩溃和内存访问错误
class ThreadSafetyUtils {
    
    /// 安全地在主线程执行UI更新
    static func safeMainThreadExecution(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async {
                block()
            }
        }
    }
    
    /// 安全地在主线程执行UI更新（带弱引用检查）
    static func safeMainThreadExecution<T: AnyObject>(
        weakObject: T?,
        _ block: @escaping (T) -> Void
    ) {
        guard let object = weakObject else { return }
        
        if Thread.isMainThread {
            block(object)
        } else {
            DispatchQueue.main.async { [weak object] in
                guard let object = object else { return }
                block(object)
            }
        }
    }
    
    /// 安全地取消并清理Task
    static func safeCancelTask(_ task: inout Task<Void, Never>?) {
        task?.cancel()
        task = nil
    }
    
    /// 安全地取消并清理Timer
    static func safeCancelTimer(_ timer: inout Timer?) {
        timer?.invalidate()
        timer = nil
    }
    
    /// 创建防抖的异步任务
    static func createDebouncedTask(
        delay: UInt64 = 300_000_000, // 默认300ms
        operation: @escaping () async -> Void
    ) -> Task<Void, Never> {
        return Task {
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            await operation()
        }
    }
    
    /// 安全地执行带错误处理的异步操作
    static func safeAsyncOperation(
        operation: @escaping () async throws -> Void,
        errorHandler: @escaping (Error) -> Void = { error in
            print("❌ 异步操作错误: \(error)")
        }
    ) -> Task<Void, Never> {
        return Task {
            do {
                try await operation()
            } catch {
                await MainActor.run {
                    errorHandler(error)
                }
            }
        }
    }
}

/// 线程安全的属性包装器
@propertyWrapper
struct ThreadSafe<T> {
    private var value: T
    private let lock = NSLock()
    
    init(wrappedValue: T) {
        self.value = wrappedValue
    }
    
    var wrappedValue: T {
        get {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            value = newValue
        }
    }
    
    /// 线程安全的修改操作
    mutating func modify<Result>(_ operation: (inout T) -> Result) -> Result {
        lock.lock()
        defer { lock.unlock() }
        return operation(&value)
    }
}

/// 线程安全的缓存管理器
class ThreadSafeCache<Key: Hashable, Value> {
    private var cache: [Key: Value] = [:]
    private let lock = NSLock()
    
    func get(_ key: Key) -> Value? {
        lock.lock()
        defer { lock.unlock() }
        return cache[key]
    }
    
    func set(_ key: Key, value: Value) {
        lock.lock()
        defer { lock.unlock() }
        cache[key] = value
    }
    
    func remove(_ key: Key) {
        lock.lock()
        defer { lock.unlock() }
        cache.removeValue(forKey: key)
    }
    
    func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAll()
    }
    
    func keys() -> [Key] {
        lock.lock()
        defer { lock.unlock() }
        return Array(cache.keys)
    }
    
    func count() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return cache.count
    }
}

/// 安全的定时器管理器
class SafeTimerManager {
    private var timers: Set<Timer> = []
    private let lock = NSLock()
    
    func createTimer(
        timeInterval: TimeInterval,
        repeats: Bool,
        block: @escaping (Timer) -> Void
    ) -> Timer {
        let timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: repeats) { [weak self] timer in
            block(timer)
            
            // 如果是非重复定时器，自动清理
            if !repeats {
                self?.removeTimer(timer)
            }
        }
        
        lock.lock()
        timers.insert(timer)
        lock.unlock()
        
        return timer
    }
    
    func removeTimer(_ timer: Timer) {
        lock.lock()
        defer { lock.unlock() }
        
        timer.invalidate()
        timers.remove(timer)
    }
    
    func removeAllTimers() {
        lock.lock()
        defer { lock.unlock() }
        
        for timer in timers {
            timer.invalidate()
        }
        timers.removeAll()
    }
    
    deinit {
        removeAllTimers()
    }
}

/// SwiftUI视图的线程安全扩展
extension View {
    /// 安全地执行异步操作
    func safeTask(
        priority: TaskPriority = .userInitiated,
        operation: @escaping () async -> Void
    ) -> some View {
        self.task(priority: priority) {
            await ThreadSafetyUtils.safeAsyncOperation(operation: operation).value
        }
    }
    
    /// 安全地处理onChange事件
    func safeOnChange<V: Equatable>(
        of value: V,
        debounceTime: UInt64 = 100_000_000, // 默认100ms
        perform action: @escaping (V) -> Void
    ) -> some View {
        self.onChange(of: value) { newValue in
            Task {
                try? await Task.sleep(nanoseconds: debounceTime)
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    action(newValue)
                }
            }
        }
    }
}
