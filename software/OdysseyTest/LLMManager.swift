//
//  LLMManager.swift
//  OdysseyTest
//
//  Manages local LLM inference (llama.cpp placeholder)


import Foundation

class LLMManager: ObservableObject {
    @Published var isLoaded = false
    @Published var isGenerating = false
    @Published var loadError: String?
    
    private var conversationHistory: [Message] = []
    private var bleEvents: [DetectedEvent] = []  // Track BLE events for context
    private var llamaBridge: LlamaBridge?
    
    // MARK: - Model Loading
    
    func loadModel() {
        guard !isLoaded else { return }
        guard LLMConfig.isModelDownloaded else {
            loadError = "Model not downloaded"
            TimestampUtility.log("ERROR: Model not downloaded", category: "LLMManager")
            return
        }
        
        let modelPath = LLMConfig.modelPath.path
        TimestampUtility.log("Loading local LLM model via llama.cpp at path: \(modelPath)", category: "LLMManager")
        
        // Heavy work: do on background queue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            if let bridge = LlamaBridge(modelPath: modelPath) {
                DispatchQueue.main.async {
                    self.llamaBridge = bridge
                    self.isLoaded = true
                    self.loadError = nil
                    TimestampUtility.log("Local LLM loaded successfully (llama.cpp)", category: "LLMManager")
                    DebugLogger.shared.log(.info, category: "LLM", message: "Local llama.cpp model loaded")
                }
            } else {
                let message = "Failed to load local LLM model"
                DispatchQueue.main.async {
                    self.loadError = message
                    self.isLoaded = false
                    TimestampUtility.log("ERROR: \(message)", category: "LLMManager")
                    DebugLogger.shared.log(.error, category: "LLM", message: message)
                }
            }
        }
    }
    
    func unloadModel() {
        llamaBridge?.unload()
        llamaBridge = nil
        isLoaded = false
        conversationHistory.removeAll()
        TimestampUtility.log("LLM unloaded", category: "LLMManager")
    }
    
    // MARK: - Text Generation
    
    func generate(prompt: String, completion: @escaping (String, String?) -> Void) {
        guard isLoaded, let llamaBridge = llamaBridge else {
            TimestampUtility.log("ERROR: Attempted generation with unloaded model", category: "LLMManager")
            completion("", "Model not loaded")
            return
        }
        
        TimestampUtility.log("Generating local LLM response for: \(prompt.prefix(80))...", category: "LLMManager")
        
        isGenerating = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var nsError: NSError?
            let response = llamaBridge.generateResponse(
                prompt,
                maxTokens: Int32(LLMConfig.maxTokens),
                temperature: LLMConfig.temperature,
                topP: LLMConfig.topP,
                error: &nsError
            )
            
            let errorMessage = nsError?.localizedDescription
            
            DispatchQueue.main.async {
                self.isGenerating = false
                
                if let errorMessage {
                    // For now, surface the bridge error directly
                    let text = "⚠️ Local LLM error: \(errorMessage)"
                    let event: String? = nil
                    completion(text, event)
                } else {
                    completion(response, nil)
                }
            }
        }
    }
    
    // MARK: - Prompt Building
    
    private func buildPromptContext(userMessage: String) async -> String {
        var context = ""
        
        // Add BLE context if there are recent events
        if !bleEvents.isEmpty {
            context += "=== Recent Hardware Events ===\n"
            for event in bleEvents.suffix(5) { // Last 5 BLE events
                let timeAgo = formatTimeAgo(event.timestamp)
                context += "• \(event.displayName) (\(timeAgo))\n"
            }
            context += "\n"
        }
        
        // Add conversation history
        if !conversationHistory.isEmpty {
            context += "=== Recent Conversation ===\n"
            for message in conversationHistory.suffix(6) { // Keep last 6 messages for context
                let role = message.sender == .user ? "User" : "Assistant"
                context += "\(role): \(message.text)\n"
            }
            context += "\n"
        }
        
        return context
    }
    
    private func formatTimeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 {
            return "\(seconds)s ago"
        } else if seconds < 3600 {
            return "\(seconds / 60)m ago"
        } else {
            return "\(seconds / 3600)h ago"
        }
    }
    
    // MARK: - Event Extraction
    
    private func extractEvent(from response: String) async -> String? {
        // Look for [FUNCTION:function_name] in response
        if let range = response.range(of: #"\[FUNCTION:(\w+)\]"#, options: .regularExpression) {
            let functionTag = String(response[range])
            if let functionName = functionTag.split(separator: ":").last?.dropLast() {
                return String(functionName)
            }
        }
        
        // Fallback: Simple keyword detection
        let lowercased = response.lowercased()
        if lowercased.contains("log") && (lowercased.contains("water") || lowercased.contains("drink")) {
            return "log_water_intake"
        } else if lowercased.contains("goal") {
            return "set_hydration_goal"
        } else if lowercased.contains("status") || lowercased.contains("progress") {
            return "hydration_status"
        } else if lowercased.contains("remind") || lowercased.contains("reminder") || lowercased.contains("hydrate") {
            return "hydration_prompt"
        }
        
        return nil
    }
    
    // MARK: - Conversation Management
    
    func addToHistory(_ message: Message) {
        conversationHistory.append(message)
        
        // Keep history manageable
        if conversationHistory.count > 20 {
            conversationHistory.removeFirst(conversationHistory.count - 20)
        }
    }
    
    func clearHistory() {
        conversationHistory.removeAll()
    }
    
    // MARK: - BLE Event Management
    
    func addBLEEvent(_ event: DetectedEvent) {
        bleEvents.append(event)
        
        // Keep BLE events manageable (last 10)
        if bleEvents.count > 10 {
            bleEvents.removeFirst(bleEvents.count - 10)
        }
        
        TimestampUtility.log("LLM context updated with BLE event: \(event.name)", category: "LLMManager")
    }
    
    func clearBLEEvents() {
        bleEvents.removeAll()
    }
    
    func getBLEContext() -> String {
        guard !bleEvents.isEmpty else {
            return "No recent hardware events."
        }
        
        var context = "Recent hardware events:\n"
        for event in bleEvents.suffix(5) {
            let timeAgo = formatTimeAgo(event.timestamp)
            context += "• \(event.displayName) (\(timeAgo))\n"
        }
        return context
    }
    
}

