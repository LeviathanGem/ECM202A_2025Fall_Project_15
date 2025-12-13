//
//  ChatView.swift
//  OdysseyTest
//
//  Local chat interface with speech input
//

import SwiftUI

struct ChatView: View {
    @StateObject private var speechRecognizer = LocalSpeechRecognizer()
    @StateObject private var conversationManager: ConversationManager
    @StateObject private var llmManager = LLMManager()
    @StateObject private var modelDownloader = ModelDownloader()
    @State private var messages: [Message] = []
    @State private var textInput = ""
    @State private var showingPermissionAlert = false
    @State private var showingModelSetup = false
    
    init(conversationManager: ConversationManager) {
        _conversationManager = StateObject(wrappedValue: conversationManager)
    }
    
    var body: some View {
        ZStack {
            // Main chat interface
            chatInterface
            
            // Model setup overlay
            if !modelDownloader.isModelReady || !llmManager.isLoaded {
                modelSetupView
            }
        }
        .navigationTitle("AI Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                modelStatusButton
            }
        }
        .onAppear {
            setupSpeechRecognizer()
            checkModelStatus()
            syncBLEEventsToLLM()  // Sync BLE events when view appears
        }
        .alert("Speech Recognition Permission", isPresented: $showingPermissionAlert) {
            Button("OK", role: .cancel) { }
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("Please grant speech recognition access in Settings to use voice input.")
        }
    }
    
    // MARK: - Main Chat Interface
    
    private var chatInterface: some View {
        VStack(spacing: 0) {
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        // Welcome message
                        if messages.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "message.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.blue.opacity(0.6))
                                
                                Text("Local Assistant")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                
                                Text("Tap the microphone or type to chat")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                
                                Text("✨ 100% free • Works offline • Private")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                    .padding(.top, 4)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 100)
                        }
                        
                        // Message bubbles
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _ in
                    // Scroll to bottom when new message arrives
                    if let lastMessage = messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Input area
            VStack(spacing: 12) {
                // Transcription indicator
                if speechRecognizer.isRecording {
                    HStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        Text(speechRecognizer.transcribedText.isEmpty ? "Listening..." : speechRecognizer.transcribedText)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                HStack(spacing: 12) {
                    // Text input
                    TextField("Type a message...", text: $textInput)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            sendTextMessage()
                        }
                    
                    // Voice input button
                    Button(action: toggleRecording) {
                        ZStack {
                            Circle()
                                .fill(speechRecognizer.isRecording ? Color.red : Color.blue)
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: speechRecognizer.isRecording ? "stop.fill" : "mic.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 20))
                        }
                    }
                    .disabled(!speechRecognizer.isAuthorized)
                    
                    // Send button (if text entered)
                    if !textInput.isEmpty {
                        Button(action: sendTextMessage) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .background(Color(.systemBackground))
        }
    }
    
    // MARK: - Model Setup View
    
    private var modelSetupView: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Image(systemName: "brain")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Local AI Model")
                    .font(.title2)
                    .fontWeight(.bold)
                
                if !modelDownloader.isModelReady {
                    // Model not downloaded
                    if modelDownloader.isDownloading {
                        VStack(spacing: 12) {
                            ProgressView(value: modelDownloader.downloadProgress)
                                .progressViewStyle(.linear)
                            Text("\(Int(modelDownloader.downloadProgress * 100))% - Downloading...")
                                .font(.caption)
                        }
                        .padding(.horizontal, 40)
                        
                        Button("Cancel") {
                            modelDownloader.cancelDownload()
                        }
                        .foregroundColor(.red)
                    } else {
                        Text("Download TinyLlama 1.1B model")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        Text("Size: ~669 MB")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Button(action: {
                            modelDownloader.downloadModel()
                        }) {
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                Text("Download Model")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                    }
                } else if !llmManager.isLoaded {
                    // Model downloaded but not loaded
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading model...")
                            .font(.caption)
                    }
                }
                
                if let error = llmManager.loadError ?? modelDownloader.downloadError {
                    Text("Error: \(error)")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .padding(30)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(radius: 20)
            .padding(40)
        }
    }
    
    private var modelStatusButton: some View {
        Button(action: {
            showingModelSetup.toggle()
        }) {
            HStack(spacing: 4) {
                Circle()
                    .fill(llmManager.isLoaded ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(llmManager.isLoaded ? "AI Ready" : "AI Loading")
                    .font(.caption)
            }
        }
    }
    
    // MARK: - Actions
    
    private func setupSpeechRecognizer() {
        speechRecognizer.onFinished = { [self] transcription in
            guard !transcription.isEmpty else { return }
            self.processUserMessage(transcription)
        }
    }
    
    private func addInitialMessage() {
        guard messages.isEmpty else { return }
        let welcomeMessage = Message(
            text: "👋 Hi! I'm your local hydration coach powered by a 1B LLM running entirely on your iPhone. Ask me to log water, set a goal, or check your status.",
            sender: .bot
        )
        messages.append(welcomeMessage)
    }
    
    private func checkModelStatus() {
        if modelDownloader.isModelReady && !llmManager.isLoaded {
            llmManager.loadModel()
        }
    }
    
    private func toggleRecording() {
        if !speechRecognizer.isAuthorized {
            showingPermissionAlert = true
            return
        }
        
        if speechRecognizer.isRecording {
            speechRecognizer.stopRecording()
        } else {
            speechRecognizer.startRecording()
        }
    }
    
    private func sendTextMessage() {
        guard !textInput.isEmpty else { return }
        let text = textInput
        textInput = ""
        processUserMessage(text)
    }
    
    private func processUserMessage(_ text: String) {
        // Update LLM with latest BLE events before processing
        syncBLEEventsToLLM()
        
        // Add user message
        let userMessage = Message(text: text, sender: .user)
        messages.append(userMessage)
        llmManager.addToHistory(userMessage)
        
        // Add "thinking" indicator
        let thinkingMessage = Message(text: "...", sender: .bot)
        messages.append(thinkingMessage)
        
        // Generate response with LLM
        llmManager.generate(prompt: text) { response, eventName in
            DispatchQueue.main.async {
                // Remove thinking indicator
                if let thinkingIndex = self.messages.firstIndex(where: { $0.id == thinkingMessage.id }) {
                    self.messages.remove(at: thinkingIndex)
                }
                
                // Clean up response (remove function tags)
                let cleanResponse = response.replacingOccurrences(of: #"\[FUNCTION:\w+\]"#, with: "", options: .regularExpression)
                
                // Add bot response
                let botMessage = Message(
                    text: cleanResponse.trimmingCharacters(in: .whitespacesAndNewlines),
                    sender: .bot,
                    relatedEvent: eventName
                )
                self.messages.append(botMessage)
                self.llmManager.addToHistory(botMessage)
                
                // Log event if detected
                if let eventName = eventName {
                    let event = DetectedEvent(name: eventName, timestamp: Date(), arguments: [:])
                    self.conversationManager.detectedEvents.append(event)
                    print("LLM detected event: \(eventName)")
                }
            }
        }
    }
    
    private func syncBLEEventsToLLM() {
        // Pass BLE events to local LLM for context
        let bleEvents = conversationManager.detectedEvents.filter { event in
            // Only include BLE-related events
            ["alexa_wake_word", "ndp_event", "command", "test_message", "ble_message"].contains(event.name)
        }
        
        for event in bleEvents {
            llmManager.addBLEEvent(event)
        }
    }
}

// MARK: - Message Bubble Component

struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.sender == .user {
                Spacer()
            }
            
            VStack(alignment: message.sender == .user ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .padding(12)
                    .background(message.sender == .user ? Color.blue : Color.gray.opacity(0.2))
                    .foregroundColor(message.sender == .user ? .white : .primary)
                    .cornerRadius(16)
                
                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: 280, alignment: message.sender == .user ? .trailing : .leading)
            
            if message.sender == .bot {
                Spacer()
            }
        }
    }
}

#Preview {
    NavigationView {
        ChatView(conversationManager: ConversationManager(apiKey: "preview"))
    }
}

