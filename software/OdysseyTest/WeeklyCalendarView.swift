//
//  WeeklyCalendarView.swift
//  OdysseyTest
//
//  Google Calendar-style weekly view
//

import SwiftUI

struct WeeklyCalendarView: View {
    @ObservedObject var calendarManager: CalendarManager
    @State private var currentWeekStart: Date
    @State private var selectedEvent: CalendarEvent?
    
    private let calendar = Calendar.current
    private let hourHeight: CGFloat = 60
    private let hours = Array(0...23)
    
    init(calendarManager: CalendarManager) {
        self.calendarManager = calendarManager
        let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        _currentWeekStart = State(initialValue: weekStart)
    }
    
    var weekDays: [Date] {
        (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: currentWeekStart)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Week navigation header
            weekNavigationHeader
            
            // Week day headers
            weekDayHeaders
            
            // Scrollable weekly grid
            ScrollView {
                weeklyGridView
                    .frame(height: CGFloat(hours.count) * hourHeight)
            }
        }
        .sheet(item: $selectedEvent) { event in
            EditEventView(event: event, calendarManager: calendarManager)
        }
    }
    
    // MARK: - Week Navigation
    
    private var weekNavigationHeader: some View {
        HStack {
            Button {
                moveWeek(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .padding()
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text(monthYearText)
                    .font(.headline)
                Text(isCurrentWeek ? "This Week" : weekRangeText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                moveWeek(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .padding()
            }
            
            Button {
                goToToday()
            } label: {
                Text("Today")
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.trailing)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    private var monthYearText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentWeekStart)
    }
    
    private var weekRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let start = formatter.string(from: weekDays.first!)
        let end = formatter.string(from: weekDays.last!)
        return "\(start) - \(end)"
    }
    
    private var isCurrentWeek: Bool {
        calendar.isDate(currentWeekStart, equalTo: Date(), toGranularity: .weekOfYear)
    }
    
    // MARK: - Week Day Headers
    
    private var weekDayHeaders: some View {
        HStack(spacing: 0) {
            // Time column spacer
            Text("")
                .frame(width: 50)
            
            // Day headers
            ForEach(weekDays, id: \.self) { day in
                VStack(spacing: 4) {
                    Text(dayName(day))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(calendar.component(.day, from: day))")
                        .font(.title3)
                        .fontWeight(isToday(day) ? .bold : .regular)
                        .foregroundColor(isToday(day) ? .white : .primary)
                        .frame(width: 32, height: 32)
                        .background(isToday(day) ? Color.blue : Color.clear)
                        .clipShape(Circle())
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .overlay(
            Divider()
                .frame(maxWidth: .infinity, maxHeight: 1)
                .background(Color.gray.opacity(0.3)),
            alignment: .bottom
        )
    }
    
    // MARK: - Weekly Grid
    
    private var weeklyGridView: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Grid lines
                gridLinesView
                
                // Events overlay
                eventsOverlayView(columnWidth: (geometry.size.width - 50) / 7)
            }
        }
    }
    
    private var gridLinesView: some View {
        VStack(spacing: 0) {
            ForEach(hours, id: \.self) { hour in
                HStack(spacing: 0) {
                    // Time label
                    Text(timeString(for: hour))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .trailing)
                        .padding(.trailing, 8)
                    
                    // Hour row
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: hourHeight)
                        .overlay(
                            // Vertical day separators
                            HStack(spacing: 0) {
                                ForEach(0..<7) { _ in
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 1)
                                    Spacer()
                                }
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 1)
                            }
                        )
                }
                .overlay(
                    Divider()
                        .frame(maxWidth: .infinity, maxHeight: 1)
                        .background(Color.gray.opacity(0.3)),
                    alignment: .top
                )
            }
        }
    }
    
    private func eventsOverlayView(columnWidth: CGFloat) -> some View {
        ForEach(weekDays.indices, id: \.self) { dayIndex in
            let day = weekDays[dayIndex]
            let dayEvents = calendarManager.events(for: day)
            
            ForEach(dayEvents) { event in
                eventBlockView(event: event)
                    .frame(width: columnWidth - 4)
                    .offset(x: 50 + CGFloat(dayIndex) * columnWidth + 2,
                           y: eventYOffset(for: event))
                    .onTapGesture {
                        selectedEvent = event
                    }
            }
        }
    }
    
    private func eventBlockView(event: CalendarEvent) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: event.category.icon)
                    .font(.caption2)
                Text(event.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)
            }
            
            if !event.isAllDay {
                Text(eventTimeString(event: event))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: event.isAllDay ? 24 : eventHeight(for: event), alignment: .top)
        .background(categoryColor(for: event.category).opacity(0.9))
        .foregroundColor(.white)
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(categoryColor(for: event.category), lineWidth: 1)
        )
    }
    
    // MARK: - Helper Functions
    
    private func dayName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }
    
    private func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }
    
    private func timeString(for hour: Int) -> String {
        if hour == 0 {
            return "12 AM"
        } else if hour < 12 {
            return "\(hour) AM"
        } else if hour == 12 {
            return "12 PM"
        } else {
            return "\(hour - 12) PM"
        }
    }
    
    private func eventTimeString(event: CalendarEvent) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: event.date)
    }
    
    private func eventYOffset(for event: CalendarEvent) -> CGFloat {
        if event.isAllDay {
            return 4 // Top of the day
        }
        
        let hour = calendar.component(.hour, from: event.date)
        let minute = calendar.component(.minute, from: event.date)
        return CGFloat(hour) * hourHeight + (CGFloat(minute) / 60.0) * hourHeight
    }
    
    private func eventHeight(for event: CalendarEvent) -> CGFloat {
        if event.isAllDay {
            return 24
        }
        // Default 1-hour duration
        return hourHeight - 4
    }
    
    private func categoryColor(for category: EventCategory) -> Color {
        switch category.color {
        case "blue": return .blue
        case "orange": return .orange
        case "green": return .green
        case "red": return .red
        case "purple": return .purple
        case "cyan": return .cyan
        default: return .gray
        }
    }
    
    private func moveWeek(by weeks: Int) {
        if let newDate = calendar.date(byAdding: .weekOfYear, value: weeks, to: currentWeekStart) {
            currentWeekStart = newDate
        }
    }
    
    private func goToToday() {
        currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
    }
}

#Preview {
    NavigationView {
        WeeklyCalendarView(calendarManager: CalendarManager.shared)
    }
}

