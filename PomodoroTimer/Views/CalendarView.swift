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
    @EnvironmentObject var activityMonitor: ActivityMonitorManager
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
                        .environmentObject(activityMonitor)

                case .month:
                    MonthView(selectedDate: $selectedDate)
                        .environmentObject(eventManager)
                        .environmentObject(activityMonitor)
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
            // 简化的工具栏：只保留日期文字、今天按钮和添加事件按钮
            HStack {
                // 日期显示（只保留文字，删除左右切换按钮）
                Text(formattedDateTitle)
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                // 今天按钮和添加事件按钮
                HStack(spacing: 12) {
                    // 今天按钮
                    Button(action: goToToday) {
                        Text("今天")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.blue, lineWidth: 1)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(isToday ? Color.blue.opacity(0.1) : Color.clear)
                                    )
                            )
                    }
                    .disabled(isToday)

                    // 视图模式切换（保留功能但移除"视图模式"标签）
                    Picker("", selection: $viewMode) {
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
    


    /// 跳转到今天
    private func goToToday() {
        selectedDate = Date()
    }

    /// 检查当前选中的日期是否是今天
    private var isToday: Bool {
        switch viewMode {
        case .day:
            return calendar.isDateInToday(selectedDate)
        case .week:
            let today = Date()
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate),
                  let todayWeekInterval = calendar.dateInterval(of: .weekOfYear, for: today) else {
                return false
            }
            return weekInterval.start == todayWeekInterval.start
        case .month:
            let today = Date()
            return calendar.isDate(selectedDate, equalTo: today, toGranularity: .month)
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

                // 右侧面板 - 恢复日历模块和事件详情
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
                .background(
                    Group {
                        #if os(iOS)
                        Color(.systemGray6)
                        #else
                        Color(NSColor.windowBackgroundColor)
                        #endif
                    }
                )
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

    // 性能优化：缓存事件布局信息，避免拖拽时重复计算
    private var eventLayoutInfo: [(event: PomodoroEvent, column: Int, totalColumns: Int)] {
        // 只有在事件列表变化时才重新计算布局
        computeEventColumns(events: eventsForDay)
    }

    var body: some View {
        GeometryReader { geometry in
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

                    // 事件块（并列排布）- 性能优化，使用动态宽度
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
                            totalColumns: totalColumns,
                            containerWidth: geometry.size.width-50 // 使用TimelineView本身的宽度
                        )
                        .id(event.id) // 确保正确的视图标识，提高更新性能
                        .drawingGroup() // 将事件块渲染为单个图层，提高性能
                    }
                
                // 选择区域覆盖层
                if isSelecting, let start = selectionStart, let end = selectionEnd {
                    SelectionOverlay(start: start, end: end)
                }
            }
            .padding(.leading, 60)
        }
        .onTapGesture { location in
            // 简化的点击处理：点击空白区域取消选中事件
            // 由于事件块有自己的onTapGesture，这里只处理空白区域的点击
            selectedEvent = nil
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    // 改进拖拽体验：只在事件区域内开始选择
                    let leftPadding: CGFloat = 60

                    if selectionStart == nil {
                        // 只有在事件区域内点击才开始选择
                        if value.startLocation.x > leftPadding {
                            selectionStart = value.startLocation
                            isSelecting = true
                        }
                    }

                    // 更新选择结束位置
                    if isSelecting {
                        selectionEnd = value.location
                    }
                }
                .onEnded { value in
                    if isSelecting {
                        createEventFromSelection()
                    }
                    resetSelection()
                }
        )
        }
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

        // 修复坐标系问题：考虑左侧时间标签的偏移
        // TimelineView 有 .padding(.leading, 60)，所以需要调整坐标
        let leftPadding: CGFloat = 60

        // 只有在事件区域内的点击才创建事件（x > leftPadding）
        guard start.x > leftPadding && end.x > leftPadding else { return }

        // 支持分钟级别的精确时间计算
        let startY = min(start.y, end.y)
        let endY = max(start.y, end.y)

        // 确保选择区域有最小高度（至少15分钟）
        let minSelectionHeight = hourHeight * 0.25 // 15分钟
        let adjustedEndY = max(endY, startY + minSelectionHeight)

        let totalMinutesStart = max(0, min(24*60-1, Int(startY / hourHeight * 60)))
        let totalMinutesEnd = max(totalMinutesStart+15, min(24*60, Int(adjustedEndY / hourHeight * 60)))

        let startHour = totalMinutesStart / 60
        let startMinute = totalMinutesStart % 60
        let endHour = totalMinutesEnd / 60
        let endMinute = totalMinutesEnd % 60

        guard let startTime = calendar.date(bySettingHour: startHour, minute: startMinute, second: 0, of: selectedDate),
              let endTime = calendar.date(bySettingHour: endHour, minute: endMinute, second: 0, of: selectedDate) else {
            return
        }

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

    // 计算事件的位置信息
    private func eventPositionForEvent(_ event: PomodoroEvent) -> (y: CGFloat, height: CGFloat) {
        let startHour = calendar.component(.hour, from: event.startTime)
        let startMinute = calendar.component(.minute, from: event.startTime)
        let endHour = calendar.component(.hour, from: event.endTime)
        let endMinute = calendar.component(.minute, from: event.endTime)
        let startY = CGFloat(startHour) * hourHeight + CGFloat(startMinute) * hourHeight / 60
        let endY = CGFloat(endHour) * hourHeight + CGFloat(endMinute) * hourHeight / 60
        let height = endY - startY
        return (startY, max(20, height))
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
    let containerWidth: CGFloat // 新增：容器宽度参数
    @EnvironmentObject var eventManager: EventManager

    // 性能优化：缓存计算结果
    private let calendar = Calendar.current
    @State private var isDragging = false
    @State private var dragStartOffset: CGSize = .zero
    @State private var lastUpdateTime: Date = Date()

    // 拖拽阈值，避免意外触发 - 降低阈值以提高响应性
    private let dragThreshold: CGFloat = 1.0
    // 更新频率限制（毫秒）- 提高更新频率以改善响应性
    private let updateThrottleMs: TimeInterval = 8.33 // ~120fps
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

        // 动态计算宽度：使用容器宽度而不是固定值
        let leftPadding: CGFloat = 60 // 时间标签区域宽度
        let rightPadding: CGFloat = 20 // 右侧留白
        let availableWidth = containerWidth - leftPadding - rightPadding
        let gap: CGFloat = 4 // 减小间隙以节省空间
        let totalGapWidth = gap * CGFloat(totalColumns - 1)
        let width = (availableWidth - totalGapWidth) / CGFloat(totalColumns)
        let x = leftPadding + CGFloat(column) * (width + gap)
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
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8), value: selectedEvent?.id == event.id)
            .animation(.none, value: draggedEvent?.id == event.id ? dragOffset : .zero) // 拖拽时不使用动画
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
                DragGesture(minimumDistance: dragThreshold)
                    .onChanged { value in
                        handleDragChanged(value)
                    }
                    .onEnded { value in
                        handleDragEnded(value)
                    }
            )
    }

    // MARK: - 性能优化的拖拽处理

    private func handleDragChanged(_ value: DragGesture.Value) {
        let currentTime = Date()

        // 初始拖拽检测：立即响应，不受节流限制
        if !isDragging {
            isDragging = true
            dragStartOffset = value.translation
            selectedEvent = event // 开始拖拽时选中
            draggedEvent = event
            dragOffset = value.translation

            // 触觉反馈
            #if os(iOS)
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            #endif

            lastUpdateTime = currentTime
            return
        }

        // 后续拖拽更新：应用节流以优化性能
        guard currentTime.timeIntervalSince(lastUpdateTime) >= updateThrottleMs / 1000 else {
            // 即使在节流期间，也要更新偏移量以保持流畅性
            dragOffset = value.translation
            return
        }

        // 使用相对偏移量，减少计算
        dragOffset = value.translation
        lastUpdateTime = currentTime
    }

    private func handleDragEnded(_ value: DragGesture.Value) {
        defer {
            // 清理状态
            isDragging = false
            draggedEvent = nil
            dragOffset = .zero
            dragStartOffset = .zero
        }

        // 只有实际移动了才更新时间
        let totalTranslation = value.translation
        if abs(totalTranslation.height) > dragThreshold {
            updateEventTime(with: totalTranslation)
        }
    }

    private func updateEventTime(with translation: CGSize) {
        // 性能优化：使用更精确的时间计算
        let timeChange = translation.height / hourHeight * 3600 // 秒数
        let roundedTimeChange = round(timeChange / 300) * 300 // 四舍五入到5分钟

        guard let newStartTime = calendar.date(byAdding: .second, value: Int(roundedTimeChange), to: event.startTime),
              let newEndTime = calendar.date(byAdding: .second, value: Int(roundedTimeChange), to: event.endTime) else {
            return
        }

        // 批量更新，减少重绘
        DispatchQueue.main.async {
            var updatedEvent = event
            updatedEvent.startTime = newStartTime
            updatedEvent.endTime = newEndTime
            eventManager.updateEvent(updatedEvent)
        }
    }
}

// MARK: - 选择覆盖层
struct SelectionOverlay: View {
    let start: CGPoint
    let end: CGPoint

    var body: some View {
        // 修复选择区域显示：限制在事件区域内
        let leftPadding: CGFloat = 60
        let eventAreaWidth: CGFloat = 200 // 事件区域宽度

        let constrainedStart = CGPoint(
            x: max(leftPadding, start.x),
            y: start.y
        )
        let constrainedEnd = CGPoint(
            x: min(leftPadding + eventAreaWidth, max(leftPadding, end.x)),
            y: end.y
        )

        let rect = CGRect(
            x: min(constrainedStart.x, constrainedEnd.x),
            y: min(constrainedStart.y, constrainedEnd.y),
            width: max(10, abs(constrainedEnd.x - constrainedStart.x)), // 最小宽度
            height: max(10, abs(constrainedEnd.y - constrainedStart.y)) // 最小高度
        )

        Rectangle()
            .foregroundColor(Color.blue.opacity(0.2))
            .overlay(
                Rectangle()
                    .stroke(Color.blue.opacity(0.6), lineWidth: 1)
            )
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
                    Group {
                        #if os(iOS)
                        Color(.systemBackground)
                        #else
                        Color(NSColor.controlBackgroundColor)
                        #endif
                    }
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
                .background(
                    Group {
                        #if os(iOS)
                        Color(.systemGray6)
                        #else
                        Color(NSColor.windowBackgroundColor)
                        #endif
                    }
                )
                .cornerRadius(12)
            }
        }
        .padding()
        .background(
            Group {
                #if os(iOS)
                Color(.systemBackground)
                #else
                Color(NSColor.controlBackgroundColor)
                #endif
            }
        )
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

// MARK: - 周视图
struct WeekView: View {
    @Binding var selectedDate: Date
    @EnvironmentObject var eventManager: EventManager
    @EnvironmentObject var activityMonitor: ActivityMonitorManager
    @State private var selectedEvent: PomodoroEvent?
    @State private var showingAddEvent = false

    private let calendar = Calendar.current
    private let hourHeight: CGFloat = 50

    // 获取当前周的日期范围
    private var weekDates: [Date] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else {
            return []
        }

        var dates: [Date] = []
        let startDate = weekInterval.start

        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: i, to: startDate) {
                dates.append(date)
            }
        }

        return dates
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // 主要周视图区域
                VStack(spacing: 0) {
                    // 星期标题行
                    weekHeaderView
                        .frame(height: 60)

                    Divider()

                    // 时间轴和事件网格
                    ScrollView {
                        HStack(alignment: .top, spacing: 0) {
                            // 左侧时间标签
                            timeLabelsView
                                .frame(width: 60)

                            // 周事件网格
                            weekGridView
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                // 右侧面板（类似日视图）
                VStack(spacing: 0) {
                    // 小日历
                    MiniCalendarView(selectedDate: $selectedDate)
                        .frame(height: 250)
                        .padding()

                    Divider()

                    // 周统计信息
                    weekStatsPanel
                        .frame(maxHeight: .infinity)
                }
                .frame(width: 300)
                .background(
                    Group {
                        #if os(iOS)
                        Color(.systemGray6)
                        #else
                        Color(NSColor.windowBackgroundColor)
                        #endif
                    }
                )
            }
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

    // 星期标题视图
    private var weekHeaderView: some View {
        HStack(spacing: 0) {
            // 左侧空白区域（对应时间标签）
            Rectangle()
                .fill(Color.clear)
                .frame(width: 60)

            // 星期标题
            ForEach(weekDates, id: \.self) { date in
                VStack(spacing: 4) {
                    Text(dayFormatter.string(from: date))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("\(calendar.component(.day, from: date))")
                        .font(.title2)
                        .fontWeight(calendar.isDate(date, inSameDayAs: selectedDate) ? .bold : .regular)
                        .foregroundColor(calendar.isDate(date, inSameDayAs: selectedDate) ? .blue : .primary)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedDate = date
                }
            }
        }
        .padding(.vertical, 8)
    }

    // 时间标签视图
    private var timeLabelsView: some View {
        VStack(spacing: 0) {
            ForEach(Array(0...23), id: \.self) { hour in
                HStack {
                    Text(String(format: "%02d:00", hour))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .trailing)

                    Spacer()
                }
                .frame(height: hourHeight)
            }
        }
    }

    // 周事件网格视图
    private var weekGridView: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(weekDates, id: \.self) { date in
                VStack(spacing: 0) {
                    // 每日网格线
                    ForEach(Array(0...23), id: \.self) { hour in
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 1)
                            .frame(maxWidth: .infinity)
                            .padding(.top, hourHeight - 1)
                    }
                }
                .background(
                    // 当日事件 - 使用并列布局算法
                    GeometryReader { dayGeometry in
                        ZStack(alignment: .topLeading) {
                            let dayEvents = eventManager.eventsForDate(date)
                            let eventLayoutInfo = computeEventColumns(events: dayEvents)

                            ForEach(eventLayoutInfo, id: \.0.id) { info in
                                let (event, column, totalColumns) = info
                                WeekEventBlock(
                                    event: event,
                                    selectedEvent: $selectedEvent,
                                    hourHeight: hourHeight,
                                    date: date,
                                    column: column,
                                    totalColumns: totalColumns,
                                    containerWidth: dayGeometry.size.width
                                )
                            }
                        }
                    }
                )
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { location in
                    // 点击创建新事件的逻辑
                    createEventAt(date: date, location: location)
                }
            }
        }
    }

    // 周统计面板
    private var weekStatsPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("本周统计")
                    .font(.headline)
                    .padding(.horizontal)

                // 本周活动概览
                weekActivityOverview

                // 本周热门应用
                weekTopApps

                Spacer()
            }
        }
    }

    // 本周活动概览
    private var weekActivityOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("活动概览")
                .font(.subheadline)
                .fontWeight(.medium)

            // 计算本周统计
            let weekStats = calculateWeekStats()

            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "timer")
                        .foregroundColor(.blue)
                    Text("总活跃时间")
                    Spacer()
                    Text(formatTime(weekStats.totalActiveTime))
                        .fontWeight(.medium)
                }

                HStack {
                    Image(systemName: "app.badge")
                        .foregroundColor(.orange)
                    Text("应用切换")
                    Spacer()
                    Text("\(weekStats.totalAppSwitches)")
                        .fontWeight(.medium)
                }

                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(.green)
                    Text("番茄时钟")
                    Spacer()
                    Text("\(weekStats.pomodoroSessions)")
                        .fontWeight(.medium)
                }
            }
            .font(.caption)
        }
        .padding()
        .background(
            Group {
                #if os(iOS)
                Color(.systemBackground)
                #else
                Color(NSColor.controlBackgroundColor)
                #endif
            }
        )
        .cornerRadius(8)
        .padding(.horizontal)
    }

    // 本周热门应用
    private var weekTopApps: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("热门应用")
                .font(.subheadline)
                .fontWeight(.medium)

            let topApps = getWeekTopApps()

            if topApps.isEmpty {
                Text("暂无数据")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(topApps.prefix(5)), id: \.appName) { app in
                    HStack {
                        Text(app.appName)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text(app.formattedTime)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(
            Group {
                #if os(iOS)
                Color(.systemBackground)
                #else
                Color(NSColor.controlBackgroundColor)
                #endif
            }
        )
        .cornerRadius(8)
        .padding(.horizontal)
    }

    // 辅助方法
    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter
    }()

    private func createEventAt(date: Date, location: CGPoint) {
        let hour = Int(location.y / hourHeight)
        let startTime = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
        let endTime = calendar.date(byAdding: .hour, value: 1, to: startTime) ?? startTime

        let newEvent = PomodoroEvent(
            title: "新事件",
            startTime: startTime,
            endTime: endTime,
            type: .custom
        )

        eventManager.addEvent(newEvent)
        selectedEvent = newEvent
    }

    private func calculateWeekStats() -> (totalActiveTime: TimeInterval, totalAppSwitches: Int, pomodoroSessions: Int) {
        var totalActiveTime: TimeInterval = 0
        var totalAppSwitches = 0
        var pomodoroSessions = 0

        for date in weekDates {
            let overview = activityMonitor.getTodayOverview()
            totalActiveTime += overview.activeTime
            totalAppSwitches += overview.appSwitches

            // 计算当日番茄时钟会话
            let dayEvents = eventManager.eventsForDate(date)
            pomodoroSessions += dayEvents.filter { $0.type == .pomodoro }.count
        }

        return (totalActiveTime, totalAppSwitches, pomodoroSessions)
    }

    private func getWeekTopApps() -> [AppUsageStats] {
        var allApps: [String: (totalTime: TimeInterval, activationCount: Int)] = [:]

        for date in weekDates {
            let dayApps = activityMonitor.getAppUsageStats(for: date)
            for app in dayApps {
                let current = allApps[app.appName] ?? (totalTime: 0, activationCount: 0)
                allApps[app.appName] = (
                    totalTime: current.totalTime + app.totalTime,
                    activationCount: current.activationCount + app.activationCount
                )
            }
        }

        return allApps.map { (appName, stats) in
            AppUsageStats(
                appName: appName,
                totalTime: stats.totalTime,
                activationCount: stats.activationCount,
                lastUsed: Date()
            )
        }.sorted { $0.totalTime > $1.totalTime }
    }

    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    // 事件并列排布算法（复用日视图的逻辑）
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

        // 修正每个事件的 totalColumns 为与其重叠区间的最大 overlapCount
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
}

// MARK: - 周视图事件块
struct WeekEventBlock: View {
    let event: PomodoroEvent
    @Binding var selectedEvent: PomodoroEvent?
    let hourHeight: CGFloat
    let date: Date
    var column: Int = 0
    var totalColumns: Int = 1
    let containerWidth: CGFloat

    private let calendar = Calendar.current

    // 性能优化：缓存位置计算
    private var eventPosition: (y: CGFloat, height: CGFloat) {
        let startHour = calendar.component(.hour, from: event.startTime)
        let startMinute = calendar.component(.minute, from: event.startTime)
        let endHour = calendar.component(.hour, from: event.endTime)
        let endMinute = calendar.component(.minute, from: event.endTime)

        let startY = CGFloat(startHour) * hourHeight + CGFloat(startMinute) * hourHeight / 60
        let endY = CGFloat(endHour) * hourHeight + CGFloat(endMinute) * hourHeight / 60
        let height = max(20, endY - startY)

        return (startY, height)
    }

    var body: some View {
        let position = eventPosition

        // 动态计算宽度和位置（类似日视图的EventBlock）
        let gap: CGFloat = 2 // 周视图中使用更小的间隙
        let totalGapWidth = gap * CGFloat(totalColumns - 1)
        let width = (containerWidth - totalGapWidth) / CGFloat(totalColumns)
        let x = CGFloat(column) * (width + gap)

        RoundedRectangle(cornerRadius: 4)
            .fill(event.type.color.opacity(0.8))
            .overlay(
                VStack(alignment: .leading, spacing: 1) {
                    Text(event.title)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if position.height > 30 {
                        Text(event.formattedTimeRange)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                }
                .padding(2)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            )
            .frame(width: width, height: position.height)
            .position(x: x + width / 2, y: position.y + position.height / 2)
            .scaleEffect(selectedEvent?.id == event.id ? 1.05 : 1.0)
            .shadow(radius: selectedEvent?.id == event.id ? 2 : 1)
            .onTapGesture {
                selectedEvent = event
            }
    }
}

// MARK: - 月视图
struct MonthView: View {
    @Binding var selectedDate: Date
    @EnvironmentObject var eventManager: EventManager
    @EnvironmentObject var activityMonitor: ActivityMonitorManager
    @State private var selectedEvent: PomodoroEvent?
    @State private var showingAddEvent = false
    @State private var currentMonth = Date()

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 7)

    // 获取当前月的所有日期（包括前后月份的日期以填满6周）
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
        for i in 0..<42 { // 6周 × 7天
            if let day = calendar.date(byAdding: .day, value: i, to: startDate) {
                days.append(day)
            }
        }

        return days
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // 主要月视图区域
                VStack(spacing: 0) {
                    // 月份导航
                    monthNavigationView
                        .frame(height: 50)

                    Divider()

                    // 星期标题
                    weekdayHeaderView
                        .frame(height: 40)

                    Divider()

                    // 月历网格
                    monthGridView
                        .frame(maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity)

                // 右侧面板
                VStack(spacing: 0) {
                    // 选中日期详情
                    selectedDatePanel
                        .frame(height: 200)
                        .padding()

                    Divider()

                    // 月度统计
                    monthStatsPanel
                        .frame(maxHeight: .infinity)
                }
                .frame(width: 300)
                .background(
                    Group {
                        #if os(iOS)
                        Color(.systemGray6)
                        #else
                        Color(NSColor.windowBackgroundColor)
                        #endif
                    }
                )
            }
        }
        .onAppear {
            currentMonth = selectedDate
        }
        .onChange(of: selectedDate) { newDate in
            if !calendar.isDate(newDate, equalTo: currentMonth, toGranularity: .month) {
                currentMonth = newDate
            }
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

    // 月份导航视图
    private var monthNavigationView: some View {
        HStack {
            Button(action: previousMonth) {
                Image(systemName: "chevron.left")
                    .font(.title2)
            }

            Spacer()

            Text(monthFormatter.string(from: currentMonth))
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            Button(action: nextMonth) {
                Image(systemName: "chevron.right")
                    .font(.title2)
            }
        }
        .padding(.horizontal)
    }

    // 星期标题视图
    private var weekdayHeaderView: some View {
        HStack(spacing: 0) {
            ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { day in
                Text(day)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
    }

    // 月历网格视图
    private var monthGridView: some View {
        LazyVGrid(columns: columns, spacing: 1) {
            ForEach(monthDays, id: \.self) { date in
                MonthDayCell(
                    date: date,
                    selectedDate: $selectedDate,
                    currentMonth: currentMonth,
                    events: eventManager.eventsForDate(date),
                    activityStats: activityMonitor.getAppUsageStats(for: date)
                )
                .onTapGesture {
                    selectedDate = date
                }
                .onLongPressGesture {
                    selectedDate = date
                    showingAddEvent = true
                }
            }
        }
        .padding(.horizontal, 8)
    }

    // 选中日期面板
    private var selectedDatePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selectedDateFormatter.string(from: selectedDate))
                .font(.headline)
                .fontWeight(.semibold)

            let dayEvents = eventManager.eventsForDate(selectedDate)

            if dayEvents.isEmpty {
                Text("无事件")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("今日事件 (\(dayEvents.count))")
                    .font(.subheadline)
                    .fontWeight(.medium)

                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(dayEvents.prefix(3), id: \.id) { event in
                            HStack {
                                Circle()
                                    .fill(event.type.color)
                                    .frame(width: 8, height: 8)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.title)
                                        .font(.caption)
                                        .lineLimit(1)

                                    Text(event.formattedTimeRange)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()
                            }
                            .onTapGesture {
                                selectedEvent = event
                            }
                        }

                        if dayEvents.count > 3 {
                            Text("还有 \(dayEvents.count - 3) 个事件...")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Button("添加事件") {
                showingAddEvent = true
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(
            Group {
                #if os(iOS)
                Color(.systemBackground)
                #else
                Color(NSColor.controlBackgroundColor)
                #endif
            }
        )
        .cornerRadius(8)
    }

    // 月度统计面板
    private var monthStatsPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("本月统计")
                    .font(.headline)
                    .padding(.horizontal)

                // 月度活动概览
                monthActivityOverview

                // 月度生产力趋势
                monthProductivityTrend

                Spacer()
            }
        }
    }

    // 月度活动概览
    private var monthActivityOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("活动概览")
                .font(.subheadline)
                .fontWeight(.medium)

            let monthStats = calculateMonthStats()

            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                    Text("活跃天数")
                    Spacer()
                    Text("\(monthStats.activeDays)")
                        .fontWeight(.medium)
                }

                HStack {
                    Image(systemName: "timer")
                        .foregroundColor(.orange)
                    Text("总活跃时间")
                    Spacer()
                    Text(formatTime(monthStats.totalActiveTime))
                        .fontWeight(.medium)
                }

                HStack {
                    Image(systemName: "target")
                        .foregroundColor(.green)
                    Text("番茄时钟")
                    Spacer()
                    Text("\(monthStats.pomodoroSessions)")
                        .fontWeight(.medium)
                }

                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.purple)
                    Text("平均生产力")
                    Spacer()
                    Text(String(format: "%.1f%%", monthStats.avgProductivity))
                        .fontWeight(.medium)
                }
            }
            .font(.caption)
        }
        .padding()
        .background(
            Group {
                #if os(iOS)
                Color(.systemBackground)
                #else
                Color(NSColor.controlBackgroundColor)
                #endif
            }
        )
        .cornerRadius(8)
        .padding(.horizontal)
    }

    // 月度生产力趋势
    private var monthProductivityTrend: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("生产力趋势")
                .font(.subheadline)
                .fontWeight(.medium)

            // 简单的生产力趋势图（使用条形图）
            let weeklyProductivity = calculateWeeklyProductivity()

            VStack(spacing: 8) {
                ForEach(Array(weeklyProductivity.enumerated()), id: \.offset) { index, productivity in
                    HStack {
                        Text("第\(index + 1)周")
                            .font(.caption)
                            .frame(width: 40, alignment: .leading)

                        GeometryReader { geometry in
                            HStack(spacing: 0) {
                                Rectangle()
                                    .fill(Color.green.opacity(0.7))
                                    .frame(width: geometry.size.width * CGFloat(productivity / 100))

                                Spacer(minLength: 0)
                            }
                        }
                        .frame(height: 8)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)

                        Text(String(format: "%.0f%%", productivity))
                            .font(.caption)
                            .frame(width: 35, alignment: .trailing)
                    }
                }
            }
        }
        .padding()
        .background(
            Group {
                #if os(iOS)
                Color(.systemBackground)
                #else
                Color(NSColor.controlBackgroundColor)
                #endif
            }
        )
        .cornerRadius(8)
        .padding(.horizontal)
    }

    // 辅助方法
    private let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        return formatter
    }()

    private let selectedDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 EEEE"
        return formatter
    }()

    private func previousMonth() {
        currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
    }

    private func nextMonth() {
        currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
    }

    private func calculateMonthStats() -> (activeDays: Int, totalActiveTime: TimeInterval, pomodoroSessions: Int, avgProductivity: Double) {
        let monthDates = getMonthDates()
        var activeDays = 0
        var totalActiveTime: TimeInterval = 0
        var pomodoroSessions = 0
        var totalProductivity: Double = 0

        for date in monthDates {
            let dayEvents = eventManager.eventsForDate(selectedDate)
            let appStats = activityMonitor.getAppUsageStats(for: date)

            if !dayEvents.isEmpty || !appStats.isEmpty {
                activeDays += 1
            }

            let overview = activityMonitor.getTodayOverview()
            totalActiveTime += overview.activeTime

            pomodoroSessions += dayEvents.filter { $0.type == .pomodoro }.count

            let productivity = activityMonitor.getProductivityAnalysis(for: date)
            totalProductivity += productivity.productivityScore
        }

        let avgProductivity = activeDays > 0 ? totalProductivity / Double(activeDays) : 0

        return (activeDays, totalActiveTime, pomodoroSessions, avgProductivity)
    }

    private func calculateWeeklyProductivity() -> [Double] {
        let monthDates = getMonthDates()
        var weeklyProductivity: [Double] = []

        // 将月份分成4周
        let weeksInMonth = 4
        let daysPerWeek = monthDates.count / weeksInMonth

        for week in 0..<weeksInMonth {
            let startIndex = week * daysPerWeek
            let endIndex = min(startIndex + daysPerWeek, monthDates.count)
            let weekDates = Array(monthDates[startIndex..<endIndex])

            var weekProductivity: Double = 0
            var validDays = 0

            for date in weekDates {
                let productivity = activityMonitor.getProductivityAnalysis(for: date)
                weekProductivity += productivity.productivityScore
                validDays += 1
            }

            let avgWeekProductivity = validDays > 0 ? weekProductivity / Double(validDays) : 0
            weeklyProductivity.append(avgWeekProductivity)
        }

        return weeklyProductivity
    }

    private func getMonthDates() -> [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth) else {
            return []
        }

        var dates: [Date] = []
        let startDate = monthInterval.start
        let numberOfDays = calendar.range(of: .day, in: .month, for: currentMonth)?.count ?? 30

        for i in 0..<numberOfDays {
            if let date = calendar.date(byAdding: .day, value: i, to: startDate) {
                dates.append(date)
            }
        }

        return dates
    }

    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - 月视图日期单元格
struct MonthDayCell: View {
    let date: Date
    @Binding var selectedDate: Date
    let currentMonth: Date
    let events: [PomodoroEvent]
    let activityStats: [AppUsageStats]

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

    private var hasEvents: Bool {
        !events.isEmpty
    }

    private var hasActivity: Bool {
        !activityStats.isEmpty
    }

    private var dayNumber: String {
        "\(calendar.component(.day, from: date))"
    }

    var body: some View {
        VStack(spacing: 2) {
            // 日期数字
            Text(dayNumber)
                .font(.system(size: 16, weight: isSelected ? .bold : .regular))
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

            // 事件指示器
            HStack(spacing: 2) {
                if hasEvents {
                    ForEach(Array(events.prefix(3)), id: \.id) { event in
                        Circle()
                            .fill(event.type.color)
                            .frame(width: 4, height: 4)
                    }

                    if events.count > 3 {
                        Text("...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                if hasActivity && !hasEvents {
                    Circle()
                        .fill(Color.gray.opacity(0.6))
                        .frame(width: 4, height: 4)
                }
            }
            .frame(height: 8)
        }
        .frame(maxWidth: .infinity, minHeight: 60)
        .background(
            Group {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue)
                } else if isToday {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue, lineWidth: 2)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.1))
                        )
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.clear)
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
        )
        .contentShape(Rectangle())
    }
}