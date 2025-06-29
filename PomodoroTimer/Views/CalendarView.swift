//
//  CalendarView.swift
//  PomodoroTimer
//
//  Created by Developer on 2024.
//

import SwiftUI
import Foundation

struct CalendarView: View {
    @EnvironmentObject var eventManager: EventManager
    @State private var selectedDate = Date()
    @State private var showingAddEvent = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 日期选择器
                DatePicker(
                    "选择日期",
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.compact)
                .padding()
                
                Divider()
                
                // 时间轴视图
                TimelineView(selectedDate: selectedDate)
                    .environmentObject(eventManager)
            }
            .navigationTitle("日历")
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddEvent = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button(action: {
                        showingAddEvent = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
                #endif
            }
        }
        .sheet(isPresented: $showingAddEvent) {
            AddEventView(selectedDate: selectedDate)
                .environmentObject(eventManager)
        }
    }
}
    

struct TimelineView: View {
    let selectedDate: Date
    @EnvironmentObject var eventManager: EventManager
    
    private let hours = Array(0...23)
    private let hourHeight: CGFloat = 60
    
    @State private var selectionStart: CGFloat? = nil
    @State private var selectionEnd: CGFloat? = nil
    @State private var showingQuickAdd = false
    @State private var quickAddStartTime = Date()
    @State private var quickAddEndTime = Date()
    
    var eventsForSelectedDate: [PomodoroEvent] {
        eventManager.eventsForDate(selectedDate)
    }
    
    // 计算选择区域对应的时间
    private func calculateTimeFromOffset(_ offset: CGFloat) -> Date {
        let hours = Int(offset / hourHeight)
        let minutes = Int((offset.truncatingRemainder(dividingBy: hourHeight)) / hourHeight * 60)
        
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        components.hour = hours
        components.minute = minutes
        
        return calendar.date(from: components) ?? selectedDate
    }
    
    var body: some View {
        ScrollView {
            ZStack(alignment: .topLeading) {
                // 时间轴背景
                VStack(spacing: 0) {
                    ForEach(hours, id: \.self) { hour in
                        HStack {
                            // 小时标签
                            Text("\(hour)时")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 50, alignment: .trailing)
                            
                            // 时间线
                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(height: 1)
                            
                            Spacer()
                        }
                        .frame(height: hourHeight)
                    }
                }
                
                // 选择区域
                if let start = selectionStart, let end = selectionEnd {
                    let minY = min(start, end)
                    let maxY = max(start, end)
                    let height = maxY - minY
                    
                    Rectangle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(height: height)
                        .frame(maxWidth: .infinity)
                        .offset(y: minY)
                }
                
                // 事件块
                ForEach(eventsForSelectedDate) { event in
                    EventBlockView(event: event, hourHeight: hourHeight)
                        .environmentObject(eventManager)
                }
                
                // 当前时间指示器（仅当选择今天时显示）
                if Calendar.current.isDateInToday(selectedDate) {
                    CurrentTimeIndicator(hourHeight: hourHeight)
                }
            }
            .padding(.leading, 60)
            .padding(.trailing, 16)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { value in
                        let location = value.location.y
                        
                        if selectionStart == nil {
                            selectionStart = location
                        }
                        selectionEnd = location
                    }
                    .onEnded { value in
                        if let start = selectionStart, let end = selectionEnd, abs(end - start) > 10 {
                            // 计算选择区域对应的时间
                            let minY = min(start, end)
                            let maxY = max(start, end)
                            
                            quickAddStartTime = calculateTimeFromOffset(minY)
                            quickAddEndTime = calculateTimeFromOffset(maxY)
                            
                            // 显示快速添加事件视图
                            showingQuickAdd = true
                        }
                        
                        // 重置选择区域
                        selectionStart = nil
                        selectionEnd = nil
                    }
            )
            .sheet(isPresented: $showingQuickAdd) {
                QuickAddEventView(
                    selectedDate: selectedDate,
                    startTime: quickAddStartTime,
                    endTime: quickAddEndTime
                )
                .environmentObject(eventManager)
            }
        }
    }
}

// 计算事件在时间轴上的位置
func calculateEventPosition(event: PomodoroEvent, hourHeight: CGFloat) -> (offset: CGFloat, height: CGFloat) {
    let calendar = Calendar.current
    let startHour = calendar.component(.hour, from: event.startTime)
    let startMinute = calendar.component(.minute, from: event.startTime)
    
    let startOffset = CGFloat(startHour) * hourHeight + CGFloat(startMinute) * hourHeight / 60
    let eventHeight = CGFloat(event.duration / 3600) * hourHeight
    
    return (startOffset, max(eventHeight, 20)) // 最小高度20
}

struct EventBlockView: View {
    let event: PomodoroEvent
    let hourHeight: CGFloat
    @EnvironmentObject var eventManager: EventManager
    @State private var showingEventDetail = false
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    private var eventPosition: (offset: CGFloat, height: CGFloat) {
        return calculateEventPosition(event: event, hourHeight: hourHeight)
    }
    
    // 计算拖拽时的新时间
    private func calculateNewTime() -> (start: Date, end: Date) {
        let timeChange = Double(dragOffset) / Double(hourHeight) * 3600 // 转换为秒
        let newStartTime = event.startTime.addingTimeInterval(timeChange)
        let newEndTime = event.endTime.addingTimeInterval(timeChange)
        return (newStartTime, newEndTime)
    }
    
    // 格式化时间为字符串
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var body: some View {
        let newTimes = isDragging ? calculateNewTime() : (event.startTime, event.endTime)
        
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: event.type.icon)
                    .font(.caption)
                Text(event.title)
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                if event.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            Text(isDragging ? "\(formatTime(newTimes.0)) - \(formatTime(newTimes.1))" : event.formattedTimeRange)
                .font(.caption2)
                .opacity(0.8)
            
            if eventPosition.height > 40 {
                Text(event.formattedDuration)
                    .font(.caption2)
                    .opacity(0.6)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: eventPosition.height)
        .background(event.type.color.opacity(isDragging ? 0.4 : 0.2))
        .overlay(
            Rectangle()
                .fill(event.type.color)
                .frame(width: 3),
            alignment: .leading
        )
        .cornerRadius(6)
        .scaleEffect(isDragging ? 1.05 : 1.0)
        .opacity(isDragging ? 0.8 : 1.0)
        .shadow(color: isDragging ? .black.opacity(0.3) : .clear, radius: isDragging ? 8 : 0, x: 0, y: isDragging ? 4 : 0)
        .animation(.easeInOut(duration: 0.2), value: isDragging)
        .animation(.easeInOut(duration: 0.2), value: dragOffset)
        .offset(y: eventPosition.offset + dragOffset)
        .onTapGesture {
            if !isDragging {
                showingEventDetail = true
            }
        }
        .gesture(
            DragGesture(minimumDistance: 5)
                .onChanged { value in
                    isDragging = true
                    // 添加时间吸附功能，每15分钟为一个单位
                    let snapInterval: CGFloat = hourHeight / 4 // 15分钟
                    let snappedOffset = round(value.translation.height / snapInterval) * snapInterval
                    dragOffset = snappedOffset
                }
                .onEnded { value in
                    isDragging = false
                    
                    // 计算新的时间（基于吸附后的位置）
                    let timeChange = Double(dragOffset) / Double(hourHeight) * 3600 // 转换为秒
                    let newStartTime = event.startTime.addingTimeInterval(timeChange)
                    let newEndTime = event.endTime.addingTimeInterval(timeChange)
                    
                    // 确保时间在合理范围内（当天）
                    let calendar = Calendar.current
                    let startOfDay = calendar.startOfDay(for: event.startTime)
                    let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
                    
                    if newStartTime >= startOfDay && newEndTime < endOfDay {
                        // 更新事件时间
                        var updatedEvent = event
                        updatedEvent.startTime = newStartTime
                        updatedEvent.endTime = newEndTime
                        eventManager.updateEvent(updatedEvent)
                        
                        #if os(iOS)
                        // 添加触觉反馈
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        #endif
                    }
                    
                    dragOffset = 0
                }
        )
        .sheet(isPresented: $showingEventDetail) {
            EventDetailView(event: event)
                .environmentObject(eventManager)
        }
    }
}

struct CurrentTimeIndicator: View {
    let hourHeight: CGFloat
    
    private var currentTimeOffset: CGFloat {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        
        return CGFloat(hour) * hourHeight + CGFloat(minute) * hourHeight / 60
    }
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
            
            Rectangle()
                .fill(Color.red)
                .frame(height: 2)
        }
        .offset(y: currentTimeOffset)
    }
}

// MARK: - 添加事件视图
struct AddEventView: View {
    let selectedDate: Date
    @EnvironmentObject var eventManager: EventManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var startTime = Date()
    @State private var endTime = Date()
    @State private var eventType: PomodoroEvent.EventType = .pomodoro
    
    var body: some View {
        NavigationView {
            Form {
                Section("事件信息") {
                    TextField("事件标题", text: $title)
                    
                    DatePicker("开始时间", selection: $startTime, displayedComponents: [.hourAndMinute])
                    DatePicker("结束时间", selection: $endTime, displayedComponents: [.hourAndMinute])
                    
                    Picker("事件类型", selection: $eventType) {
                        ForEach(PomodoroEvent.EventType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
            .navigationTitle("添加事件")
            .toolbar {
                 ToolbarItem(placement: .cancellationAction) {
                     Button("取消") {
                         dismiss()
                     }
                 }
                 
                 ToolbarItem(placement: .confirmationAction) {
                     Button("保存") {
                         saveEvent()
                     }
                     .disabled(title.isEmpty)
                 }
             }
        }
        .onAppear {
            setupInitialTimes()
        }
    }
    
    private func setupInitialTimes() {
        let calendar = Calendar.current
        let now = Date()
        
        // 设置为选择日期的当前小时
        var components = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        let currentHour = calendar.component(.hour, from: now)
        components.hour = currentHour
        components.minute = 0
        
        if let start = calendar.date(from: components) {
            startTime = start
            endTime = calendar.date(byAdding: .hour, value: 1, to: start) ?? start
        }
    }
    
    private func saveEvent() {
        let calendar = Calendar.current
        
        // 确保开始和结束时间在选择的日期
        var startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        var endComponents = calendar.dateComponents([.hour, .minute], from: endTime)
        
        let baseDateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        
        startComponents.year = baseDateComponents.year
        startComponents.month = baseDateComponents.month
        startComponents.day = baseDateComponents.day
        
        endComponents.year = baseDateComponents.year
        endComponents.month = baseDateComponents.month
        endComponents.day = baseDateComponents.day
        
        guard let finalStartTime = calendar.date(from: startComponents),
              let finalEndTime = calendar.date(from: endComponents) else {
            return
        }
        
        let event = PomodoroEvent(
            title: title,
            startTime: finalStartTime,
            endTime: finalEndTime,
            type: eventType
        )
        
        eventManager.addEvent(event)
        dismiss()
    }
}

// MARK: - 快速添加事件视图
struct QuickAddEventView: View {
    let selectedDate: Date
    let startTime: Date
    let endTime: Date
    @EnvironmentObject var eventManager: EventManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var adjustedStartTime: Date
    @State private var adjustedEndTime: Date
    @State private var eventType: PomodoroEvent.EventType = .pomodoro
    
    init(selectedDate: Date, startTime: Date, endTime: Date) {
        self.selectedDate = selectedDate
        self.startTime = startTime
        self.endTime = endTime
        self._adjustedStartTime = State(initialValue: startTime)
        self._adjustedEndTime = State(initialValue: endTime)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("事件信息") {
                    TextField("事件标题", text: $title)
                    
                    DatePicker("开始时间", selection: $adjustedStartTime, displayedComponents: [.hourAndMinute])
                    DatePicker("结束时间", selection: $adjustedEndTime, displayedComponents: [.hourAndMinute])
                    
                    Picker("事件类型", selection: $eventType) {
                        ForEach(PomodoroEvent.EventType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section {
                    Text("选择的时间段: \(formatTime(adjustedStartTime)) - \(formatTime(adjustedEndTime))")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .navigationTitle("快速添加事件")
            .toolbar {
                 ToolbarItem(placement: .cancellationAction) {
                     Button("取消") {
                         dismiss()
                     }
                 }
                 
                 ToolbarItem(placement: .confirmationAction) {
                     Button("保存") {
                         saveEvent()
                     }
                     .disabled(title.isEmpty)
                 }
             }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func saveEvent() {
        let event = PomodoroEvent(
            title: title,
            startTime: adjustedStartTime,
            endTime: adjustedEndTime,
            type: eventType
        )
        
        eventManager.addEvent(event)
        dismiss()
    }
}

struct EventDetailView: View {
    let event: PomodoroEvent
    @EnvironmentObject var eventManager: EventManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                // 事件类型和图标
                HStack {
                    Image(systemName: event.type.icon)
                        .font(.title2)
                        .foregroundColor(event.type.color)
                    
                    VStack(alignment: .leading) {
                        Text(event.type.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(event.title)
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    if event.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                    }
                }
                
                // 时间信息
                VStack(alignment: .leading, spacing: 8) {
                    Label(event.formattedTimeRange, systemImage: "clock")
                    Label(event.formattedDuration, systemImage: "timer")
                }
                .font(.body)
                .foregroundColor(.secondary)
                
                Spacer()
                
                // 操作按钮
                VStack(spacing: 12) {
                    if !event.isCompleted {
                        Button(action: {
                            var updatedEvent = event
                            updatedEvent.isCompleted = true
                            eventManager.updateEvent(updatedEvent)
                            dismiss()
                        }) {
                            Label("标记为完成", systemImage: "checkmark.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    Button(action: {
                        showingDeleteAlert = true
                    }) {
                        Label("删除事件", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
            }
            .padding()
            .navigationTitle("事件详情")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button("完成") {
                        dismiss()
                    }
                }
                #endif
            }
        }
        .alert("删除事件", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                eventManager.removeEvent(event)
                dismiss()
            }
        } message: {
            Text("确定要删除这个事件吗？此操作无法撤销。")
        }
    }
}

struct CalendarView_Previews: PreviewProvider {
    static var previews: some View {
        CalendarView()
            .environmentObject(EventManager())
    }
}

