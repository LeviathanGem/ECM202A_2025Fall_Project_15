//
//  HydrationStore.swift
//  OdysseyTest
//
//  Shared hydration state with simple per-day persistence.
//

import Foundation

struct HydrationEntry: Identifiable, Codable {
    let id: UUID
    let amount: Int // milliliters
    let timestamp: Date
    
    init(id: UUID = UUID(), amount: Int, timestamp: Date = Date()) {
        self.id = id
        self.amount = amount
        self.timestamp = timestamp
    }
}

struct HydrationStorageData: Codable {
    let dateKey: String
    var entries: [HydrationEntry]
    var dailyGoal: Int
    var lastPromptAt: Date?
}

final class HydrationStore {
    static let shared = HydrationStore()
    
    private let storageKey = "hydration_storage"
    private let windowConfigKey = "hydration_window_config"
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    
    private init() {}
    
    func loadToday() -> HydrationStorageData {
        let todayKey = Self.todayKey()
        
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let stored = try? decoder.decode(HydrationStorageData.self, from: data),
            stored.dateKey == todayKey
        else {
            let fresh = HydrationStorageData(dateKey: todayKey, entries: [], dailyGoal: 2000, lastPromptAt: nil)
            save(fresh)
            return fresh
        }
        
        return stored
    }
    
    func log(amount: Int) -> HydrationStorageData {
        var state = loadToday()
        state.entries.append(HydrationEntry(amount: amount))
        save(state)
        return state
    }
    
    func setDailyGoal(_ goal: Int) -> HydrationStorageData {
        var state = loadToday()
        state.dailyGoal = goal
        save(state)
        return state
    }
    
    func resetToday() -> HydrationStorageData {
        let fresh = HydrationStorageData(dateKey: Self.todayKey(), entries: [], dailyGoal: 2000, lastPromptAt: nil)
        save(fresh)
        return fresh
    }
    
    func recordPromptSent(at date: Date = Date()) -> HydrationStorageData {
        var state = loadToday()
        state.lastPromptAt = date
        save(state)
        return state
    }
    
    func resetPromptCooldown() -> HydrationStorageData {
        var state = loadToday()
        state.lastPromptAt = nil
        save(state)
        return state
    }
    
    func save(_ state: HydrationStorageData) {
        if let data = try? encoder.encode(state) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    static func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    // MARK: - Hydration Window Configuration
    
    func getHydrationWindow() -> (startHour: Int, endHour: Int) {
        if let data = UserDefaults.standard.data(forKey: windowConfigKey),
           let config = try? decoder.decode([String: Int].self, from: data),
           let start = config["start"],
           let end = config["end"] {
            return (start, end)
        }
        // Default: 8 AM - 10 PM
        return (8, 22)
    }
    
    func setHydrationWindow(startHour: Int, endHour: Int) {
        let config = ["start": startHour, "end": endHour]
        if let data = try? encoder.encode(config) {
            UserDefaults.standard.set(data, forKey: windowConfigKey)
        }
    }
}

