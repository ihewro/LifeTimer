//
//  CalendarView.swift
//  PomodoroTimer
//
//  Created by Developer on 2024.
//

import SwiftUI
import AppKit
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

// MARK: - 可重用的日历导航工具栏组件
struct CalendarNavigationToolbar: View {
    let viewMode: CalendarViewMode
    @Binding var selectedDate: Date

    private let calendar = Calendar.current

    // 根据视图模式计算是否为今天
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

    var body: some View {
        HStack {
            Spacer()
            // 上一个时间段按钮
            Button(action: previousPeriod) {
                Image(systemName: "chevron.left")
            }
            .controlSize(.small)

            // 今天按钮
            Button(action: goToToday) {
                Text("今天")
            }
            .controlSize(.small)
            .disabled(isToday)

            // 下一个时间段按钮
            Button(action: nextPeriod) {
                Image(systemName: "chevron.right")
            }
            .controlSize(.small)
        }
    }

    // MARK: - 导航方法

    /// 跳转到今天
    private func goToToday() {
        selectedDate = Date()
    }

    /// 上一个时间段
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

    /// 下一个时间段
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

struct CalendarView: View {
    @EnvironmentObject var eventManager: EventManager
    @EnvironmentObject var activityMonitor: ActivityMonitorManager
    @State private var selectedDate = Date()
    @State private var currentViewMode: CalendarViewMode = .day
    @State private var selectedEvent: PomodoroEvent?
    @State private var showingAddEvent = false
    @State private var draggedEvent: PomodoroEvent?
    @State private var dragOffset: CGSize = .zero
    @State private var searchText = ""
    
    private let calendar = Calendar.current
    
    var body: some View {
        Group {
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
                    .environmentObject(activityMonitor)
                    .background(Color(NSColor.controlBackgroundColor))

                case .week:
                    WeekView(selectedDate: $selectedDate)
                        .environmentObject(eventManager)
                        .environmentObject(activityMonitor)
                        .background(Color(NSColor.controlBackgroundColor))

                case .month:
                    MonthView(viewMode: currentViewMode, selectedDate: $selectedDate)
                        .environmentObject(eventManager)
                        .environmentObject(activityMonitor)
                        .background(Color(NSColor.controlBackgroundColor))
            }
        }
        .sheet(isPresented: $showingAddEvent) {
            EventEditView(event: PomodoroEvent(
                title: "新事件",
                startTime: selectedDate,
                endTime: Calendar.current.date(byAdding: .hour, value: 1, to: selectedDate) ?? selectedDate,
                type: .custom
            ), onSave: { _ in
                showingAddEvent = false
            }, onDelete: {
                showingAddEvent = false
            })
                .environmentObject(eventManager)
        }
        .toolbar {
            // 左侧：添加事件按钮
            ToolbarItem(placement: .navigation) {
                Button(action: {
                    showingAddEvent = true
                }) {
                    Image(systemName: "plus")
                }
                .help("添加事件")
            }

            // 中间：完整的工具栏布局
            ToolbarItem(placement: .principal) {
                HStack {
                    // 视图模式选择器
                    Picker("视图模式", selection: $currentViewMode) {
                        ForEach(CalendarViewMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)

                }
            }
            // 中间：占位符确保 toolbar 铺满宽度
            ToolbarItem(placement: .principal) {
                Spacer()
            }
            ToolbarItem(placement: .confirmationAction) {
                // 搜索框
                HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 13))

                        TextField("搜索事件", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13))
                            .frame(width: 140)
                }
            }
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
    @EnvironmentObject var activityMonitor: ActivityMonitorManager
    private let calendar = Calendar.current
    private let hourHeight: CGFloat = 60
    
    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                // 左侧时间轴区域
                TimelineView(
                    selectedDate: $selectedDate,
                    selectedEvent: $selectedEvent,
                    showingAddEvent: $showingAddEvent,
                    draggedEvent: $draggedEvent,
                    dragOffset: $dragOffset,
                    hourHeight: hourHeight
                )
                .environmentObject(eventManager)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.controlBackgroundColor))

                // 右侧面板 - 恢复日历模块和事件详情
                VStack(spacing: 0) {
                    MiniCalendarView(viewMode: .day, selectedDate: $selectedDate)
                        .frame(height: 200)
                        .padding()
                    Divider()
                    DayStatsPanel(selectedDate: $selectedDate)
                        .environmentObject(eventManager)
                        .environmentObject(activityMonitor)
                        .frame(maxHeight: .infinity)
                }
                .frame(width: 300)
                .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

// MARK: - 时间轴视图
struct TimelineView: View {
    @Binding var selectedDate: Date
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
        VStack(alignment: .leading, spacing: 0) {
            // 日期显示区域（只显示日期信息，不显示导航按钮）
            DateDisplayOnly(selectedDate: $selectedDate)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // 时间轴内容
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
            .padding(.leading, 0)
            .contentShape(Rectangle())
            .onTapGesture { location in
                // 简化的点击处理：点击空白区域取消选中事件
                selectedEvent = nil
            }
            .gesture(
                DragGesture(minimumDistance: 5)
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
        }
    }

    // --- 新增：事件并列排布算法 ---
    private func computeEventColumns(events: [PomodoroEvent]) -> [(PomodoroEvent, Int, Int)] {
        // 按开始时间排序
        let sorted = events.sorted { $0.startTime < $1.startTime }
        var result: [(PomodoroEvent, Int, Int)] = []
        var active: [(PomodoroEvent, Int)] = [] // (event, column)

        for event in sorted {
            // 计算当前事件的视觉位置（考虑最小高度）
            let eventVisualBounds = getEventVisualBounds(event)

            // 移除已结束的事件（考虑视觉边界而不仅仅是时间边界）
            active.removeAll { activeEvent in
                let activeVisualBounds = getEventVisualBounds(activeEvent.0)
                return activeVisualBounds.maxY <= eventVisualBounds.minY
            }

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
            let eventVisualBounds = getEventVisualBounds(event)
            let overlapping = result.filter { otherEvent in
                let otherVisualBounds = getEventVisualBounds(otherEvent.0)
                // 检查视觉边界是否重叠
                return eventVisualBounds.minY < otherVisualBounds.maxY &&
                       eventVisualBounds.maxY > otherVisualBounds.minY
            }
            let maxCol = overlapping.map { $0.2 }.max() ?? 1
            eventToMaxCol[event.id] = maxCol
        }
        return result.map { (event, col, _) in
            (event, col, eventToMaxCol[event.id] ?? 1)
        }
    }

    // 计算事件的视觉边界（考虑最小高度）
    private func getEventVisualBounds(_ event: PomodoroEvent) -> (minY: CGFloat, maxY: CGFloat) {
        let startHour = calendar.component(.hour, from: event.startTime)
        let startMinute = calendar.component(.minute, from: event.startTime)
        let endHour = calendar.component(.hour, from: event.endTime)
        let endMinute = calendar.component(.minute, from: event.endTime)
        let startY = CGFloat(startHour) * hourHeight + CGFloat(startMinute) * hourHeight / 60
        let endY = CGFloat(endHour) * hourHeight + CGFloat(endMinute) * hourHeight / 60
        let actualHeight = endY - startY
        let visualHeight = max(20, actualHeight) // 最小高度20
        return (startY, startY + visualHeight)
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
    @State private var showingPopover = false

    // 性能优化：缓存计算结果
    private let calendar = Calendar.current
    @State private var isDragging = false
    @State private var dragStartOffset: CGSize = .zero
    @State private var lastUpdateTime: Date = Date()

    // 拖拽阈值，避免意外触发 - 增加阈值以避免与双击冲突
    private let dragThreshold: CGFloat = 10.0
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
        HStack(alignment: .top, spacing: 0) {
            // 左侧深色border - 与右侧内容区域高度保持一致
            Rectangle()
                .fill(event.type.color)
                .frame(width: 4)

            // 右侧内容区域
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(selectedEvent?.id == event.id ? .white : event.type.color)
                    .lineLimit(2)
                Text(event.formattedTimeRange)
                    .font(.caption2)
                    .foregroundColor(selectedEvent?.id == event.id ? .white.opacity(0.8) : event.type.color.opacity(0.7))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, minHeight: max(20, position.height), alignment: .topLeading)
            .background(
                selectedEvent?.id == event.id
                    ? event.type.color
                    : event.type.color.opacity(0.2)
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .frame(width: width, height: max(20, position.height))
        .position(x: x + width / 2, y: position.y + position.height / 2)
        .offset(draggedEvent?.id == event.id ? dragOffset : .zero)
        .animation(.easeInOut(duration: 0.2), value: selectedEvent?.id == event.id)
            .onTapGesture(count: 2) {
                showingPopover = true
            }
            .simultaneousGesture(
                    TapGesture()
                        .onEnded { _ in
                            selectedEvent = event
                        }
                )
            .popover(isPresented: $showingPopover, arrowEdge: .trailing) {
                EventDetailPopover(event: event, onSave: { updatedEvent in
                    showingPopover = false
                    // 更新选中事件以同步右侧面板
                    if selectedEvent?.id == event.id {
                        selectedEvent = updatedEvent
                    }
                }, onDelete: {
                    showingPopover = false
                    selectedEvent = nil
                })
                .environmentObject(eventManager)
                .frame(width: 300)
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

            // 更新选中事件以同步右侧面板
            if selectedEvent?.id == event.id {
                selectedEvent = updatedEvent
            }
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
    let viewMode: CalendarViewMode
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
        VStack(spacing: 6) {
            // 导航按钮组
            CalendarNavigationToolbar(
                viewMode: viewMode,
                selectedDate: $selectedDate
            )

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
            LazyVGrid(columns: columns, spacing: 2) {
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
                .font(.caption2)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor({
                    if isSelected {
                        return .white
                    } else if isToday {
                        return .accentColor // 使用系统强调色
                    } else if isCurrentMonth {
                        return .primary
                    } else {
                        return .secondary
                    }
                }())
                .frame(width: 24, height: 24)
                .background(
                    Group {
                        if isSelected {
                            // 选中状态使用系统强调色背景
                            Color.accentColor
                        } else {
                            // 未选中状态无背景色
                            Color.clear
                        }
                    }
                )
                .clipShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 当日统计面板
struct DayStatsPanel: View {
    @Binding var selectedDate: Date
    @EnvironmentObject var eventManager: EventManager
    @EnvironmentObject var activityMonitor: ActivityMonitorManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 当日活动概览
                dayActivityOverview

                // 当日热门应用
                dayTopApps

                Spacer()
            }
        }
    }

    // 当日活动概览
    private var dayActivityOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("活动概览")
                .font(.subheadline)
                .fontWeight(.medium)

            // 计算当日统计
            let dayStats = calculateDayStats()

            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "timer")
                        .foregroundColor(.blue)
                    Text("活跃时间")
                    Spacer()
                    Text(formatTime(dayStats.totalActiveTime))
                        .fontWeight(.medium)
                }

                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(.green)
                    Text("番茄时钟")
                    Spacer()
                    Text("\(dayStats.pomodoroSessions)")
                        .fontWeight(.medium)
                }

                HStack {
                    Image(systemName: "app.badge")
                        .foregroundColor(.orange)
                    Text("应用切换")
                    Spacer()
                    Text("\(dayStats.appSwitches)")
                        .fontWeight(.medium)
                }
            }
            .font(.caption)
        }
        .padding()
    }

    // 当日热门应用
    private var dayTopApps: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("热门应用")
                .font(.subheadline)
                .fontWeight(.medium)

            let topApps = getTopApps()

            if topApps.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "app.dashed")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                    Text("暂无应用使用记录")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(topApps.enumerated()), id: \.offset) { index, appStat in
                        HStack {
                            // 排名
                            Text("\(index + 1)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .frame(width: 16)

                            // 应用名称
                            Text(appStat.appName)
                                .font(.caption)
                                .lineLimit(1)

                            Spacer()

                            // 使用时长
                            Text(formatTime(appStat.totalTime))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
    }

    // 计算当日统计数据
    private func calculateDayStats() -> (totalActiveTime: TimeInterval, pomodoroSessions: Int, appSwitches: Int) {
        // 获取当日事件
        let dayEvents = eventManager.eventsForDate(selectedDate)

        // 计算活跃时间（番茄时间+正计时间+自定义事件，不包含休息）
        var totalActiveTime: TimeInterval = 0
        for event in dayEvents {
            if event.type == .pomodoro || event.type == .countUp || event.type == .custom {
                totalActiveTime += event.endTime.timeIntervalSince(event.startTime)
            }
        }

        // 计算番茄时钟个数
        let pomodoroSessions = dayEvents.filter { $0.type == .pomodoro }.count

        // 获取应用切换次数
        let overview = activityMonitor.getTodayOverview()
        let appSwitches = overview.appSwitches

        return (totalActiveTime, pomodoroSessions, appSwitches)
    }

    // 获取当日热门应用Top5
    private func getTopApps() -> [AppUsageStats] {
        let appStats = activityMonitor.getAppUsageStats(for: selectedDate)
        return Array(appStats.prefix(5))
    }

    // 格式化时间显示
    private func formatTime(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60

        if hours > 0 {
            return "\(hours)h\(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}



// MARK: - 周视图
struct WeekView: View {
    @Binding var selectedDate: Date
    @EnvironmentObject var eventManager: EventManager
    @EnvironmentObject var activityMonitor: ActivityMonitorManager
    @State private var selectedEvent: PomodoroEvent?
    @State private var showingAddEvent = false

    // 拖拽选择状态
    @State private var isSelecting = false
    @State private var selectionStart: CGPoint?
    @State private var selectionEnd: CGPoint?
    @State private var selectionDate: Date?

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
                VStack(alignment: .leading, spacing: 0) {
                    // 日期显示区域（只显示日期信息，不显示导航按钮）
                    DateDisplayOnly(selectedDate: $selectedDate)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()

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
                    MiniCalendarView(viewMode: .week, selectedDate: $selectedDate)
                        .frame(height: 200)
                        .padding()

                    Divider()

                    // 周统计信息
                    weekStatsPanel
                        .frame(maxHeight: .infinity)
                }
                .frame(width: 300)
                .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
            }
        }
        .sheet(isPresented: $showingAddEvent) {
            EventEditView(event: PomodoroEvent(
                title: "新事件",
                startTime: selectedDate,
                endTime: Calendar.current.date(byAdding: .hour, value: 1, to: selectedDate) ?? selectedDate,
                type: .custom
            ), onSave: { _ in
                showingAddEvent = false
            }, onDelete: {
                showingAddEvent = false
            })
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
            ForEach(Array(weekDates.enumerated()), id: \.element) { index, date in
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
            ForEach(Array(weekDates.enumerated()), id: \.element) { index, date in
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        // 移除横线，只保留空间占位
                        ForEach(Array(0...23), id: \.self) { hour in
                            Rectangle()
                                .fill(Color.clear)
                                .frame(height: hourHeight)
                                .frame(maxWidth: .infinity)
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

                                // 选择区域覆盖层（只在当前选择的日期显示）
                                if isSelecting, let start = selectionStart, let end = selectionEnd, selectionDate == date {
                                    WeekSelectionOverlay(start: start, end: end, containerWidth: dayGeometry.size.width)
                                }
                            }
                        }
                    )
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // 点击取消选中事件
                        selectedEvent = nil
                    }
                    .gesture(
                        DragGesture(minimumDistance: 5)
                            .onChanged { value in
                                // 开始拖拽选择
                                if selectionStart == nil {
                                    selectionStart = value.startLocation
                                    selectionDate = date
                                    isSelecting = true
                                }

                                // 只有在同一天内才更新选择
                                if selectionDate == date {
                                    selectionEnd = value.location
                                }
                            }
                            .onEnded { value in
                                if isSelecting && selectionDate == date {
                                    createEventFromWeekSelection(date: date)
                                }
                                resetSelection()
                            }
                    )

                    // 添加竖线分隔（除了最后一列）
                    if index < weekDates.count - 1 {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(width: 1)
                    }
                }
            }
        }
    }

    // 周统计面板
    private var weekStatsPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Text("本周统计")
                //     .font(.headline)
                //     .padding(.horizontal)

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

    // 事件并列排布算法（使用视觉边界检测）
    private func computeEventColumns(events: [PomodoroEvent]) -> [(PomodoroEvent, Int, Int)] {
        // 按开始时间排序
        let sorted = events.sorted { $0.startTime < $1.startTime }
        var result: [(PomodoroEvent, Int, Int)] = []
        var active: [(PomodoroEvent, Int)] = [] // (event, column)

        for event in sorted {
            // 计算当前事件的视觉位置（考虑最小高度）
            let eventVisualBounds = getEventVisualBounds(event)

            // 移除已结束的事件（考虑视觉边界而不仅仅是时间边界）
            active.removeAll { activeEvent in
                let activeVisualBounds = getEventVisualBounds(activeEvent.0)
                return activeVisualBounds.maxY <= eventVisualBounds.minY
            }

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
            let eventVisualBounds = getEventVisualBounds(event)
            let overlapping = result.filter { otherEvent in
                let otherVisualBounds = getEventVisualBounds(otherEvent.0)
                // 检查视觉边界是否重叠
                return eventVisualBounds.minY < otherVisualBounds.maxY &&
                       eventVisualBounds.maxY > otherVisualBounds.minY
            }
            let maxCol = overlapping.map { $0.2 }.max() ?? 1
            eventToMaxCol[event.id] = maxCol
        }
        return result.map { (event, col, _) in
            (event, col, eventToMaxCol[event.id] ?? 1)
        }
    }

    // 计算事件的视觉边界（考虑最小高度）- 周视图版本
    private func getEventVisualBounds(_ event: PomodoroEvent) -> (minY: CGFloat, maxY: CGFloat) {
        let startHour = calendar.component(.hour, from: event.startTime)
        let startMinute = calendar.component(.minute, from: event.startTime)
        let endHour = calendar.component(.hour, from: event.endTime)
        let endMinute = calendar.component(.minute, from: event.endTime)
        let startY = CGFloat(startHour) * hourHeight + CGFloat(startMinute) * hourHeight / 60
        let endY = CGFloat(endHour) * hourHeight + CGFloat(endMinute) * hourHeight / 60
        let actualHeight = endY - startY
        let visualHeight = max(20, actualHeight) // 最小高度20
        return (startY, startY + visualHeight)
    }

    // 从周视图选择创建事件
    private func createEventFromWeekSelection(date: Date) {
        guard let start = selectionStart, let end = selectionEnd else { return }

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

        guard let startTime = calendar.date(bySettingHour: startHour, minute: startMinute, second: 0, of: date),
              let endTime = calendar.date(bySettingHour: endHour, minute: endMinute, second: 0, of: date) else {
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
        selectionDate = nil
        isSelecting = false
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

    @State private var showingPopover = false
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @EnvironmentObject var eventManager: EventManager

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

        HStack(spacing: 0) {
            // 左侧深色border - 确保高度与容器一致
            Rectangle()
                .fill(event.type.color)
                .frame(width: 3, height: position.height)

            // 右侧内容区域
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(selectedEvent?.id == event.id ? .white : event.type.color)
                    .lineLimit(1)

                if position.height > 30 {
                    Text(event.formattedTimeRange)
                        .font(.caption2)
                        .foregroundColor(selectedEvent?.id == event.id ? .white.opacity(0.8) : event.type.color.opacity(0.7))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                selectedEvent?.id == event.id
                    ? event.type.color
                    : event.type.color.opacity(0.2)
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .frame(width: width, height: position.height)
        .position(x: x + width / 2, y: position.y + position.height / 2)
        .offset(dragOffset)
        .animation(.easeInOut(duration: 0.2), value: selectedEvent?.id == event.id)
        .onTapGesture(count: 2) {
            showingPopover = true
        }
       .simultaneousGesture(
            TapGesture()
                .onEnded { _ in
                    selectedEvent = event
                }
        )
        .popover(isPresented: $showingPopover, arrowEdge: .trailing) {
            EventDetailPopover(
                event: event,
                onSave: { updatedEvent in
                    showingPopover = false
                    // 更新选中事件以同步右侧面板
                    if selectedEvent?.id == event.id {
                        selectedEvent = updatedEvent
                    }
                },
                onDelete: {
                    selectedEvent = nil
                    showingPopover = false
                }
            )
            .environmentObject(eventManager)
            .frame(width: 350, height: 400)
        }
        .contextMenu {
            Button(role: .destructive) {
                eventManager.removeEvent(event)
                if selectedEvent?.id == event.id {
                    selectedEvent = nil
                }
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
        .gesture(
            DragGesture(minimumDistance: 10.0)
                .onChanged { value in
                    isDragging = true
                    dragOffset = value.translation
                    selectedEvent = event
                }
                .onEnded { value in
                    // 计算新的时间
                    let timeChange = value.translation.height / hourHeight * 3600 // 转换为秒
                    let roundedTimeChange = round(timeChange / 300) * 300 // 四舍五入到5分钟

                    if abs(roundedTimeChange) > 0 {
                        let newStartTime = event.startTime.addingTimeInterval(roundedTimeChange)
                        let duration = event.endTime.timeIntervalSince(event.startTime)
                        let newEndTime = newStartTime.addingTimeInterval(duration)

                        // 更新事件
                        var updatedEvent = event
                        updatedEvent.startTime = newStartTime
                        updatedEvent.endTime = newEndTime
                        eventManager.updateEvent(updatedEvent)

                        // 更新选中事件以同步右侧面板
                        if selectedEvent?.id == event.id {
                            selectedEvent = updatedEvent
                        }
                    }

                    // 重置拖拽状态
                    isDragging = false
                    dragOffset = .zero
                }
        )
    }
}

// MARK: - 月视图
struct MonthView: View {
    let viewMode: CalendarViewMode
    @Binding var selectedDate: Date
    @EnvironmentObject var eventManager: EventManager
    @EnvironmentObject var activityMonitor: ActivityMonitorManager
    @State private var selectedEvent: PomodoroEvent?
    @State private var showingAddEvent = false
    @State private var currentMonth = Date()

    // Popover 状态管理
    @State private var showingDayEventsPopover = false
    @State private var showingEventDetailPopover = false
    @State private var popoverDate: Date = Date()
    @State private var popoverEvent: PomodoroEvent?

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

                    Divider()

                    // 星期标题
                    weekdayHeaderView
                        .frame(height: 30)

                    Divider()

                    // 月历网格
                    monthGridView
                        .frame(maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity)

                // 右侧面板
                VStack(spacing: 0) {
                    VStack(spacing: 6) {
                        CalendarNavigationToolbar(
                            viewMode: viewMode,
                            selectedDate: $selectedDate
                        )
                        .padding()
                        .padding(.top, 2)

                        // 月度统计
                        monthStatsPanel
                            .frame(maxHeight: .infinity)
                    }
                }
                .frame(width: 300)
                .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
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
            ), onSave: { _ in
                showingAddEvent = false
            }, onDelete: {
                showingAddEvent = false
            })
                .environmentObject(eventManager)
        }
    }

    // 月份导航视图
    private var monthNavigationView: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(monthFormatter.string(from: currentMonth))
                .font(.title)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // 星期标题视图
    private var weekdayHeaderView: some View {
        HStack(spacing: 0) {
            ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { day in
                Text(day)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
    }

    // 月历网格视图
    private var monthGridView: some View {
        GeometryReader { geometry in
            let availableHeight = geometry.size.height
            let cellHeight = availableHeight / 6 // 6 rows for calendar weeks

            LazyVGrid(columns: columns, spacing: 1) {
                ForEach(monthDays, id: \.self) { date in
                    MonthDayCell(
                        date: date,
                        selectedDate: $selectedDate,
                        currentMonth: currentMonth,
                        events: eventManager.eventsForDate(date),
                        activityStats: activityMonitor.getAppUsageStats(for: date),
                        cellHeight: cellHeight
                    )
                .onTapGesture {
                    selectedDate = date
                    popoverDate = date
                    showingDayEventsPopover = true
                }
                .onLongPressGesture {
                    selectedDate = date
                    showingAddEvent = true
                }
                .popover(isPresented: Binding<Bool>(
                    get: { showingDayEventsPopover && Calendar.current.isDate(popoverDate, inSameDayAs: date) },
                    set: { newValue in
                        if !newValue {
                            showingDayEventsPopover = false
                        }
                    }
                )) {
                    DayEventsPopover(
                        date: popoverDate,
                        selectedEvent: $popoverEvent,
                        showingEventDetail: $showingEventDetailPopover
                    )
                    .environmentObject(eventManager)
                }
            }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 0)
    }



    // 月度统计面板
    private var monthStatsPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
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
    let cellHeight: CGFloat

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

    // 根据单元格高度动态计算可显示的事件数量
    private var maxVisibleEvents: Int {
        // 预留空间：日期数字区域(~20pt) + 顶部padding(2pt) + 底部padding(2pt) + Spacer
        // 每个事件行大约需要 14pt (字体10pt + padding 4pt)
        // "还有X项"指示器大约需要 12pt
        let reservedSpace: CGFloat = 26 // 日期数字和padding
        let eventRowHeight: CGFloat = 16 // 增加事件行高度以适应更大字体
        let moreIndicatorHeight: CGFloat = 14

        let availableForEvents = cellHeight - reservedSpace

        if events.count <= 1 {
            return max(1, Int(availableForEvents / eventRowHeight))
        } else {
            // 如果有多个事件，需要为"还有X项"指示器预留空间
            let spaceForEventsAndIndicator = availableForEvents - moreIndicatorHeight
            return max(1, Int(spaceForEventsAndIndicator / eventRowHeight))
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            // 顶部：日期数字（右上角）
            HStack {
                Spacer()
                Text(dayNumber)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor({
                        if isToday {
                            return .accentColor
                        } else if isCurrentMonth {
                            return .primary
                        } else {
                            return .secondary
                        }
                    }())
            }
            .padding(.top, 2)
            .padding(.trailing, 4)

            // 事件列表区域
            VStack(alignment: .leading, spacing: 2) {
                if hasEvents {
                    // 动态显示事件数量
                    ForEach(Array(events.prefix(maxVisibleEvents)), id: \.id) { event in
                        eventRow(for: event)
                    }

                    if events.count > maxVisibleEvents {
                        Text("还有\(events.count - maxVisibleEvents)项")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.secondary.opacity(0.1))
                            )
                    }
                } else if hasActivity {
                    Circle()
                        .fill(Color.gray.opacity(0.6))
                        .frame(width: 4, height: 4)
                        .padding(.leading, 2)
                }
            }
            .padding(.horizontal, 3)

            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: cellHeight, maxHeight: cellHeight)
        .background(
            Rectangle()
                .fill(Color.clear)
                .overlay(
                    Rectangle()
                        .stroke(Color.gray.opacity(0.15), lineWidth: 0.5)
                )
        )
        .contentShape(Rectangle())
    }

    // 事件行视图
    private func eventRow(for event: PomodoroEvent) -> some View {
        HStack(alignment: .center, spacing: 3) {
            Circle()
                .fill(event.type.color)
                .frame(width: 4, height: 4)

            Text(event.title)
                .font(.caption)  // 从 .system(size: 9) 升级到 .caption (约11pt)
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)  // 确保左对齐

            Spacer(minLength: 0)  // 确保文本左对齐
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 3)
                .fill(event.type.color.opacity(0.1))
        )
    }
}

// MARK: - 事件详情弹窗
struct EventDetailPopover: View {
    let event: PomodoroEvent
    let onSave: (PomodoroEvent) -> Void
    let onDelete: () -> Void

    @EnvironmentObject var eventManager: EventManager
    @State private var title: String
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var eventType: PomodoroEvent.EventType
    @State private var isEditing = false

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
        VStack(alignment: .leading, spacing: 16) {
            // 标题栏
            HStack {
                Text("事件详情")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button(isEditing ? "完成" : "编辑") {
                    if isEditing {
                        saveEvent()
                    }
                    isEditing.toggle()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            Divider()

            if isEditing {
                // 编辑模式
                VStack(alignment: .leading, spacing: 12) {
                    // 事件标题
                    VStack(alignment: .leading, spacing: 4) {
                        Text("标题")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("事件标题", text: $title)
                            .textFieldStyle(.roundedBorder)
                    }

                    // 事件类型
                    VStack(alignment: .leading, spacing: 4) {
                        Text("类型")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("事件类型", selection: $eventType) {
                            ForEach(PomodoroEvent.EventType.allCases, id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // 时间设置
                    VStack(alignment: .leading, spacing: 8) {
                        Text("时间")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("开始")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                DatePicker("", selection: $startTime, displayedComponents: [.hourAndMinute])
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("结束")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                DatePicker("", selection: $endTime, displayedComponents: [.hourAndMinute])
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                            }
                        }
                    }
                }
            } else {
                // 显示模式
                VStack(alignment: .leading, spacing: 12) {
                    // 事件标题
                    VStack(alignment: .leading, spacing: 4) {
                        Text("标题")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(event.title)
                            .font(.body)
                            .fontWeight(.medium)
                    }

                    // 事件类型
                    VStack(alignment: .leading, spacing: 4) {
                        Text("类型")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            Circle()
                                .fill(event.type.color)
                                .frame(width: 12, height: 12)
                            Text(event.type.displayName)
                                .font(.body)
                        }
                    }

                    // 时间信息
                    VStack(alignment: .leading, spacing: 4) {
                        Text("时间")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("开始：\(formatTime(event.startTime))")
                                .font(.body)
                            Text("结束：\(formatTime(event.endTime))")
                                .font(.body)
                            Text("时长：\(formatDuration(event.endTime.timeIntervalSince(event.startTime)))")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Spacer()

            // 底部按钮
            HStack {
                Button("删除", role: .destructive) {
                    eventManager.removeEvent(event)
                    onDelete()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
        onSave(updatedEvent)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60

        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
}

// MARK: - 仅日期显示组件
struct DateDisplayOnly: View {
    @Binding var selectedDate: Date
    private let calendar = Calendar.current

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        return formatter
    }()

    private let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()

    private let lunarFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .chinese)
        formatter.dateFormat = "MMMMd"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()

    var body: some View {
        // 只显示日期信息，不显示导航按钮
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(dateFormatter.string(from: selectedDate))
                    .font(.title)
                    .fontWeight(.semibold)

                Text(weekdayFormatter.string(from: selectedDate))
                    .font(.title2)
                    .foregroundColor(.secondary)
            }

            Text(lunarFormatter.string(from: selectedDate))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}


// MARK: - VisualEffectView for macOS
#if os(macOS)
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }

    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}
#endif

// MARK: - 周视图选择覆盖层
struct WeekSelectionOverlay: View {
    let start: CGPoint
    let end: CGPoint
    let containerWidth: CGFloat

    var body: some View {
        let rect = CGRect(
            x: 0,
            y: min(start.y, end.y),
            width: containerWidth,
            height: max(10, abs(end.y - start.y)) // 最小高度
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

// MARK: - 日期事件列表 Popover
struct DayEventsPopover: View {
    let date: Date
    @Binding var selectedEvent: PomodoroEvent?
    @Binding var showingEventDetail: Bool
    @EnvironmentObject var eventManager: EventManager

    // 预计算的数据，避免重复计算
    private var dayEvents: [PomodoroEvent] {
        eventManager.eventsForDate(date)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 EEEE"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 日期标题
            Text(formattedDate)
                .font(.headline)
                .fontWeight(.semibold)

            if dayEvents.isEmpty {
                // 空状态 - 简化版本
                emptyStateView
            } else {
                // 事件列表 - 优化版本
                eventListView
            }
        }
        .padding()
        .frame(width: 280)
    }

    // 空状态视图 - 预构建避免重复创建
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.system(size: 24))
                .foregroundColor(.secondary)
            Text("当日无事件")
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    // 事件列表视图 - 优化性能
    private var eventListView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(dayEvents, id: \.id) { event in
                    OptimizedEventRowView(
                        event: event,
                        selectedEvent: $selectedEvent,
                        showingEventDetail: $showingEventDetail
                    )
                    .environmentObject(eventManager)
                }
            }
        }
        .frame(maxHeight: 300)
    }
}

// MARK: - 优化的事件行视图
struct OptimizedEventRowView: View {
    let event: PomodoroEvent
    @Binding var selectedEvent: PomodoroEvent?
    @Binding var showingEventDetail: Bool
    @EnvironmentObject var eventManager: EventManager

    // 预计算的属性，避免重复计算
    private var formattedDuration: String {
        let duration = event.endTime.timeIntervalSince(event.startTime)
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60

        if hours > 0 {
            return "\(hours)h\(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // 事件类型指示器
            Circle()
                .fill(event.type.color)
                .frame(width: 12, height: 12)

            // 事件信息
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.callout)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(event.formattedTimeRange)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 时长 - 使用预计算的值
            Text(formattedDuration)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
        )
        .contentShape(Rectangle()) // 确保整个区域都可以点击
        .onTapGesture {
            // 立即响应，无延迟
            selectedEvent = event
            showingEventDetail = true
        }
        .buttonStyle(PlainButtonStyle()) // 避免按钮样式干扰
        .popover(
            isPresented: Binding<Bool>(
                get: { showingEventDetail && selectedEvent?.id == event.id },
                set: { newValue in
                    if !newValue {
                        showingEventDetail = false
                        selectedEvent = nil
                    }
                }
            ),
            attachmentAnchor: .point(.trailing),
            arrowEdge: .trailing
        ) {
            // 事件详情popover
            if let selectedEvent = selectedEvent, selectedEvent.id == event.id {
                EventDetailPopover(
                    event: selectedEvent,
                    onSave: { updatedEvent in
                        // 更新事件
                        eventManager.updateEvent(updatedEvent)
                        showingEventDetail = false
                        self.selectedEvent = nil
                    },
                    onDelete: {
                        // 删除事件
                        eventManager.removeEvent(selectedEvent)
                        showingEventDetail = false
                        self.selectedEvent = nil
                    }
                )
                .frame(width: 300)
                .environmentObject(eventManager)
            }
        }
    }
}


