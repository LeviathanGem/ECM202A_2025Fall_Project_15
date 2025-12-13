//
//  OdysseyTestApp.swift
//  OdysseyTest
//
//  Created by Assia LI on 2025/10/24.
//

import SwiftUI

@main
struct OdysseyTestApp: App {
    @StateObject private var sharedConversationManager = ConversationManager(apiKey: Config.apiKey)
    
    var body: some Scene {
        WindowGroup {
            TabView {
                // AI Chat Tab - Unified Cloud/Local/Hybrid with BLE
                NavigationView {
                    UnifiedChatView(conversationManager: sharedConversationManager)
                }
                .tabItem {
                    Label("AI Chat", systemImage: "message.fill")
                }
                
                // Events Tab - Unified event history
                NavigationView {
                    EventsHistoryView(conversationManager: sharedConversationManager)
                }
                .tabItem {
                    Label("Events", systemImage: "list.bullet")
                }
                
                // Calendar Tab - Agenda management
                NavigationView {
                    CalendarView()
                }
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
                
                // Hydration Tab - Daily water intake tracker
                NavigationView {
                    HydrationView()
                }
                .tabItem {
                    Label("Hydration", systemImage: "drop.fill")
                }
            }
            .onAppear {
                // Ask for notification permission so LLM nudges can be delivered
                NotificationManager.shared.requestAuthorization()
            }
        }
    }
}

// MARK: - Events History View

struct EventsHistoryView: View {
    @ObservedObject var conversationManager: ConversationManager
    @ObservedObject private var nudgeStore = NudgeHistoryStore.shared
    
    private var hasNudges: Bool {
        !nudgeStore.recent(days: 7).isEmpty
    }
    
    var body: some View {
        List {
            // BLE Events Section
            Section(header: Text("BLE Events")) {
                if conversationManager.detectedEvents.isEmpty {
                    Text("No BLE events yet")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.vertical, 8)
                } else {
                    ForEach(conversationManager.detectedEvents) { event in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(event.displayName)
                                .font(.headline)
                            Text(event.timestamp.formatted(date: .abbreviated, time: .standard))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 5)
                    }
                }
            }
            
            // Hydration Nudge History Section
            Section(header: Text("Hydration Nudges")) {
                let nudges = nudgeStore.recent(days: 7)
                if nudges.isEmpty {
                    Text("No nudges in the last 7 days")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.vertical, 8)
                } else {
                    ForEach(nudges) { record in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(record.message)
                                .font(.subheadline)
                            Text(record.timestamp.formatted(date: .abbreviated, time: .standard))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 5)
                    }
                }
            }
        }
        .navigationTitle("Event History")
        .navigationBarItems(trailing:
            HStack {
                Button("Clear BLE") {
                    if !conversationManager.detectedEvents.isEmpty {
                        conversationManager.clearEvents()
                    }
                }
                .disabled(conversationManager.detectedEvents.isEmpty)
                
                Button("Clear Nudges") {
                    if hasNudges {
                        nudgeStore.clearAll()
                    }
                }
                .disabled(!hasNudges)
            }
        )
    }
}
