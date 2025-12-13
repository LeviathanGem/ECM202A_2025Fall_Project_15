//
//  CalendarEvent.swift
//  OdysseyTest
//
//  Calendar event data model for agenda management
//

import Foundation

struct CalendarEvent: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var notes: String
    /// Start date/time of the event
    var date: Date
    /// Optional explicit end date/time; if nil, we derive a default duration
    var endDate: Date?
    var isAllDay: Bool
    var category: EventCategory
    var isCompleted: Bool
    
    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        date: Date = Date(),
        endDate: Date? = nil,
        isAllDay: Bool = false,
        category: EventCategory = .wellness,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.date = date
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.category = category
        self.isCompleted = isCompleted
    }
    
    /// Computed end time used throughout the app
    var effectiveEndDate: Date {
        if let endDate = endDate {
            return endDate
        }
        if isAllDay {
            return Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
        } else {
            // Default duration for non-all-day events: 30 minutes
            return date.addingTimeInterval(60 * 30)
        }
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        if isAllDay {
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        } else {
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            let start = formatter.string(from: date)
            formatter.dateStyle = .none
            let end = formatter.string(from: effectiveEndDate)
            return "\(start) - \(end)"
        }
    }
    
    var isUpcoming: Bool {
        effectiveEndDate > Date()
    }
    
    var isPast: Bool {
        effectiveEndDate < Date()
    }
}

enum EventCategory: String, Codable, CaseIterable {
    case wellness = "Wellness"
    case maintenance = "Maintenance"
    case training = "Training"
    case race = "Race"
    case social = "Social"
    case weather = "Weather"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .wellness: return "drop.fill"
        case .maintenance: return "wrench.fill"
        case .training: return "graduationcap.fill"
        case .race: return "flag.checkered"
        case .social: return "person.3.fill"
        case .weather: return "cloud.sun.fill"
        case .other: return "calendar"
        }
    }
    
    var color: String {
        switch self {
        case .wellness: return "blue"
        case .maintenance: return "orange"
        case .training: return "green"
        case .race: return "red"
        case .social: return "purple"
        case .weather: return "cyan"
        case .other: return "gray"
        }
    }
}

