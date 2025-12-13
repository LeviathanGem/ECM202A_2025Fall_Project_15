//
//  HydrationView.swift
//  OdysseyTest
//
//  Simple daily hydration tracker with quick-add shortcuts and persistence.
//

import SwiftUI

struct HydrationView: View {
    private let store = HydrationStore.shared
    
    @State private var entries: [HydrationEntry] = []
    @State private var dailyGoal: Int = 2000
    @State private var lastPromptAt: Date?
    @State private var customAmount: String = ""
    @State private var windowStartHour: Int = 8
    @State private var windowEndHour: Int = 22
    
    private var totalConsumed: Int {
        entries.reduce(0) { $0 + $1.amount }
    }
    
    private var progress: Double {
        guard dailyGoal > 0 else { return 0 }
        return min(Double(totalConsumed) / Double(dailyGoal), 1.0)
    }
    
    private var remaining: Int {
        max(dailyGoal - totalConsumed, 0)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Summary
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Today's Intake")
                                .font(.headline)
                            Text("\(totalConsumed) / \(dailyGoal) ml")
                                .font(.title2).bold()
                            Text(remaining > 0 ? "\(remaining) ml to go" : "Goal reached 🎉")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                            .frame(width: 140)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                // Quick add buttons
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick Add")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    HStack {
                        quickAddButton(amount: 250)
                        quickAddButton(amount: 500)
                        quickAddButton(amount: 750)
                    }
                }
                
                // Custom add
                VStack(alignment: .leading, spacing: 8) {
                    Text("Custom Amount (ml)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    HStack {
                        TextField("e.g. 300", text: $customAmount)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                        Button("Add") {
                            addCustomAmount()
                        }
                        .disabled(customAmount.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                
                // Daily goal
                VStack(alignment: .leading, spacing: 8) {
                    Text("Daily Goal (ml)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Stepper(value: $dailyGoal, in: 500...5000, step: 100) {
                        Text("\(dailyGoal) ml")
                    }
                    .onChange(of: dailyGoal) { _ in
                        saveStorage()
                    }
                }
                
                // Hydration window
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hydration Window")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Set the time range for daily hydration tracking")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Start")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Picker("Start Hour", selection: $windowStartHour) {
                                ForEach(0..<24) { hour in
                                    Text(formatHour(hour)).tag(hour)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        
                        Text("—")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("End")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Picker("End Hour", selection: $windowEndHour) {
                                ForEach(0..<24) { hour in
                                    Text(formatHour(hour)).tag(hour)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                    .onChange(of: windowStartHour) { _ in
                        saveWindowConfig()
                    }
                    .onChange(of: windowEndHour) { _ in
                        saveWindowConfig()
                    }
                }
                
                // Log
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Today's Log")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                        if !entries.isEmpty {
                            Button("Reset Day") {
                                resetDay()
                            }
                            .foregroundColor(.red)
                        }
                    }
                    
                    if entries.isEmpty {
                        Text("No entries yet. Log your first drink!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 6)
                    } else {
                        ForEach(entries.sorted { $0.timestamp > $1.timestamp }) { entry in
                            HStack {
                                Text("+\(entry.amount) ml")
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(entry.timestamp, style: .time)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Hydration")
        .onAppear {
            loadStorage()
        }
    }
    
    // MARK: - Actions
    
    private func quickAddButton(amount: Int) -> some View {
        Button("+\(amount) ml") {
            addEntry(amount)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(Color.blue.opacity(0.15))
        .foregroundColor(.blue)
        .cornerRadius(10)
    }
    
    private func addCustomAmount() {
        let trimmed = customAmount.trimmingCharacters(in: .whitespaces)
        guard let value = Int(trimmed), value > 0 else { return }
        addEntry(value)
        customAmount = ""
    }
    
    private func addEntry(_ amount: Int) {
        let state = store.log(amount: amount)
        apply(state: state)
    }
    
    private func resetDay() {
        let state = store.resetToday()
        apply(state: state)
    }
    
    // MARK: - Persistence
    
    private func loadStorage() {
        let state = store.loadToday()
        apply(state: state)
        
        let window = store.getHydrationWindow()
        windowStartHour = window.startHour
        windowEndHour = window.endHour
    }
    
    private func saveStorage() {
        let state = HydrationStorageData(
            dateKey: HydrationStore.todayKey(),
            entries: entries,
            dailyGoal: dailyGoal,
            lastPromptAt: lastPromptAt
        )
        store.save(state)
    }

    private func apply(state: HydrationStorageData) {
        entries = state.entries
        dailyGoal = state.dailyGoal
        lastPromptAt = state.lastPromptAt
    }
    
    private func saveWindowConfig() {
        store.setHydrationWindow(startHour: windowStartHour, endHour: windowEndHour)
    }
    
    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let calendar = Calendar.current
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationView {
        HydrationView()
    }
}

