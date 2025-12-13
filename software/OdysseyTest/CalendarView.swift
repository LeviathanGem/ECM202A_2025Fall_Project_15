//
//  CalendarView.swift
//  OdysseyTest
//
//  Calendar and agenda management view
//

import SwiftUI

struct CalendarView: View {
    @ObservedObject private var calendarManager = CalendarManager.shared
    @State private var showingAddEvent = false
    @State private var selectedFilter: EventFilter = .all
    @State private var selectedEvent: CalendarEvent?
    @State private var viewMode: ViewMode = .list
    
    enum ViewMode: String, CaseIterable {
        case week = "Week"
        case list = "List"
        
        var icon: String {
            switch self {
            case .week: return "calendar"
            case .list: return "list.bullet"
            }
        }
    }
    
    enum EventFilter: String, CaseIterable {
        case all = "All"
        case upcoming = "Upcoming"
        case past = "Past"
        case completed = "Completed"
    }
    
    var filteredEvents: [CalendarEvent] {
        switch selectedFilter {
        case .all:
            return calendarManager.events
        case .upcoming:
            return calendarManager.upcomingEvents()
        case .past:
            return calendarManager.pastEvents()
        case .completed:
            return calendarManager.completedEvents()
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // View mode toggle
            viewModeToggle
            
            // Content based on view mode
            if viewMode == .week {
                WeeklyCalendarView(calendarManager: calendarManager)
            } else {
                listView
            }
        }
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddEvent = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
            }
            
            if !calendarManager.events.isEmpty && viewMode == .list {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
        }
        .sheet(isPresented: $showingAddEvent) {
            AddEventView(calendarManager: calendarManager)
        }
        .sheet(item: $selectedEvent) { event in
            EditEventView(event: event, calendarManager: calendarManager)
        }
    }
    
    // MARK: - View Mode Toggle
    
    private var viewModeToggle: some View {
        HStack(spacing: 0) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewMode = mode
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: mode.icon)
                            .font(.subheadline)
                        Text(mode.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(viewMode == mode ? Color.blue : Color.clear)
                    .foregroundColor(viewMode == mode ? .white : .primary)
                }
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // MARK: - List View
    
    private var listView: some View {
        VStack(spacing: 0) {
            // Filter picker
            Picker("Filter", selection: $selectedFilter) {
                ForEach(EventFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Events list
            if filteredEvents.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(filteredEvents) { event in
                        EventRowView(event: event) {
                            selectedEvent = event
                        } onToggleComplete: {
                            calendarManager.toggleCompletion(for: event)
                        }
                    }
                    .onDelete { indexSet in
                        calendarManager.deleteEvents(at: indexSet)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar")
                .font(.system(size: 70))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Events")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Tap the + button to add your first event")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                showingAddEvent = true
            } label: {
                Label("Add Event", systemImage: "plus.circle.fill")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Event Row View

struct EventRowView: View {
    let event: CalendarEvent
    let onTap: () -> Void
    let onToggleComplete: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 15) {
                // Category icon
                Image(systemName: event.category.icon)
                    .font(.title2)
                    .foregroundColor(categoryColor)
                    .frame(width: 40)
                
                // Event details
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .strikethrough(event.isCompleted)
                    
                    Text(event.formattedDate)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if !event.notes.isEmpty {
                        Text(event.notes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Status indicators
                VStack(spacing: 5) {
                    if event.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else if event.isUpcoming {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.orange)
                    } else if event.isPast {
                        Image(systemName: "clock.badge.xmark")
                            .foregroundColor(.gray)
                    }
                    
                    Text(event.category.rawValue)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
        }
        .swipeActions(edge: .leading) {
            Button {
                onToggleComplete()
            } label: {
                Label(event.isCompleted ? "Undo" : "Complete", 
                      systemImage: event.isCompleted ? "arrow.uturn.backward" : "checkmark")
            }
            .tint(event.isCompleted ? .orange : .green)
        }
    }
    
    private var categoryColor: Color {
        switch event.category.color {
        case "blue": return .blue
        case "orange": return .orange
        case "green": return .green
        case "red": return .red
        case "purple": return .purple
        case "cyan": return .cyan
        default: return .gray
        }
    }
}

// MARK: - Add Event View

struct AddEventView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var calendarManager: CalendarManager
    
    @State private var title = ""
    @State private var notes = ""
    @State private var date = Date()
    @State private var endDate = Date().addingTimeInterval(60 * 30)
    @State private var isAllDay = false
    @State private var category: EventCategory = .wellness
    
    var body: some View {
        NavigationView {
            Form {
                Section("Event Details") {
                    TextField("Title", text: $title)
                    
                    TextField("Notes (Optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Date & Time") {
                    DatePicker("Start", selection: $date, displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                    
                    if !isAllDay {
                        DatePicker("End", selection: $endDate, in: date..., displayedComponents: [.date, .hourAndMinute])
                    }
                    
                    Toggle("All Day", isOn: $isAllDay)
                }
                
                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(EventCategory.allCases, id: \.self) { category in
                            Label(category.rawValue, systemImage: category.icon)
                                .tag(category)
                        }
                    }
                }
            }
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        let normalizedEnd = isAllDay ? nil : max(endDate, date)
                        let event = CalendarEvent(
                            title: title,
                            notes: notes,
                            date: date,
                            endDate: normalizedEnd,
                            isAllDay: isAllDay,
                            category: category
                        )
                        calendarManager.addEvent(event)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Edit Event View

struct EditEventView: View {
    @Environment(\.dismiss) var dismiss
    let event: CalendarEvent
    @ObservedObject var calendarManager: CalendarManager
    
    @State private var title: String
    @State private var notes: String
    @State private var date: Date
    @State private var endDate: Date
    @State private var isAllDay: Bool
    @State private var category: EventCategory
    @State private var isCompleted: Bool
    @State private var showingDeleteAlert = false
    
    init(event: CalendarEvent, calendarManager: CalendarManager) {
        self.event = event
        self.calendarManager = calendarManager
        _title = State(initialValue: event.title)
        _notes = State(initialValue: event.notes)
        _date = State(initialValue: event.date)
        _endDate = State(initialValue: event.endDate ?? event.date.addingTimeInterval(60 * 30))
        _isAllDay = State(initialValue: event.isAllDay)
        _category = State(initialValue: event.category)
        _isCompleted = State(initialValue: event.isCompleted)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Event Details") {
                    TextField("Title", text: $title)
                    
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Date & Time") {
                    DatePicker("Start", selection: $date, displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                    
                    if !isAllDay {
                        DatePicker("End", selection: $endDate, in: date..., displayedComponents: [.date, .hourAndMinute])
                    }
                    
                    Toggle("All Day", isOn: $isAllDay)
                }
                
                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(EventCategory.allCases, id: \.self) { category in
                            Label(category.rawValue, systemImage: category.icon)
                                .tag(category)
                        }
                    }
                }
                
                Section("Status") {
                    Toggle("Completed", isOn: $isCompleted)
                }
                
                Section {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Event")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        var updatedEvent = event
                        updatedEvent.title = title
                        updatedEvent.notes = notes
                        updatedEvent.date = date
                        updatedEvent.endDate = isAllDay ? nil : max(endDate, date)
                        updatedEvent.isAllDay = isAllDay
                        updatedEvent.category = category
                        updatedEvent.isCompleted = isCompleted
                        calendarManager.updateEvent(updatedEvent)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .alert("Delete Event", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    calendarManager.deleteEvent(event)
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to delete this event?")
            }
        }
    }
}

#Preview {
    NavigationView {
        CalendarView()
    }
}

