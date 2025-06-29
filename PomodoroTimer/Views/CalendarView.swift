//
//  CalendarView.swift
//  PomodoroTimer
//
//  Created by Developer on 2024.
//

import SwiftUI
import Foundation

// 导入事件模型
// 注意：确保EventModel.swift在同一个target中

// 确保PomodoroEvent类型可用
typealias Event = PomodoroEvent

enum CalendarViewMode: String, CaseIterable {
    case day = "日"
    case week = "周"
    case month = "月"
    
    var icon: String {
        switch self {
        case .day: return "calendar.day.timeline.left"
        case .week: return "calendar"
        case .month: return "calendar.month"
        }
    }
}

struct CalendarView: View {
    @EnvironmentObject var eventManager: EventManager
    @State private var selectedDate = Date()
    @State private var currentViewMode: CalendarViewMode = .day
    @State private var selectedEvent: PomodoroEvent?
    @State private var showingAddEvent = false
    @State private var draggedEvent: PomodoroEvent?
    @State private var dragOffset: CGSize = .zero
    
    private let calendar = Calendar.current
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 顶部工具栏
                CalendarToolbar(
                    selectedDate: $selectedDate,
                    viewMode: $currentViewMode,
                    showingAddEvent: $showingAddEvent
                )
                
                // 主要内容区域
                switch currentViewMode {
                case .day:
                    DayView(
                        selectedDate: $selectedDate,
                        selectedEvent: $selectedEvent,
                        showingAddEvent: $showingAddEvent,
                        draggedEvent: $draggedEvent,
                        dragOffset: $dragOffset
                    )
                    .environmentObject(eventManager)
                    
                case .week:
                    WeekView(selectedDate: $selectedDate)
                        .environmentObject(eventManager)
                    
                case .month:
                    MonthView(selectedDate: $selectedDate)
                        .environmentObject(eventManager)
                }
            }
            .navigationTitle("日历")
        }
        .sheet(isPresented: $showingAddEvent) {
            EventEditView(event: PomodoroEvent(
                title: "新事件",
                startTime: selectedDate,
                endTime: Calendar.current.date(byAdding: .hour, value: 1, to: selectedDate) ?? selectedDate,
                type: .custom
            ))
                .environmentObject(eventManager)
        }
    }
}

// MARK: - 日历工具栏
struct CalendarToolbar: View {
    @Binding var selectedDate: Date
    @Binding var viewMode: CalendarViewMode
    @Binding var showingAddEvent: Bool
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 12) {
            // 日期导航和视图模式切换
            HStack {
                // 日期导航
                HStack(spacing: 16) {
                    Button(action: previousPeriod) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                    }
                    
                    Text(formattedDateTitle)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Button(action: nextPeriod) {
                        Image(systemName: "chevron.right")
                            .font(.title2)
                    }
                }
                
                Spacer()
                
                // 视图模式切换
                Picker("视图模式", selection: $viewMode) {
                    ForEach(CalendarViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
                
                // 添加事件按钮
                Button(action: {
                    showingAddEvent = true
                }) {
                    Image(systemName: "plus")
                        .font(.title2)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            Divider()
        }
    }
    
    private var formattedDateTitle: String {
        switch viewMode {
        case .day:
            return dateFormatter.string(from: selectedDate)
        case .week:
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? selectedDate
            let formatter = DateFormatter()
            formatter.dateFormat = "M月d日"
            return "\(formatter.string(from: weekStart)) - \(formatter.string(from: weekEnd))"
        case .month:
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy年M月"
            return formatter.string(from: selectedDate)
        }
    }
    
    private func previousPeriod() {
        switch viewMode {
        case .day:
            selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        case .week:
            selectedDate = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedDate) ?? selectedDate
        case .month:
            selectedDate = calendar.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
        }
    }
    
    private func nextPeriod() {
        switch viewMode {
        case .day:
            selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        case .week:
            selectedDate = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate) ?? selectedDate
        case .month:
            selectedDate = calendar.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
        }
    }
}

// MARK: - 日视图
struct DayView: View {
    @Binding var selectedDate: Date
    @Binding var selectedEvent: PomodoroEvent?
    @Binding var showingAddEvent: Bool
    @Binding var draggedEvent: PomodoroEvent?
    @Binding var dragOffset: CGSize
    @EnvironmentObject var eventManager: EventManager
    private let calendar = Calendar.current
    private let hourHeight: CGFloat = 60
    
    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                // 左侧时间轴区域
                TimelineView(
                    selectedDate: selectedDate,
                    selectedEvent: $selectedEvent,
                    showingAddEvent: $showingAddEvent,
                    draggedEvent: $draggedEvent,
                    dragOffset: $dragOffset,
                    hourHeight: hourHeight
                )
                .environmentObject(eventManager)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // 右侧面板
                VStack(spacing: 0) {
                    MiniCalendarView(selectedDate: $selectedDate)
                        .frame(height: 300)
                        .padding()
                    Divider()
                    EventDetailPanel(selectedEvent: $selectedEvent)
                        .environmentObject(eventManager)
                        .frame(maxHeight: .infinity)
                }
                .frame(width: 300)
                .background {
                    #if os(iOS)
                    Color(.systemGray6)
                    #else
                    Color(NSColor.windowBackgroundColor)
                    #endif
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

// MARK: - 时间轴视图
struct TimelineView: View {
    let selectedDate: Date
    @Binding var selectedEvent: PomodoroEvent?
    @Binding var showingAddEvent: Bool
    @Binding var draggedEvent: PomodoroEvent?
    @Binding var dragOffset: CGSize
    let hourHeight: CGFloat
    
    @EnvironmentObject var eventManager: EventManager
    @State private var selectionStart: CGPoint?
    @State private var selectionEnd: CGPoint?
    @State private var isSelecting = false
    
    private let calendar = Calendar.current
    private let hours = Array(0...23)
    
    private var eventsForDay: [PomodoroEvent] {
        eventManager.eventsForDate(selectedDate)
    }

    // 新增：计算事件并列排布信息
    private var eventLayoutInfo: [(event: PomodoroEvent, column: Int, totalColumns: Int)] {
        computeEventColumns(events: eventsForDay)
    }

    var body: some View {
        ScrollView {
            ZStack(alignment: .topLeading) {
                // 时间标签和网格线
                VStack(spacing: 0) {
                    ForEach(hours, id: \.self) { (hour: Int) in
                        HStack {
                            // 时间标签
                            Text(String(format: "%02d:00", hour))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 50, alignment: .trailing)
                            
                            // 网格线
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 1)
                        }
                        .frame(height: hourHeight)
                    }
                }
                
                // 事件块（并列排布）
                ForEach(eventLayoutInfo, id: \.0.id) { info in
                    let (event, column, totalColumns) = info
                    EventBlock(
                        event: event,
                        selectedEvent: $selectedEvent,
                        draggedEvent: $draggedEvent,
                        dragOffset: $dragOffset,
                        hourHeight: hourHeight,
                        selectedDate: selectedDate,
                        column: column,
                        totalColumns: totalColumns
                    )
                }
                
                // 选择区域覆盖层
                if isSelecting, let start = selectionStart, let end = selectionEnd {
                    SelectionOverlay(start: start, end: end)
                }
            }
            .padding(.leading, 60)
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    if selectionStart == nil {
                        selectionStart = value.startLocation
                        isSelecting = true
                    }
                    selectionEnd = value.location
                }
                .onEnded { value in
                    createEventFromSelection()
                    resetSelection()
                }
        )
    }

    // --- 新增：事件并列排布算法 ---
    private func computeEventColumns(events: [PomodoroEvent]) -> [(PomodoroEvent, Int, Int)] {
        // 按开始时间排序
        let sorted = events.sorted { $0.startTime < $1.startTime }
        var result: [(PomodoroEvent, Int, Int)] = []
        var active: [(PomodoroEvent, Int)] = [] // (event, column)
        for event in sorted {
            // 移除已结束的事件
            active.removeAll { $0.0.endTime <= event.startTime }
            // 查找可用列
            let usedColumns = Set(active.map { $0.1 })
            var col = 0
            while usedColumns.contains(col) { col += 1 }
            active.append((event, col))
            // 计算当前重叠的总列数
            let overlapCount = active.count
            result.append((event, col, overlapCount))
        }
        // 由于每个事件的 totalColumns 需要是与其重叠区间的最大 overlapCount，需再遍历修正
        var eventToMaxCol: [UUID: Int] = [:]
        for (event, _, _) in result {
            let overlapping = result.filter {
                $0.0.startTime < event.endTime && $0.0.endTime > event.startTime
            }
            let maxCol = overlapping.map { $0.2 }.max() ?? 1
            eventToMaxCol[event.id] = maxCol
        }
        return result.map { (event, col, _) in
            (event, col, eventToMaxCol[event.id] ?? 1)
        }
    }
    // --- END ---
    
    private func createEventFromSelection() {
        guard let start = selectionStart, let end = selectionEnd else { return }
        // 支持分钟级别
        let startY = min(start.y, end.y)
        let endY = max(start.y, end.y)
        let totalMinutesStart = max(0, min(24*60-1, Int(startY / hourHeight * 60)))
        let totalMinutesEnd = max(totalMinutesStart+1, min(24*60, Int(endY / hourHeight * 60)))
        let startHour = totalMinutesStart / 60
        let startMinute = totalMinutesStart % 60
        let endHour = totalMinutesEnd / 60
        let endMinute = totalMinutesEnd % 60
        let startTime = calendar.date(bySettingHour: startHour, minute: startMinute, second: 0, of: selectedDate) ?? selectedDate
        let endTime = calendar.date(bySettingHour: endHour, minute: endMinute, second: 0, of: selectedDate) ?? selectedDate
        let newEvent = PomodoroEvent(
            title: "新事件",
            startTime: startTime,
            endTime: endTime,
            type: PomodoroEvent.EventType.custom
        )
        eventManager.addEvent(newEvent)
        selectedEvent = newEvent
    }
    
    private func resetSelection() {
        selectionStart = nil
        selectionEnd = nil
        isSelecting = false
    }
}
                
// MARK: - 事件块
struct EventBlock: View {
    let event: PomodoroEvent
    @Binding var selectedEvent: PomodoroEvent?
    @Binding var draggedEvent: PomodoroEvent?
    @Binding var dragOffset: CGSize
    let hourHeight: CGFloat
    let selectedDate: Date
    var column: Int = 0
    var totalColumns: Int = 1
    @EnvironmentObject var eventManager: EventManager
    private let calendar = Calendar.current
    private var eventPosition: (y: CGFloat, height: CGFloat) {
        let startHour = calendar.component(.hour, from: event.startTime)
        let startMinute = calendar.component(.minute, from: event.startTime)
        let endHour = calendar.component(.hour, from: event.endTime)
        let endMinute = calendar.component(.minute, from: event.endTime)
        let startY = CGFloat(startHour) * hourHeight + CGFloat(startMinute) * hourHeight / 60
        let endY = CGFloat(endHour) * hourHeight + CGFloat(endMinute) * hourHeight / 60
        let height = endY - startY
        return (startY, max(20, height))
    }
    var body: some View {
        let position = eventPosition
        let blockWidth: CGFloat = 180 // 单列宽度
        let gap: CGFloat = 8
        let width = (blockWidth - gap * CGFloat(totalColumns - 1)) / CGFloat(totalColumns)
        let x = 100 + CGFloat(column) * (width + gap)
        RoundedRectangle(cornerRadius: 6)
            .fill(event.type.color.opacity(0.8))
            .overlay(
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .lineLimit(2)
                    Text(event.formattedTimeRange)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            )
            .frame(width: width, height: position.height)
            .position(x: x + width / 2, y: position.y + position.height / 2)
            .offset(draggedEvent?.id == event.id ? dragOffset : .zero)
            .scaleEffect(selectedEvent?.id == event.id ? 1.05 : 1.0)
            .shadow(radius: selectedEvent?.id == event.id ? 4 : 2)
            .onTapGesture {
                selectedEvent = event
            }
            .contextMenu {
                Button(role: .destructive) {
                    eventManager.removeEvent(event)
                    if selectedEvent?.id == event.id { selectedEvent = nil }
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        draggedEvent = event
                        dragOffset = value.translation
                        selectedEvent = event // 拖动时高亮选中
                    }
                    .onEnded { value in
                        updateEventTime(with: value.translation)
                        draggedEvent = nil as PomodoroEvent?
                        dragOffset = .zero
                    }
            )
    }
    private func updateEventTime(with translation: CGSize) {
        // 支持分钟级别
        let minuteChange = Int(translation.height / hourHeight * 60)
        guard let newStartTime = calendar.date(byAdding: .minute, value: minuteChange, to: event.startTime),
              let newEndTime = calendar.date(byAdding: .minute, value: minuteChange, to: event.endTime) else {
            return
        }
        var updatedEvent = event
        updatedEvent.startTime = newStartTime
        updatedEvent.endTime = newEndTime
        eventManager.updateEvent(updatedEvent)
    }
}

// MARK: - 选择覆盖层
struct SelectionOverlay: View {
    let start: CGPoint
    let end: CGPoint
    
    var body: some View {
        let rect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
        
        Rectangle()
            .fill(Color.blue.opacity(0.3))
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }
}

// MARK: - 小日历视图
struct MiniCalendarView: View {
    @Binding var selectedDate: Date
    @State private var currentMonth = Date()
    
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    private var monthDays: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth) else {
            return []
        }
        
        let firstOfMonth = monthInterval.start
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let daysToSubtract = (firstWeekday - 1) % 7
        
        guard let startDate = calendar.date(byAdding: .day, value: -daysToSubtract, to: firstOfMonth) else {
            return []
        }
        
        var days: [Date] = []
        for i in 0..<42 {
            if let day = calendar.date(byAdding: .day, value: i, to: startDate) {
                days.append(day)
            }
        }
        
        return days
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // 月份导航
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .font(.caption)
                }
                
                Spacer()
                
                Text(monthFormatter.string(from: currentMonth))
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
            }
            
            // 星期标题
            HStack(spacing: 0) {
                ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { day in
                    Text(day)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // 日历网格
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(monthDays, id: \.self) { date in
                    MiniDayCell(date: date, selectedDate: $selectedDate, currentMonth: currentMonth)
                }
            }
        }
    }
    
    private let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        return formatter
    }()
    
    private func previousMonth() {
        currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
    }
    
    private func nextMonth() {
        currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
    }
}

// MARK: - 小日历日期单元格
struct MiniDayCell: View {
    let date: Date
    @Binding var selectedDate: Date
    let currentMonth: Date
    
    private let calendar = Calendar.current
    
    private var isSelected: Bool {
        calendar.isDate(date, inSameDayAs: selectedDate)
    }
    
    private var isCurrentMonth: Bool {
        calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)
    }
    
    private var isToday: Bool {
        calendar.isDateInToday(date)
    }
    
    var body: some View {
        Button(action: {
            selectedDate = date
        }) {
            Text("\(calendar.component(.day, from: date))")
                .font(.caption)
                .fontWeight(isSelected ? .bold : .regular)
                .foregroundColor({
                    if isSelected {
                        return .white
                    } else if isToday {
                        return .blue
                    } else if isCurrentMonth {
                        return .primary
                    } else {
                        return .secondary
                    }
                }())
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(isSelected ? Color.blue : Color.clear)
                )
                .overlay(
                    Circle()
                        .stroke(isToday && !isSelected ? Color.blue : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 事件详情面板
struct EventDetailPanel: View {
    @Binding var selectedEvent: PomodoroEvent?
    @EnvironmentObject var eventManager: EventManager
    @State private var editSuccessFlag = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let event = selectedEvent {
                // 事件详情编辑
                EventEditView(event: event, onSave: {
                    // 保存后刷新右侧面板
                    editSuccessFlag.toggle()
                }, onDelete: {
                    // 删除后自动回到未选中
                    selectedEvent = nil
                })
                .id(event.id) // 保证切换事件时刷新
                .environmentObject(eventManager)
            } else {
                // 空状态
                VStack(spacing: 16) {
                    Image(systemName: "calendar")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("未选中事件")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Text("请在左侧时间轴点击事件，或拖拽新建事件后在此编辑详情")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
#if os(iOS)
                .background(Color(.systemGray6))
#else
                .background(Color(NSColor.windowBackgroundColor))
#endif
                .cornerRadius(12)
            }
        }
        .padding()
#if os(iOS)
        .background(Color(.systemBackground))
#else
        .background(Color(NSColor.controlBackgroundColor))
#endif
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
    }
}

// MARK: - 事件编辑视图
struct EventEditView: View {
    let event: PomodoroEvent
    var onSave: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    @EnvironmentObject var eventManager: EventManager
    @State private var title: String
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var eventType: PomodoroEvent.EventType
    @State private var showingDeleteAlert = false
    init(event: PomodoroEvent, onSave: (() -> Void)? = nil, onDelete: (() -> Void)? = nil) {
        self.event = event
        self.onSave = onSave
        self.onDelete = onDelete
        self._title = State(initialValue: event.title)
        self._startTime = State(initialValue: event.startTime)
        self._endTime = State(initialValue: event.endTime)
        self._eventType = State(initialValue: event.type)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("事件详情")
                .font(.headline)
                .fontWeight(.semibold)
            VStack(alignment: .leading, spacing: 4) {
                Text("标题")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("事件标题", text: $title)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("时间")
                    .font(.caption)
                    .foregroundColor(.secondary)
                DatePicker("开始时间", selection: $startTime, displayedComponents: [.hourAndMinute])
                    .datePickerStyle(CompactDatePickerStyle())
                DatePicker("结束时间", selection: $endTime, displayedComponents: [.hourAndMinute])
                    .datePickerStyle(CompactDatePickerStyle())
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("类型")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Picker("事件类型", selection: $eventType) {
                    ForEach(["番茄时间", "短休息", "长休息", "自定义"], id: \.self) { (typeName: String) in
                        Text(typeName)
                            .tag(getEventType(from: typeName))
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            Spacer()
            VStack(spacing: 8) {
                Button("保存更改") {
                    saveChanges()
                    onSave?()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                Button("删除事件") {
                    showingDeleteAlert = true
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
            }
        }
        .alert("删除事件", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                eventManager.removeEvent(event)
                onDelete?()
            }
        } message: {
            Text("确定要删除这个事件吗？此操作无法撤销。")
        }
    }
    private func getEventType(from typeName: String) -> PomodoroEvent.EventType {
        switch typeName {
        case "番茄时间": return .pomodoro
        case "短休息": return .shortBreak
        case "长休息": return .longBreak
        case "自定义": return .custom
        default: return .custom
        }
    }
    private func saveChanges() {
        var updatedEvent = event
        updatedEvent.title = title
        updatedEvent.startTime = startTime
        updatedEvent.endTime = endTime
        updatedEvent.type = eventType
        eventManager.updateEvent(updatedEvent)
    }
}

// MARK: - 周视图（占位符）
struct WeekView: View {
    @Binding var selectedDate: Date
    @EnvironmentObject var eventManager: EventManager
    
    var body: some View {
        VStack {
            Text("周视图")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("即将推出")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 月视图（占位符）
struct MonthView: View {
    @Binding var selectedDate: Date
    @EnvironmentObject var eventManager: EventManager
    
    var body: some View {
        VStack {
            Text("月视图")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("即将推出")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

