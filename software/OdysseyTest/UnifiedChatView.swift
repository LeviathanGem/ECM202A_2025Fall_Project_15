//
//  UnifiedChatView.swift
//  OdysseyTest
//
//  Unified chat interface supporting Cloud, Local, and Hybrid modes
//

import SwiftUI

struct UnifiedChatView: View {
    @StateObject private var viewModel: UnifiedChatViewModel
    @StateObject private var bleManager = BLEManager()
    @State private var inputText = ""
    @State private var isRecording = false
    @State private var showingBLESettings = false
    @State private var showingDebugLogs = false
    @FocusState private var isInputFocused: Bool
    
    init(conversationManager: ConversationManager) {
        _viewModel = StateObject(wrappedValue: UnifiedChatViewModel(conversationManager: conversationManager))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Mode selector
            modeSelectorView
            
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubbleView(message: message)
                                .id(message.id)
                        }
                        
                        // Loading indicators
                        if viewModel.isProcessing {
                            loadingIndicatorsView
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { _ in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onTapGesture {
                    // Dismiss keyboard when tapping on the messages area
                    isInputFocused = false
                }
            }
            
            // Input area
            inputAreaView
        }
        .navigationTitle("AI Assistant")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // BLE Status and Settings
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    showingBLESettings = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: bleManager.isConnected ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                        Text(bleManager.isConnected ? "BLE" : "BLE")
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(bleManager.isConnected ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                    .cornerRadius(12)
                }
                .foregroundColor(bleManager.isConnected ? .green : .gray)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: viewModel.clearHistory) {
                        Label("Clear History", systemImage: "trash")
                    }
                    
                    Button(action: { viewModel.clearAllEvents() }) {
                        Label("Clear Events", systemImage: "trash.circle")
                    }
                    
                    Button(action: viewModel.exportHistory) {
                        Label("Export Chat", systemImage: "square.and.arrow.up")
                    }
                    
                    // Testing helper: reset hydration prompt cooldown
                    Button(action: viewModel.resetHydrationPromptCooldown) {
                        Label("Reset Hydration Cooldown", systemImage: "clock.arrow.circlepath")
                    }
                    
                    Button(action: { showingDebugLogs = true }) {
                        Label("Debug Logs", systemImage: "ladybug")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingBLESettings) {
            BLESettingsView(bleManager: bleManager)
        }
        .sheet(isPresented: $showingDebugLogs) {
            DebugLogView()
        }
        .onAppear {
            setupBLEHandler()
        }
    }
    
    // MARK: - Mode Selector
    
    private var modeSelectorView: some View {
        HStack(spacing: 0) {
            ForEach(ChatMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectedMode = mode
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: mode.icon)
                            .font(.title3)
                        Text(mode.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(viewModel.selectedMode == mode ? modeColor(mode) : Color.clear)
                    .foregroundColor(viewModel.selectedMode == mode ? .white : .primary)
                }
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private func modeColor(_ mode: ChatMode) -> Color {
        switch mode {
        case .cloud: return .blue
        case .local: return .green
        case .hybrid: return .purple
        }
    }
    
    // MARK: - Loading Indicators
    
    private var loadingIndicatorsView: some View {
        HStack(spacing: 20) {
            if viewModel.selectedMode == .cloud || viewModel.selectedMode == .hybrid {
                loadingBubble(title: "Cloud AI", color: .blue)
            }
            
            if viewModel.selectedMode == .local || viewModel.selectedMode == .hybrid {
                loadingBubble(title: "Local AI", color: .green)
            }
        }
        .padding(.horizontal)
    }
    
    private func loadingBubble(title: String, color: Color) -> some View {
        HStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
            Text(title)
                .font(.caption)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.8))
        .cornerRadius(16)
    }
    
    // MARK: - Input Area
    
    private var inputAreaView: some View {
        VStack(spacing: 8) {
            // Status info
            if viewModel.selectedMode == .local && !viewModel.isLocalModelLoaded {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Local model not loaded")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Load") {
                        viewModel.loadLocalModel()
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(.horizontal)
            }
            
            // Input field with buttons
            HStack(spacing: 12) {
                // Voice button
                Button {
                    toggleVoiceInput()
                } label: {
                    Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.title2)
                        .foregroundColor(isRecording ? .red : .blue)
                }
                .disabled(viewModel.selectedMode == .local) // Voice only works for cloud
                
                // Text input
                TextField("Message", text: $inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .focused($isInputFocused)
                    .onSubmit {
                        sendMessage()
                    }
                    .submitLabel(.send)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                isInputFocused = false
                            }
                        }
                    }
                
                // Send button
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(inputText.isEmpty ? .gray : .blue)
                }
                .disabled(inputText.isEmpty || viewModel.isProcessing)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
        .overlay(
            Divider()
                .frame(maxWidth: .infinity, maxHeight: 1)
                .background(Color.gray.opacity(0.3)),
            alignment: .top
        )
    }
    
    // MARK: - Actions
    
    private func sendMessage() {
        guard !inputText.isEmpty else { return }
        viewModel.sendMessage(inputText)
        inputText = ""
        isInputFocused = false // Dismiss keyboard after sending
    }
    
    private func toggleVoiceInput() {
        if isRecording {
            viewModel.stopVoiceInput()
            isRecording = false
        } else {
            viewModel.startVoiceInput()
            isRecording = true
        }
    }
    
    // MARK: - BLE Integration
    
    private func setupBLEHandler() {
        bleManager.onEventReceived = { [self] message in
            // Parse the BLE message and create an event
            let eventName: String
            let displayMessage: String
            
            if message.hasPrefix("ACT:") {
                let label = message.replacingOccurrences(of: "ACT: ", with: "").lowercased()
                switch label {
                case "keyboard":
                    eventName = "activity_keyboard"
                    displayMessage = "Keyboard activity"
                case "faucet":
                    eventName = "activity_faucet"
                    displayMessage = "Break detected (faucet)"
                case "background":
                    eventName = "activity_background"
                    displayMessage = "Background/idle"
                default:
                    eventName = "activity_background"
                    displayMessage = label.isEmpty ? "Background" : label
                }
            } else if message.hasPrefix("MATCH:") {
                let lowered = message.lowercased()
                if lowered.contains("nn0:keyboard") {
                    eventName = "activity_keyboard"
                    displayMessage = "Keyboard activity"
                } else if lowered.contains("nn0:faucet") {
                    eventName = "activity_faucet"
                    displayMessage = "Break detected (faucet)"
                } else {
                    eventName = "alexa_wake_word"
                    displayMessage = message.replacingOccurrences(of: "MATCH: ", with: "")
                }
            } else if message.hasPrefix("EVENT:") {
                eventName = "ndp_event"
                displayMessage = message.replacingOccurrences(of: "EVENT: ", with: "")
            } else if message.hasPrefix("CMD:") {
                eventName = "command"
                displayMessage = message.replacingOccurrences(of: "CMD: ", with: "")
            } else if message.hasPrefix("TEST:") {
                eventName = "test_message"
                displayMessage = message.replacingOccurrences(of: "TEST: ", with: "")
            } else {
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
                // Add to conversation manager
                viewModel.addBLEEvent(event)
                
                // Add as system message in chat
                let systemMessage = ChatMessage(
                    text: "🔔 Hardware Event: \(event.displayName)",
                    isUser: false,
                    source: nil
                )
                viewModel.messages.append(systemMessage)
                
                print("📡 BLE event received: \(event.displayName)")
            }
        }
    }
}

// MARK: - Message Bubble View

struct MessageBubbleView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                // Source label for hybrid mode
                if let source = message.source, message.source != .user {
                    Text(source.displayName)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(sourceColor(source))
                }
                
                Text(message.text)
                    .font(.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(bubbleColor)
                    .foregroundColor(message.isUser ? .white : .primary)
                    .cornerRadius(16)
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: 280, alignment: message.isUser ? .trailing : .leading)
            
            if !message.isUser {
                Spacer()
            }
        }
    }
    
    private var bubbleColor: Color {
        if message.isUser {
            return .blue
        }
        
        switch message.source {
        case .cloudLLM:
            return Color.blue.opacity(0.15)
        case .localLLM:
            return Color.green.opacity(0.15)
        default:
            return Color(.systemGray5)
        }
    }
    
    private func sourceColor(_ source: MessageSource) -> Color {
        switch source {
        case .cloudLLM: return .blue
        case .localLLM: return .green
        case .user: return .gray
        }
    }
}

// MARK: - Models

enum ChatMode: String, CaseIterable {
    case cloud = "Cloud"
    case local = "Local"
    case hybrid = "Hybrid"
    
    var icon: String {
        switch self {
        case .cloud: return "cloud.fill"
        case .local: return "iphone"
        case .hybrid: return "arrow.triangle.branch"
        }
    }
}

enum MessageSource {
    case user
    case cloudLLM
    case localLLM
    
    var displayName: String {
        switch self {
        case .user: return "You"
        case .cloudLLM: return "☁️ Cloud AI"
        case .localLLM: return "📱 Local AI"
        }
    }
}

struct ChatMessage: Identifiable {
    let id: UUID
    let text: String
    let timestamp: Date
    let isUser: Bool
    let source: MessageSource?
    
    init(text: String, isUser: Bool, source: MessageSource? = nil) {
        self.id = UUID()
        self.text = text
        self.timestamp = Date()
        self.isUser = isUser
        self.source = source
    }
}

#Preview {
    NavigationView {
        UnifiedChatView(conversationManager: ConversationManager(apiKey: "test"))
    }
}

