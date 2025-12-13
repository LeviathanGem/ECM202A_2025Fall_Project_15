//
//  TimestampUtility.swift
//  OdysseyTest
//
//  Utility for consistent millisecond-precision timestamps
//

import Foundation

struct TimestampUtility {
    
    // MARK: - Timestamp Formats
    
    /// Returns current timestamp with milliseconds: "2025-10-26 23:45:12.345"
    static var now: String {
        return formatDate(Date())
    }
    
    /// Returns ISO 8601 timestamp with milliseconds: "2025-10-26T23:45:12.345Z"
    static var nowISO: String {
        return isoFormatter.string(from: Date())
    }
    
    /// Returns Unix timestamp with milliseconds: "1729987512345"
    static var nowUnix: Int64 {
        return Int64(Date().timeIntervalSince1970 * 1000)
    }
    
    /// Returns elapsed time in milliseconds since a start date
    static func elapsed(since startDate: Date) -> Double {
        return Date().timeIntervalSince(startDate) * 1000
    }
    
    // MARK: - Formatters
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    private static let timeOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    // MARK: - Formatting Functions
    
    static func formatDate(_ date: Date) -> String {
        return dateFormatter.string(from: date)
    }
    
    static func formatTime(_ date: Date) -> String {
        return timeOnlyFormatter.string(from: date)
    }
    
    static func formatElapsed(_ milliseconds: Double) -> String {
        if milliseconds < 1000 {
            return String(format: "%.0fms", milliseconds)
        } else {
            let seconds = milliseconds / 1000
            return String(format: "%.2fs", seconds)
        }
    }
    
    // MARK: - Logging Helper
    
    static func log(_ message: String, category: String = "General") {
        print("[\(now)] [\(category)] \(message)")
    }
    
    static func logPerformance(_ operation: String, duration: Double) {
        let formatted = formatElapsed(duration)
        print("[\(now)] [PERFORMANCE] \(operation): \(formatted)")
    }
}

// MARK: - Date Extension for Convenience

extension Date {
    var timestamp: String {
        return TimestampUtility.formatDate(self)
    }
    
    var timestampTime: String {
        return TimestampUtility.formatTime(self)
    }
    
    var unixMs: Int64 {
        return Int64(self.timeIntervalSince1970 * 1000)
    }
}

