//
//  NudgeHistoryStore.swift
//  OdysseyTest
//
//  Tracks hydration nudges over a rolling 7-day window.
//

import Foundation

struct NudgeRecord: Identifiable, Codable {
    let id: UUID
    let message: String
    let timestamp: Date
    
    init(id: UUID = UUID(), message: String, timestamp: Date = Date()) {
        self.id = id
        self.message = message
        self.timestamp = timestamp
    }
}

final class NudgeHistoryStore: ObservableObject {
    static let shared = NudgeHistoryStore()
    
    @Published private(set) var allNudges: [NudgeRecord] = []
    
    private let storageKey = "odyssey_nudge_history"
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    
    private init() {
        allNudges = loadAll()
    }
    
    func recent(days: Int = 7) -> [NudgeRecord] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let records = allNudges.filter { $0.timestamp >= cutoff }
        return records.sorted { $0.timestamp > $1.timestamp }
    }
    
    func logNudge(message: String, at date: Date = Date()) {
        let newRecord = NudgeRecord(message: message, timestamp: date)
        allNudges.append(newRecord)
        save(allNudges)
        DebugLogger.shared.log(.info, category: "Nudge", message: "Logged nudge: \(message)")
    }
    
    func sentWithin(minutes: Double) -> Bool {
        guard let last = recent(days: 7).first else { return false }
        let elapsed = Date().timeIntervalSince(last.timestamp) / 60
        return elapsed < minutes
    }
    
    /// Clear all stored hydration nudges
    func clearAll() {
        allNudges.removeAll()
        UserDefaults.standard.removeObject(forKey: storageKey)
        DebugLogger.shared.log(.info, category: "Nudge", message: "Cleared all hydration nudge history")
    }
    
    // MARK: - Persistence
    
    private func loadAll() -> [NudgeRecord] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let records = try? decoder.decode([NudgeRecord].self, from: data) else {
            return []
        }
        return records
    }
    
    private func save(_ records: [NudgeRecord]) {
        let trimmed = trimToSevenDays(records)
        if let data = try? encoder.encode(trimmed) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    private func trimToSevenDays(_ records: [NudgeRecord]) -> [NudgeRecord] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return records.filter { $0.timestamp >= cutoff }
    }
}

