//
//  Message.swift
//  OdysseyTest
//
//  Data model for chat messages
//

import Foundation

struct Message: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let sender: MessageSender
    let timestamp: Date
    let relatedEvent: String? // Optional: linked event type
    
    init(text: String, sender: MessageSender, timestamp: Date = Date(), relatedEvent: String? = nil) {
        self.text = text
        self.sender = sender
        self.timestamp = timestamp
        self.relatedEvent = relatedEvent
        
        // Log message creation with millisecond timestamp
        TimestampUtility.log("Message created: \(sender) - \(text.prefix(50))...", category: "Message")
    }
    
    /// Formatted timestamp with milliseconds
    var timestampMs: String {
        return timestamp.timestamp
    }
    
    /// Unix timestamp in milliseconds
    var timestampUnix: Int64 {
        return timestamp.unixMs
    }
}

enum MessageSender: Equatable {
    case user
    case bot
}

