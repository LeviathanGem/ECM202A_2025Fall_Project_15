//
//  OpenAIRealtimeService.swift
//  OdysseyTest
//
//  Handles WebSocket connection to OpenAI Realtime API
//

import Foundation
import AVFoundation

class OpenAIRealtimeService: NSObject, ObservableObject {
    @Published var isConnected = false
    @Published var transcribedText = ""
    @Published var detectedEvents: [String] = []
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var apiKey: String
    private var bleEventsContext: String = ""
    
    // Callbacks
    var onResponseReceived: ((String) -> Void)?
    var onEventDetected: ((String, [String: Any]) -> Void)?
    var onError: ((Error) -> Void)?
    
    init(apiKey: String) {
        self.apiKey = apiKey
        super.init()
    }
    
    // MARK: - Connection Management
    
    func connect() {
        let startTime = Date()
        guard !isConnected else { return }
        
        TimestampUtility.log("Connecting to OpenAI Realtime API...", category: "OpenAI")
        
        var request = URLRequest(url: URL(string: "wss://api.openai.com/v1/realtime?model=gpt-4o-realtime-preview-2024-10-01")!)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("realtime=v1", forHTTPHeaderField: "OpenAI-Beta")
        
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()
        
        receiveMessage()
        
        // Send initial session configuration
        sendSessionUpdate()
        
        let elapsed = TimestampUtility.elapsed(since: startTime)
        
        DispatchQueue.main.async {
            self.isConnected = true
        }
        TimestampUtility.logPerformance("OpenAI WebSocket connection", duration: elapsed)
    }
    
    func disconnect() {
        guard webSocketTask != nil else {
            // Already disconnected
            return
        }
        
        TimestampUtility.log("Disconnecting from OpenAI Realtime API", category: "OpenAI")
        
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        
        DispatchQueue.main.async {
            self.isConnected = false
        }
        TimestampUtility.log("Disconnected from OpenAI Realtime API", category: "OpenAI")
    }
    
    // MARK: - Session Configuration
    
    private func sendSessionUpdate() {
        let sessionConfig: [String: Any] = [
            "type": "session.update",
            "session": [
                "modalities": ["text", "audio"],
                "instructions": """
                    You are a hydration-focused JITAI assistant for Odyssey Companion.
                    Your role is to:
                    1. Keep responses concise, encouraging, and action-oriented.
                    2. Use sensor context (keyboard/faucet/background) to infer interruptibility.
                    3. Avoid prompting during busy/meeting times; prefer breaks.
                    4. Detect intents like logging water, checking status, setting goals, or offering a nudge.
                    5. Reflect BLE events from the Nicla Voice device in your reasoning when relevant.
                    
                    \(bleEventsContext.isEmpty ? "" : "\n=== Recent Hardware Events ===\n\(bleEventsContext)")
                    """,
                "voice": "alloy",
                "input_audio_format": "pcm16",
                "output_audio_format": "pcm16",
                "input_audio_transcription": [
                    "model": "whisper-1"
                ],
                "turn_detection": [
                    "type": "server_vad",
                    "threshold": 0.5,
                    "prefix_padding_ms": 300,
                    "silence_duration_ms": 500
                ],
                "tools": [
                    [
                        "type": "function",
                        "name": "log_water_intake",
                        "description": "Called when user reports drinking water",
                        "parameters": [
                            "type": "object",
                            "properties": [
                                "amount_ml": [
                                    "type": "number",
                                    "description": "Estimated milliliters consumed"
                                ]
                            ] as [String: Any],
                            "required": []
                        ]
                    ],
                    [
                        "type": "function",
                        "name": "set_hydration_goal",
                        "description": "Called when user wants to change their daily hydration target",
                        "parameters": [
                            "type": "object",
                            "properties": [
                                "goal_ml": [
                                    "type": "number",
                                    "description": "Desired daily goal in milliliters"
                                ]
                            ] as [String: Any],
                            "required": []
                        ]
                    ],
                    [
                        "type": "function",
                        "name": "hydration_status",
                        "description": "Called when summarizing current intake vs goal",
                        "parameters": [
                            "type": "object",
                            "properties": [:] as [String: Any],
                            "required": []
                        ]
                    ],
                    [
                        "type": "function",
                        "name": "hydration_prompt",
                        "description": "Called when proactively nudging a sip based on context",
                        "parameters": [
                            "type": "object",
                            "properties": [:] as [String: Any],
                            "required": []
                        ]
                    ]
                ]
            ]
        ]
        
        sendMessage(sessionConfig)
    }
    
    // MARK: - Send Audio
    
    func sendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // Check connection state
        guard isConnected, webSocketTask?.state == .running else {
            if !isConnected {
                print("Socket is not connected")
            }
            return
        }
        
        // Validate buffer has data
        guard buffer.frameLength > 0 else {
            print("Buffer is empty, skipping")
            return
        }
        
        // Convert PCM buffer to base64-encoded audio data
        guard let audioData = bufferToData(buffer) else {
            print("Failed to convert buffer to data")
            return
        }
        
        let base64Audio = audioData.base64EncodedString()
        
        let message: [String: Any] = [
            "type": "input_audio_buffer.append",
            "audio": base64Audio
        ]
        
        sendMessage(message)
    }
    
    func commitAudio() {
        let message: [String: Any] = [
            "type": "input_audio_buffer.commit"
        ]
        sendMessage(message)
    }
    
    func clearAudioBuffer() {
        let message: [String: Any] = [
            "type": "input_audio_buffer.clear"
        ]
        sendMessage(message)
    }
    
    // MARK: - Message Handling
    
    private func sendMessage(_ message: [String: Any]) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: message),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }
        
        let message = URLSessionWebSocketTask.Message.string(jsonString)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("WebSocket send error: \(error.localizedDescription)")
            }
        }
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                
                // Continue receiving
                self.receiveMessage()
                
            case .failure(let error):
                print("WebSocket receive error: \(error.localizedDescription)")
                self.onError?(error)
            }
        }
    }
    
    private func handleMessage(_ text: String) {
        let messageReceiveTime = Date()
        
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            DebugLogger.shared.log(.warn, category: "OpenAI", message: "Failed to decode message: \(text.prefix(200))")
            return
        }
        
        TimestampUtility.log("Received: \(type)", category: "OpenAI")
        DebugLogger.shared.log(.debug, category: "OpenAI", message: "Received: \(type)")
        
        switch type {
        case "session.created", "session.updated":
            print("Session initialized")
            
        case "input_audio_buffer.speech_started":
            print("Speech detected")
            
        case "input_audio_buffer.speech_stopped":
            print("Speech ended")
            
        case "input_audio_buffer.committed":
            print("Audio buffer committed")
            
        case "conversation.item.created":
            print("Conversation item created")
            
        case "conversation.item.input_audio_transcription.completed":
            if let transcript = json["transcript"] as? String {
                DispatchQueue.main.async {
                    self.transcribedText = transcript
                }
                let elapsed = TimestampUtility.elapsed(since: messageReceiveTime)
                TimestampUtility.log("Transcription completed (\(elapsed)ms): \(transcript)", category: "OpenAI")
            }
            
        case "conversation.item.input_audio_transcription.failed":
            if let error = json["error"] as? [String: Any] {
                TimestampUtility.log("ERROR: Transcription failed: \(error)", category: "OpenAI")
            } else {
                TimestampUtility.log("ERROR: Transcription failed (no error details)", category: "OpenAI")
            }
            
        case "response.created":
            print("AI response started")
            
        case "response.text.delta":
            if let delta = json["delta"] as? String {
                DispatchQueue.main.async {
                    self.transcribedText += delta
                }
                print("AI text: \(delta)")
            }
            
        case "response.text.done":
            if let text = json["text"] as? String {
                print("AI response text: \(text)")
                onResponseReceived?(text)
            }
            
        case "response.audio_transcript.delta":
            if let delta = json["delta"] as? String {
                DispatchQueue.main.async {
                    self.transcribedText += delta
                }
                print("AI says: \(delta)")
            }
            
        case "response.audio_transcript.done":
            if let transcript = json["transcript"] as? String {
                print("AI said: \(transcript)")
                onResponseReceived?(transcript)
            }
            
        case "response.function_call_arguments.done":
            if let name = json["name"] as? String,
               let arguments = json["arguments"] as? String {
                TimestampUtility.log("Function call detected: \(name)", category: "OpenAI")
                self.handleFunctionCall(name: name, arguments: arguments)
            }
            
        case "response.done":
            let elapsed = TimestampUtility.elapsed(since: messageReceiveTime)
            TimestampUtility.logPerformance("OpenAI response completed", duration: elapsed)
            
        case "error":
            if let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                TimestampUtility.log("ERROR: API Error: \(message)", category: "OpenAI")
                let error = NSError(domain: "OpenAI", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
                self.onError?(error)
            }
            
        default:
            // Log unhandled message types for debugging
            print("Unhandled message type: \(type)")
            break
        }
    }
    
    private func handleFunctionCall(name: String, arguments: String) {
        print("Function called: \(name)")
        
        DispatchQueue.main.async {
            self.detectedEvents.append(name)
        }
        
        var argsDict: [String: Any] = [:]
        if let data = arguments.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            argsDict = json
        }
        
        onEventDetected?(name, argsDict)
    }
    
    // MARK: - BLE Context Management
    
    func updateBLEContext(_ events: [DetectedEvent]) {
        guard !events.isEmpty else {
            bleEventsContext = ""
            return
        }
        
        var context = ""
        for event in events.suffix(5) {
            let timeAgo = formatTimeAgo(event.timestamp)
            context += "• \(event.displayName) (\(timeAgo))\n"
        }
        bleEventsContext = context
        
        // Update session if connected
        if isConnected {
            sendSessionUpdate()
        }
        
        TimestampUtility.log("OpenAI context updated with BLE events", category: "OpenAI")
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
    
    // MARK: - Utility
    
    private func bufferToData(_ buffer: AVAudioPCMBuffer) -> Data? {
        let audioBuffer = buffer.audioBufferList.pointee.mBuffers
        let data = Data(bytes: audioBuffer.mData!, count: Int(audioBuffer.mDataByteSize))
        return data
    }
}

// MARK: - URLSessionWebSocketDelegate

extension OpenAIRealtimeService: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("WebSocket connected")
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("WebSocket disconnected")
        DispatchQueue.main.async {
            self.isConnected = false
        }
    }
}

