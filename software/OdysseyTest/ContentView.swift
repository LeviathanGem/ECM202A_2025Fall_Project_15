//
//  ContentView.swift
//  OdysseyTest
//
//  Created by Assia LI on 2025/10/24.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var conversationManager = ConversationManager(apiKey: Config.apiKey)
    @StateObject private var bleManager = BLEManager()
    @State private var isBreathing = false
    @State private var showingPermissionAlert = false
    @State private var showingAPIKeyAlert = false
    @State private var showingEvents = false
    @State private var showingBLESettings = false
    
    var body: some View {
        VStack(spacing: 20) {
            // BLE Status indicator
            HStack {
                Spacer()
                Button(action: {
                    showingBLESettings = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: bleManager.isConnected ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                        Text(bleManager.isConnected ? "BLE Connected" : "BLE Setup")
                            .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(bleManager.isConnected ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                    .cornerRadius(20)
                }
                .foregroundColor(bleManager.isConnected ? .green : .gray)
            }
            .padding(.horizontal)
            
            // Main hydration control with breathing animation
            Circle()
                .fill(conversationManager.isActive ? Color.green : Color.blue)
                .frame(width: 200, height: 200)
                .overlay(
                    Image(systemName: "drop.fill")
                        .font(.system(size: 100))
                        .foregroundColor(.white)
                )
                .scaleEffect(isBreathing ? 0.85 : 1.0)
                .animation(
                    conversationManager.isActive ? 
                        .easeInOut(duration: 2.0).repeatForever(autoreverses: true) : .default,
                    value: isBreathing
                )
                .overlay(
                    // Audio level indicator ring
                    Circle()
                        .stroke(Color.white.opacity(0.5), lineWidth: 3)
                        .scaleEffect(1 + CGFloat(conversationManager.audioLevel) * 0.3)
                        .opacity(conversationManager.isActive ? 1 : 0)
                )
                .onTapGesture {
                    handleTap()
                }
                .shadow(color: conversationManager.isActive ? .green.opacity(0.5) : .clear, radius: 20)
            
            // Status text
            Text(conversationManager.isActive ? "🎙 Listening..." : "Tap to start")
                .font(.headline)
                .foregroundColor(conversationManager.isActive ? .green : .gray)
            
            // Transcript display
            if conversationManager.isActive {
                ScrollView {
                    Text(conversationManager.currentTranscript.isEmpty ? 
                         "Speak to interact..." : conversationManager.currentTranscript)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                }
                .frame(maxHeight: 150)
                .padding(.horizontal)
            }
            
            // Events button and display
            if !conversationManager.detectedEvents.isEmpty {
                Button(action: {
                    showingEvents.toggle()
                }) {
                    HStack {
                        Image(systemName: "list.bullet")
                        Text("Detected Events (\(conversationManager.detectedEvents.count))")
                    }
                    .padding()
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(10)
                }
            }
            
            // Error display
            if let error = conversationManager.errorMessage {
                Text("⚠️ \(error)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding()
            }
            
            Spacer()
            
            // App title
            Text("Odyssey Companion")
                .font(.title2)
                .fontWeight(.semibold)
        }
        .padding()
        .onAppear {
            checkSetup()
            setupBLEHandler()
        }
        .alert("Microphone Permission Required", isPresented: $showingPermissionAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("Please grant microphone access in Settings to use voice features.")
        }
        .alert("API Key Required", isPresented: $showingAPIKeyAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please add your OpenAI API key in Config.swift to use this feature.")
        }
        .sheet(isPresented: $showingEvents) {
            EventsListView(events: conversationManager.detectedEvents, onClear: {
                conversationManager.clearEvents()
            })
        }
        .sheet(isPresented: $showingBLESettings) {
            BLESettingsView(bleManager: bleManager)
        }
    }
    
    private func checkSetup() {
        // Check API key
        guard Config.isAPIKeyConfigured else {
            return
        }
        
        // Don't request permissions in Xcode Previews (it crashes)
        // Check if we're running in a preview environment
        guard !isPreview else { return }
        
        // Request microphone permission
        conversationManager.requestPermissions { granted in
            if !granted {
                showingPermissionAlert = true
            }
        }
    }
    
    private func setupBLEHandler() {
        // Set up BLE event handler
        bleManager.onEventReceived = { [self] message in
            // Parse the BLE message and create an event
            let eventName: String
            let displayMessage: String
            
            if message.hasPrefix("MATCH:") {
                // Alexa wake word detected
                eventName = "alexa_wake_word"
                displayMessage = message.replacingOccurrences(of: "MATCH: ", with: "")
            } else if message.hasPrefix("EVENT:") {
                // Generic NDP event
                eventName = "ndp_event"
                displayMessage = message.replacingOccurrences(of: "EVENT: ", with: "")
            } else if message.hasPrefix("CMD:") {
                // Command acknowledgment
                eventName = "command"
                displayMessage = message.replacingOccurrences(of: "CMD: ", with: "")
            } else if message.hasPrefix("TEST:") {
                // Test message
                eventName = "test_message"
                displayMessage = message.replacingOccurrences(of: "TEST: ", with: "")
            } else {
                // Generic message
                eventName = "ble_message"
                displayMessage = message
            }
            
            // Create and add event
            let event = DetectedEvent(
                name: eventName,
                timestamp: Date(),
                arguments: ["message": displayMessage]
            )
            
            DispatchQueue.main.async {
                // Add to conversation manager (displays in events list)
                self.conversationManager.detectedEvents.append(event)
                
                // Notify both LLM systems about the new BLE event
                self.notifyLLMSystems(of: event)
            }
        }
    }
    
    private func notifyLLMSystems(of event: DetectedEvent) {
        // This makes BLE events available to both local and cloud LLMs
        // They can now reference these events in their responses
        
        print("📡 BLE event sent to LLM systems: \(event.displayName)")
        
        // Note: The LLM systems will read from conversationManager.detectedEvents
        // No direct push needed - they pull the context when generating responses
    }
    
    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    private func handleTap() {
        // Don't allow interaction in previews
        guard !isPreview else {
            print("Preview mode - tap disabled")
            return
        }
        
        // Check API key first
        guard Config.isAPIKeyConfigured else {
            showingAPIKeyAlert = true
            return
        }
        
        // Check permission
        guard conversationManager.permissionGranted else {
            showingPermissionAlert = true
            return
        }
        
        // Toggle conversation
        if conversationManager.isActive {
            conversationManager.stopConversation()
            isBreathing = false
        } else {
            conversationManager.startConversation()
            isBreathing = true
        }
    }
}

// MARK: - Events List View

struct EventsListView: View {
    let events: [DetectedEvent]
    let onClear: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(events) { event in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(event.displayName)
                            .font(.headline)
                        Text(event.timestamp.formatted(date: .omitted, time: .standard))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 5)
                }
            }
            .navigationTitle("Detected Events")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") {
                        onClear()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
