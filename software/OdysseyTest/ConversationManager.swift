//
//  ConversationManager.swift
//  OdysseyTest
//
//  Coordinates audio recording and OpenAI streaming
//

import Foundation
import SwiftUI

class ConversationManager: ObservableObject {
    @Published var isActive = false
    @Published var currentTranscript = ""
    @Published var detectedEvents: [DetectedEvent] = []
    @Published var errorMessage: String?
    @Published var permissionGranted = false
    
    private let audioRecorder = AudioRecorder()
    var openAIService: OpenAIRealtimeService? // Made public for UnifiedChatView
    private let apiKey: String
    private var lastRequestTime: Date?
    private let minimumRequestInterval: TimeInterval = 3.0 // Wait 3 seconds between requests
    
    init(apiKey: String) {
        self.apiKey = apiKey
        setupAudioRecorder()
    }
    
    private func setupAudioRecorder() {
        audioRecorder.onAudioBuffer = { [weak self] buffer in
            self?.openAIService?.sendAudioBuffer(buffer)
        }
    }
    
    func requestPermissions(completion: @escaping (Bool) -> Void) {
        audioRecorder.requestPermission { [weak self] granted in
            self?.permissionGranted = granted
            completion(granted)
        }
    }
    
    func startConversation() {
        let startTime = Date()
        
        TimestampUtility.log("Starting conversation...", category: "ConversationManager")
        
        guard permissionGranted else {
            errorMessage = "Microphone permission not granted"
            TimestampUtility.log("ERROR: Microphone permission not granted", category: "ConversationManager")
            return
        }
        
        // Check rate limiting
        if let lastTime = lastRequestTime {
            let timeSinceLastRequest = Date().timeIntervalSince(lastTime)
            if timeSinceLastRequest < minimumRequestInterval {
                let waitTime = Int(minimumRequestInterval - timeSinceLastRequest)
                errorMessage = "Please wait \(waitTime) seconds before starting again (rate limiting)"
                TimestampUtility.log("Rate limited: wait \(waitTime) seconds", category: "ConversationManager")
                return
            }
        }
        
        lastRequestTime = Date()
        
        // Initialize OpenAI service
        openAIService = OpenAIRealtimeService(apiKey: apiKey)
        
        // Set up callbacks
        openAIService?.onResponseReceived = { [weak self] response in
            print("Response: \(response)")
            DispatchQueue.main.async {
                self?.currentTranscript = response
            }
        }
        
        openAIService?.onEventDetected = { [weak self] eventName, arguments in
            let event = DetectedEvent(name: eventName, timestamp: Date(), arguments: arguments)
            DispatchQueue.main.async {
                self?.detectedEvents.append(event)
                // Update OpenAI with latest BLE events (including all detected events)
                self?.updateOpenAIContext()
            }
            print("Event detected: \(eventName)")
        }
        
        // Poll for transcript updates
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self, let service = self.openAIService else {
                timer.invalidate()
                return
            }
            
            if !service.transcribedText.isEmpty {
                DispatchQueue.main.async {
                    self.currentTranscript = service.transcribedText
                }
            }
            
            if !self.isActive {
                timer.invalidate()
            }
        }
        
        openAIService?.onError = { [weak self] error in
            DispatchQueue.main.async {
                self?.errorMessage = "Connection error: \(error.localizedDescription)"
                // Stop recording on connection error
                self?.stopConversation()
            }
        }
        
        // Connect to OpenAI
        openAIService?.connect()
        
        // Wait a bit for connection before starting recording
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            // Check if still connected
            if self.openAIService?.isConnected == true {
                // Start recording
                self.audioRecorder.startRecording()
                self.isActive = true
                self.currentTranscript = ""
                
                let elapsed = TimestampUtility.elapsed(since: startTime)
                TimestampUtility.logPerformance("Conversation started (connection + setup)", duration: elapsed)
            } else {
                self.errorMessage = "Failed to connect to OpenAI. Check your internet connection."
                TimestampUtility.log("ERROR: Connection failed, not starting recording", category: "ConversationManager")
            }
        }
    }
    
    func stopConversation() {
        TimestampUtility.log("Stopping conversation", category: "ConversationManager")
        
        // Stop recording
        audioRecorder.stopRecording()
        
        // Don't commit audio - it causes errors with empty buffers
        // OpenAI will process what it received automatically
        
        // Disconnect after a brief delay to allow final processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.openAIService?.disconnect()
        }
        
        isActive = false
        
        TimestampUtility.log("Conversation stopped", category: "ConversationManager")
    }
    
    func clearEvents() {
        detectedEvents.removeAll()
    }
    
    var audioLevel: Float {
        audioRecorder.audioLevel
    }
    
    private func updateOpenAIContext() {
        // Filter for BLE-related events
        let bleEvents = detectedEvents.filter { event in
            ["alexa_wake_word", "ndp_event", "command", "test_message", "ble_message"].contains(event.name)
        }
        
        // Update OpenAI service with BLE context
        openAIService?.updateBLEContext(bleEvents)
    }
}

// MARK: - Models

struct DetectedEvent: Identifiable, Equatable {
    let id: UUID
    let name: String
    let timestamp: Date
    let arguments: [String: Any]
    
    init(name: String, timestamp: Date = Date(), arguments: [String: Any] = [:]) {
        self.id = UUID()
        self.name = name
        self.timestamp = timestamp
        self.arguments = arguments
        
        // Log event detection with millisecond timestamp
        TimestampUtility.log("Event detected: \(name)", category: "Event")
    }
    
    var displayName: String {
        switch name {
        case "log_water_intake":
            return "💧 Logged Water"
        case "set_hydration_goal":
            return "🎯 Goal Updated"
        case "hydration_status":
            return "📊 Hydration Status"
        case "hydration_prompt":
            return "🚰 Hydration Nudge"
        case "alexa_wake_word":
            // Get the actual message from arguments if available
            if let message = arguments["message"] as? String {
                return "🎤 Alexa: \(message)"
            }
            return "🎤 Alexa Wake Word"
        case "ndp_event":
            if let message = arguments["message"] as? String {
                return "🔔 \(message)"
            }
            return "🔔 NDP Event"
        case "command":
            if let message = arguments["message"] as? String {
                return "⚙️ \(message)"
            }
            return "⚙️ Command"
        case "ble_message":
            if let message = arguments["message"] as? String {
                return "📡 \(message)"
            }
            return "📡 BLE Message"
        case "test_message":
            if let message = arguments["message"] as? String {
                return "🧪 Test: \(message)"
            }
            return "🧪 Test Message"
        default:
            return name
        }
    }
    
    /// Formatted timestamp with milliseconds
    var timestampMs: String {
        return timestamp.timestamp
    }
    
    /// Unix timestamp in milliseconds
    var timestampUnix: Int64 {
        return timestamp.unixMs
    }
    
    static func == (lhs: DetectedEvent, rhs: DetectedEvent) -> Bool {
        lhs.id == rhs.id
    }
}

