//
//  DebugLogger.swift
//  OdysseyTest
//
//  Lightweight in-app logger with level control and rolling buffer.
//

import Foundation

enum LogLevel: String, CaseIterable, Codable, Identifiable {
    case error = "Error"
    case warn = "Warn"
    case info = "Info"
    case debug = "Debug"
    
    var id: String { rawValue }
    
    var priority: Int {
        switch self {
        case .error: return 3
        case .warn: return 2
        case .info: return 1
        case .debug: return 0
        }
    }
}

struct DebugLogEntry: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let level: LogLevel
    let category: String
    let message: String
    
    init(id: UUID = UUID(), timestamp: Date = Date(), level: LogLevel, category: String, message: String) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
    }
}

final class DebugLogger: ObservableObject {
    static let shared = DebugLogger()
    
    @Published private(set) var entries: [DebugLogEntry] = []
    
    private let storageKey = "odyssey_debug_logs"
    private let levelKey = "odyssey_debug_log_level"
    private let maxEntries = 500
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    
    private init() {
        load()
    }
    
    var currentLevel: LogLevel {
        get {
            if let raw = UserDefaults.standard.string(forKey: levelKey),
               let level = LogLevel(rawValue: raw) {
                return level
            }
            return .info
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: levelKey)
        }
    }
    
    func setLevel(_ level: LogLevel) {
        currentLevel = level
    }
    
    func log(_ level: LogLevel, category: String, message: String) {
        guard level.priority >= currentLevel.priority else { return }
        
        let entry = DebugLogEntry(level: level, category: category, message: message)
        DispatchQueue.main.async {
            self.entries.append(entry)
            if self.entries.count > self.maxEntries {
                self.entries.removeFirst(self.entries.count - self.maxEntries)
            }
            self.save()
        }
    }
    
    func clear() {
        entries.removeAll()
        save()
    }
    
    // MARK: - Persistence
    
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? decoder.decode([DebugLogEntry].self, from: data) else {
            entries = []
            return
        }
        entries = decoded
    }
    
    private func save() {
        if let data = try? encoder.encode(entries) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

