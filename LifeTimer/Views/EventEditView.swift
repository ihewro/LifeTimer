//
//  EventEditView.swift
//  LifeTimer
//
//  Created by Developer on 2024.
//

import SwiftUI

struct EventEditView: View {
    let event: PomodoroEvent
    let onSave: (PomodoroEvent) -> Void
    let onDelete: () -> Void
    
    @EnvironmentObject var eventManager: EventManager
    @State private var title: String
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var eventType: PomodoroEvent.EventType
    
    init(event: PomodoroEvent, onSave: @escaping (PomodoroEvent) -> Void, onDelete: @escaping () -> Void) {
        self.event = event
        self.onSave = onSave
        self.onDelete = onDelete
        self._title = State(initialValue: event.title)
        self._startTime = State(initialValue: event.startTime)
        self._endTime = State(initialValue: event.endTime)
        self._eventType = State(initialValue: event.type)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 标题
            HStack {
                Text("编辑事件")
                    .font(.headline)
                Spacer()
                Button("×") {
                    onSave(event) // 关闭时传递原始事件
                }
                .buttonStyle(.plain)
                .font(.title2)
            }
            
            // 事件标题
            VStack(alignment: .leading, spacing: 8) {
                Text("标题")
                    .font(.subheadline)
                    .fontWeight(.medium)
                TextField("事件标题", text: $title)
                    .textFieldStyle(.roundedBorder)
            }
            
            // 事件类型
            VStack(alignment: .leading, spacing: 8) {
                Text("类型")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Picker("事件类型", selection: $eventType) {
                    ForEach(PomodoroEvent.EventType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // 开始时间
            VStack(alignment: .leading, spacing: 8) {
                Text("开始时间")
                    .font(.subheadline)
                    .fontWeight(.medium)
                DatePicker("", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
            }
            
            // 结束时间
            VStack(alignment: .leading, spacing: 8) {
                Text("结束时间")
                    .font(.subheadline)
                    .fontWeight(.medium)
                DatePicker("", selection: $endTime, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
            }
            
            Spacer()
            
            // 按钮
            HStack {
                Button("删除", role: .destructive) {
                    eventManager.removeEvent(event)
                    onDelete()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("取消") {
                    onSave(event) // 取消时传递原始事件
                }
                .buttonStyle(.bordered)
                
                Button("保存") {
                    saveEvent()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.systemBackground)
    }
    
    private func saveEvent() {
        // 确保结束时间在开始时间之后
        if endTime <= startTime {
            endTime = startTime.addingTimeInterval(1800) // 默认30分钟
        }
        
        var updatedEvent = event
        updatedEvent.title = title.isEmpty ? eventType.displayName : title
        updatedEvent.startTime = startTime
        updatedEvent.endTime = endTime
        updatedEvent.type = eventType
        
        eventManager.updateEvent(updatedEvent)
        onSave(updatedEvent) // 传递更新后的事件
    }
}

#Preview {
    EventEditView(
        event: PomodoroEvent(
            title: "测试事件",
            startTime: Date(),
            endTime: Date().addingTimeInterval(1800),
            type: .pomodoro
        ),
        onSave: { _ in },
        onDelete: {}
    )
    .environmentObject(EventManager())
    .frame(width: 400, height: 500)
}
