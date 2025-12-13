//
//  CalendarManager.swift
//  OdysseyTest
//
//  Manages calendar events with persistent storage
//

import Foundation
import Combine

class CalendarManager: ObservableObject {
    static let shared = CalendarManager()
    
    @Published var events: [CalendarEvent] = []
    
    private let storageKey = "odyssey_calendar_events"
    
    private init() {
        loadEvents()
    }
    
    // MARK: - Event Management
    
    func addEvent(_ event: CalendarEvent) {
        events.append(event)
        sortEvents()
        saveEvents()
    }
    
    func updateEvent(_ event: CalendarEvent) {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index] = event
            sortEvents()
            saveEvents()
        }
    }
    
    func deleteEvent(_ event: CalendarEvent) {
        events.removeAll { $0.id == event.id }
        saveEvents()
    }
    
    func deleteEvents(at offsets: IndexSet) {
        events.remove(atOffsets: offsets)
        saveEvents()
    }
    
    func toggleCompletion(for event: CalendarEvent) {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index].isCompleted.toggle()
            saveEvents()
        }
    }
    
    // MARK: - Filtering
    
    func upcomingEvents() -> [CalendarEvent] {
        events.filter { $0.isUpcoming && !$0.isCompleted }
    }
    
    func pastEvents() -> [CalendarEvent] {
        events.filter { $0.isPast }
    }
    
    func completedEvents() -> [CalendarEvent] {
        events.filter { $0.isCompleted }
    }
    
    func events(for date: Date) -> [CalendarEvent] {
        events.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
    
    func events(in category: EventCategory) -> [CalendarEvent] {
        events.filter { $0.category == category }
    }
    
    // MARK: - Persistence
    
    private func saveEvents() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(events)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Error saving events: \(error.localizedDescription)")
        }
    }
    
    private func loadEvents() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            // Load sample data on first launch
            loadSampleData()
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            events = try decoder.decode([CalendarEvent].self, from: data)
            sortEvents()
        } catch {
            print("Error loading events: \(error.localizedDescription)")
            events = []
        }
    }
    
    private func sortEvents() {
        events.sort { $0.date < $1.date }
    }
    
    // MARK: - Sample Data
    
    private func loadSampleData() {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        let nextWeek = calendar.date(byAdding: .day, value: 7, to: Date())!
        
        events = [
            CalendarEvent(
                title: "Hydration focus day",
                notes: "Plan 4 x 500 ml bottles across the day",
                date: tomorrow,
                isAllDay: true,
                category: .wellness
            ),
            CalendarEvent(
                title: "Wellness check-in",
                notes: "Add quiet break blocks around meetings",
                date: nextWeek,
                isAllDay: false,
                category: .wellness
            )
        ]
        saveEvents()
    }
    
    func clearAllEvents() {
        events.removeAll()
        saveEvents()
    }
}

