//
//  JITAIReasoner.swift
//  OdysseyTest
//
//  Lightweight rule-based reasoner for hydration prompts using
//  BLE activity context, hydration state, and spacing rules.
//

import Foundation

enum ActivityLabel: String {
    case keyboard
    case faucet
    case background
    case unknown
}

struct JITAIRecommendation {
    let message: String
    let createdAt: Date
}

final class JITAIReasoner {
    private let hydrationStore: HydrationStore
    
    // Guardrails
    private let minPromptSpacingMinutes: Double = 45
    private let breakPromptSpacingMinutes: Double = 20
    
    // State
    private var lastActivity: ActivityLabel = .unknown
    private var lastActivityAt: Date = Date()
    private var isBusy: Bool = false
    
    init(hydrationStore: HydrationStore) {
        self.hydrationStore = hydrationStore
    }
    
    func updateBusyStatus(_ busy: Bool) {
        isBusy = busy
    }
    
    func handleActivity(label: ActivityLabel, timestamp: Date = Date()) -> JITAIRecommendation? {
        lastActivity = label
        lastActivityAt = timestamp
        
        // Never prompt if user is busy (e.g., meeting)
        guard !isBusy else { return nil }
        
        let state = hydrationStore.loadToday()
        let total = state.entries.reduce(0) { $0 + $1.amount }
        let goal = max(state.dailyGoal, 500) // avoid divide by zero
        let spacingOk = promptSpacingAllowsPrompt(lastPromptAt: state.lastPromptAt, minimumMinutes: minPromptSpacingMinutes)
        let behindAmount = hydrationDeficit(total: total, goal: goal)
        
        switch label {
        case .faucet:
            // Treat faucet as a break opportunity
            let breakSpacingOk = promptSpacingAllowsPrompt(lastPromptAt: state.lastPromptAt, minimumMinutes: breakPromptSpacingMinutes)
            if breakSpacingOk && behindAmount > 0 {
                return makePrompt(remaining: behindAmount, goal: goal, total: total, at: timestamp)
            }
        case .keyboard:
            // If working continuously and behind, nudge occasionally
            let minutesSinceLastActivity = Date().timeIntervalSince(lastActivityAt) / 60
            if minutesSinceLastActivity >= 30, spacingOk, behindAmount > 200 {
                return makePrompt(remaining: behindAmount, goal: goal, total: total, at: timestamp)
            }
        case .background, .unknown:
            break
        }
        
        return nil
    }
    
    private func makePrompt(remaining: Int, goal: Int, total: Int, at date: Date) -> JITAIRecommendation {
        hydrationStore.recordPromptSent(at: date)
        
        let suggestion = remaining >= 400 ? 300 : 200
        let message = "💧 Hydration check: you've had \(total) / \(goal) ml. Try sipping ~\(suggestion) ml now."
        
        return JITAIRecommendation(message: message, createdAt: date)
    }
    
    private func hydrationDeficit(total: Int, goal: Int) -> Int {
        // Expected intake proportional to day progress
        let minutes = minutesSinceMidnight()
        let fractionOfDay = min(max(minutes / (24 * 60), 0), 1)
        let expected = Int(Double(goal) * fractionOfDay)
        return max(expected - total, 0)
    }
    
    private func promptSpacingAllowsPrompt(lastPromptAt: Date?, minimumMinutes: Double) -> Bool {
        guard let last = lastPromptAt else { return true }
        let minutes = Date().timeIntervalSince(last) / 60
        return minutes >= minimumMinutes
    }
    
    private func minutesSinceMidnight() -> Double {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: now)
        let minutes = Double(components.hour ?? 0) * 60 + Double(components.minute ?? 0)
        return minutes
    }
}

