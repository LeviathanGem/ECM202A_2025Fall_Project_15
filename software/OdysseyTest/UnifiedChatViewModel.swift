//
//  UnifiedChatViewModel.swift
//  OdysseyTest
//
//  View model managing Cloud, Local, and Hybrid chat modes
//

import Foundation
import Combine
import UIKit

class UnifiedChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var selectedMode: ChatMode = .cloud
    @Published var isProcessing = false
    @Published var isLocalModelLoaded = false
    
    private let conversationManager: ConversationManager
    private let llmManager = LLMManager()
    private let chatService = OpenAIChatService(apiKey: Config.apiKey)
    private let speechRecognizer = LocalSpeechRecognizer()
    private let nudgeHistoryStore = NudgeHistoryStore.shared
    private let calendarManager = CalendarManager.shared
    private var nudgeTimer: Timer?
    private var contextLogTimer: Timer?
    private let nudgeQueue = DispatchQueue(label: "odyssey.nudge.queue", qos: .utility)
    
    // Activity streak tracking to stabilize noisy ACT streams
    private var activityStreakLabel: ActivityLabel = .unknown
    private var activityStreakCount: Int = 0
    private var lastStableActivity: ActivityLabel = .unknown
    private var lastStableActivityAt: Date = .distantPast
    
    init(conversationManager: ConversationManager) {
        self.conversationManager = conversationManager
        setupCallbacks()
        startNudgeLoop()
        startContextBusLogging()
    }
    
    deinit {
        nudgeTimer?.invalidate()
        contextLogTimer?.invalidate()
    }
    
    // MARK: - Setup
    
    private func setupCallbacks() {
        // Monitor local model status
        llmManager.$isLoaded
            .assign(to: &$isLocalModelLoaded)
    }

    // MARK: - Notifications
    
    /// For regular chat replies: only notify when app is not active, to avoid spamming the user.
    private func notifyIfInBackground(title: String, body: String) {
        let state = UIApplication.shared.applicationState
        guard state != .active else { return }
        scheduleTrimmedNotification(title: title, body: body)
    }
    
    /// For hydration nudges: always notify (even when app is open), since these are the main JITAI signals.
    private func notifyForNudgeAnywhere(title: String, body: String) {
        scheduleTrimmedNotification(title: title, body: body)
    }
    
    private func scheduleTrimmedNotification(title: String, body: String) {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let shortBody = trimmed.count > 140 ? String(trimmed.prefix(137)) + "..." : trimmed
        guard !shortBody.isEmpty else { return }
        NotificationManager.shared.scheduleNotification(title: title, body: shortBody)
    }
    
    // MARK: - Context Bus Logging
    
    /// Periodically log the high-level context bus that feeds the JITAI LLM
    private func startContextBusLogging() {
        contextLogTimer?.invalidate()
        contextLogTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.logContextBusSnapshot()
        }
        contextLogTimer?.tolerance = 2
    }
    
    private func logContextBusSnapshot() {
        // Only log when local model is available (i.e., JITAI can actually use this context)
        guard isLocalModelLoaded else { return }
        
        let now = Date()
        let hydrationState = HydrationStore.shared.loadToday()
        let totalIntake = hydrationState.entries.reduce(0) { $0 + $1.amount }
        let goal = max(hydrationState.dailyGoal, 500)
        let remaining = max(goal - totalIntake, 0)
        let lastDrinkTime = hydrationState.entries.sorted { $0.timestamp < $1.timestamp }.last?.timestamp
        let lastDrinkString: String
        if let lastDrink = lastDrinkTime {
            let minutesAgo = Int(now.timeIntervalSince(lastDrink) / 60)
            if minutesAgo < 60 {
                lastDrinkString = "\(minutesAgo)m ago"
            } else {
                let hoursAgo = minutesAgo / 60
                let remainingMinutes = minutesAgo % 60
                lastDrinkString = "\(hoursAgo)h \(remainingMinutes)m ago"
            }
        } else {
            lastDrinkString = "none yet"
        }
        
        // Calculate time progress based on user-configured hydration window
        let window = HydrationStore.shared.getHydrationWindow()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: now)
        let currentHour = components.hour ?? 12
        let currentMinute = components.minute ?? 0
        let currentMinuteOfDay = currentHour * 60 + currentMinute
        let hydrationStartMinute = window.startHour * 60
        let hydrationEndMinute = window.endHour * 60
        let totalHydrationWindow = hydrationEndMinute - hydrationStartMinute
        let elapsedMinutes = max(0, currentMinuteOfDay - hydrationStartMinute)
        let timeProgress = min(1.0, Double(elapsedMinutes) / Double(totalHydrationWindow))
        let expectedIntake = Int(Double(goal) * timeProgress)
        let progressGap = totalIntake - expectedIntake
        
        // Activity context last 3 hours
        let activityWindowStart = Calendar.current.date(byAdding: .hour, value: -3, to: now) ?? now
        let activityEvents = conversationManager.detectedEvents.filter { event in
            event.timestamp >= activityWindowStart &&
            (event.name == "activity_keyboard" || event.name == "activity_faucet" || event.name == "activity_background")
        }
        let activityLines = activityEvents.suffix(10).map {
            let label = activityLabel(for: $0).rawValue
            return "• \(label) at \($0.timestamp.formatted(date: .omitted, time: .shortened))"
        }.joined(separator: "\n")
        
        // Calendar context: events whose [start, end] intersect the window [now-3h, now+3h]
        let calendarWindowStart = Calendar.current.date(byAdding: .hour, value: -3, to: now) ?? now
        let calendarWindowEnd = Calendar.current.date(byAdding: .hour, value: 3, to: now) ?? now
        let windowEvents = calendarManager.events.filter { event in
            guard !event.isCompleted else { return false }
            return event.effectiveEndDate >= calendarWindowStart && event.date <= calendarWindowEnd
        }
        let calendarLines = windowEvents.prefix(5).map { event in
            if event.isAllDay {
                return "• \(event.title) (all day \(event.date.formatted(date: .abbreviated, time: .omitted)))"
            } else {
                let startStr = event.date.formatted(date: .abbreviated, time: .shortened)
                let endStr = event.effectiveEndDate.formatted(date: .omitted, time: .shortened)
                return "• \(event.title) @ \(startStr)-\(endStr)"
            }
        }.joined(separator: "\n")
        
        // Nudge history (7d)
        let recentNudges = nudgeHistoryStore.recent(days: 7)
        let nudgeLines = recentNudges.prefix(5).map {
            "• \($0.timestamp.formatted(date: .abbreviated, time: .shortened)): \($0.message)"
        }.joined(separator: "\n")
        
        // Raw BLE event count for extra context
        let totalBLEEvents = conversationManager.detectedEvents.count
        
        let snapshot = """
        Context bus @ \(now.timestamp)
        Hydration: \(totalIntake)/\(goal) ml (remaining \(remaining) ml), entries today: \(hydrationState.entries.count)
        Last drink: \(lastDrinkString)
        Expected by now: ~\(expectedIntake) ml (gap: \(progressGap >= 0 ? "+" : "")\(progressGap) ml)
        BLE events (total): \(totalBLEEvents)
        
        Activity last 3h:
        \(activityLines.isEmpty ? "• none" : activityLines)
        
        Calendar ±3h (past & upcoming):
        \(calendarLines.isEmpty ? "• none" : calendarLines)
        
        Nudge history (7d, \(recentNudges.count) total):
        \(nudgeLines.isEmpty ? "• none" : nudgeLines)
        """
        
        DebugLogger.shared.log(.info, category: "ContextBus", message: snapshot)
    }
    
    // MARK: - Message Sending
    
    func sendMessage(_ text: String) {
        // Add user message
        let userMessage = ChatMessage(text: text, isUser: true, source: .user)
        messages.append(userMessage)
        
        // Process based on mode
        switch selectedMode {
        case .cloud:
            sendToCloud(text)
        case .local:
            sendToLocal(text)
        case .hybrid:
            sendToHybrid(text)
        }
    }
    
    // MARK: - Cloud Mode
    
    private func sendToCloud(_ text: String) {
        isProcessing = true
        
        let systemPrompt = """
        You are a hydration-focused assistant. Be concise, encouraging, and action-oriented. Avoid disruptive timing; acknowledge context briefly.
        """
        
        chatService.sendChat(prompt: text, systemPrompt: systemPrompt) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let response):
                    let aiMessage = ChatMessage(text: response, isUser: false, source: .cloudLLM)
                    self.messages.append(aiMessage)
                    self.notifyIfInBackground(title: "AI Reply (Cloud)", body: response)
                case .failure(let error):
                    let aiMessage = ChatMessage(
                        text: "⚠️ Cloud error: \(error.localizedDescription)",
                        isUser: false,
                        source: .cloudLLM
                    )
                    self.messages.append(aiMessage)
                    DebugLogger.shared.log(.error, category: "OpenAIChat", message: "Chat error: \(error.localizedDescription)")
                }
                self.isProcessing = false
            }
        }
    }
    
    // MARK: - Local Mode
    
    private func sendToLocal(_ text: String) {
        guard isLocalModelLoaded else {
            let errorMessage = ChatMessage(
                text: "⚠️ Local model not loaded. Please load the model first.",
                isUser: false,
                source: .localLLM
            )
            messages.append(errorMessage)
            return
        }
        
        isProcessing = true
        
        // Sync BLE events to local LLM
        syncBLEEventsToLLM()
        
        // Generate response using local LLM
        llmManager.generate(prompt: text) { [weak self] response, event in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let event = event {
                    // Handle detected event
                    let detectedEvent = DetectedEvent(name: event, timestamp: Date())
                    self.conversationManager.detectedEvents.append(detectedEvent)
                }
                
                let aiMessage = ChatMessage(
                    text: response.isEmpty ? "Sorry, I couldn't generate a response." : response,
                    isUser: false,
                    source: .localLLM
                )
                self.messages.append(aiMessage)
                self.notifyIfInBackground(title: "AI Reply (Local)", body: aiMessage.text)
                self.isProcessing = false
            }
        }
    }
    
    private func syncBLEEventsToLLM() {
        let bleEvents = conversationManager.detectedEvents.filter { event in
            ["alexa_wake_word", "ndp_event", "command", "test_message", "ble_message",
             "activity_keyboard", "activity_faucet", "activity_background"].contains(event.name)
        }
        
        for event in bleEvents {
            llmManager.addBLEEvent(event)
        }
    }
    
    // MARK: - Hybrid Mode
    
    private func sendToHybrid(_ text: String) {
        isProcessing = true
        
        var cloudResponseReceived = false
        var localResponseReceived = false
        
        DebugLogger.shared.log(.info, category: "Hybrid", message: "Hybrid request: \(text.prefix(120))")
        
        // Send to cloud
        let systemPrompt = """
        You are a hydration-focused assistant. Be concise, encouraging, and action-oriented. Avoid disruptive timing; acknowledge context briefly.
        """
        chatService.sendChat(prompt: text, systemPrompt: systemPrompt) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let response):
                    let aiMessage = ChatMessage(text: response, isUser: false, source: .cloudLLM)
                    self.messages.append(aiMessage)
                    self.notifyIfInBackground(title: "AI Reply (Cloud)", body: response)
                case .failure(let error):
                    let aiMessage = ChatMessage(
                        text: "⚠️ Cloud error: \(error.localizedDescription)",
                        isUser: false,
                        source: .cloudLLM
                    )
                    self.messages.append(aiMessage)
                    DebugLogger.shared.log(.error, category: "Hybrid", message: "Cloud error: \(error.localizedDescription)")
                }
                cloudResponseReceived = true
                
                if cloudResponseReceived && localResponseReceived {
                    self.isProcessing = false
                    DebugLogger.shared.log(.debug, category: "Hybrid", message: "Hybrid finished (cloud+local)")
                }
            }
        }
        
        // Send to local
        if isLocalModelLoaded {
            syncBLEEventsToLLM()
            
            llmManager.generate(prompt: text) { [weak self] response, event in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    if let event = event {
                        let detectedEvent = DetectedEvent(name: event, timestamp: Date())
                        self.conversationManager.detectedEvents.append(detectedEvent)
                    }
                    
                    let aiMessage = ChatMessage(
                        text: response.isEmpty ? "Sorry, I couldn't generate a response." : response,
                        isUser: false,
                        source: .localLLM
                    )
                    self.messages.append(aiMessage)
                    self.notifyIfInBackground(title: "AI Reply (Local)", body: aiMessage.text)
                    localResponseReceived = true
                    
                    if cloudResponseReceived && localResponseReceived {
                        self.isProcessing = false
                        DebugLogger.shared.log(.debug, category: "Hybrid", message: "Hybrid finished (local+cloud)")
                    }
                }
            }
        } else {
            // Local model not loaded, just wait for cloud
            DispatchQueue.main.async {
                localResponseReceived = true
                let warningMessage = ChatMessage(
                    text: "⚠️ Local model not available",
                    isUser: false,
                    source: .localLLM
                )
                self.messages.append(warningMessage)
            }
        }
    }
    
    // MARK: - Periodic Nudge Loop
    
    private func startNudgeLoop() {
        nudgeTimer?.invalidate()
        nudgeTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.performPeriodicNudgeCheck()
        }
        nudgeTimer?.tolerance = 5
    }
    
    private func performPeriodicNudgeCheck() {
        // Cloud JITAI: periodically send the full context bus to the online LLM,
        // which decides both timing and content. No dependency on local model.
        let now = Date()
        
        // --- Hydration state today (full log) ---
        let hydrationState = HydrationStore.shared.loadToday()
        let totalIntake = hydrationState.entries.reduce(0) { $0 + $1.amount }
        let goal = max(hydrationState.dailyGoal, 500)
        let remaining = max(goal - totalIntake, 0)
        let lastDrinkTime = hydrationState.entries.sorted { $0.timestamp < $1.timestamp }.last?.timestamp
        let lastDrinkString: String
        if let lastDrink = lastDrinkTime {
            let minutesAgo = Int(now.timeIntervalSince(lastDrink) / 60)
            if minutesAgo < 60 {
                lastDrinkString = "\(minutesAgo) minutes ago"
            } else {
                let hoursAgo = minutesAgo / 60
                let remainingMinutes = minutesAgo % 60
                lastDrinkString = "\(hoursAgo)h \(remainingMinutes)m ago"
            }
        } else {
            lastDrinkString = "no drinks yet today"
        }
        let hydrationLines = hydrationState.entries.sorted { $0.timestamp < $1.timestamp }.map {
            "• \($0.timestamp.formatted(date: .omitted, time: .shortened)) — \($0.amount) ml"
        }.joined(separator: "\n")
        
        // --- Events last 3 hours (all labels + timestamps) ---
        let eventWindowStart = Calendar.current.date(byAdding: .hour, value: -3, to: now) ?? now
        let recentEvents = conversationManager.detectedEvents.filter { $0.timestamp >= eventWindowStart }
        let eventLines = recentEvents.sorted { $0.timestamp < $1.timestamp }.map { event in
            let label = activityLabel(for: event).rawValue
            return "• \(event.timestamp.formatted(date: .omitted, time: .shortened)) — \(event.name) (\(label))"
        }.joined(separator: "\n")
        
        // --- Calendar: events whose [start, end] intersect the 6h window [now-3h, now+3h] ---
        let calendarWindowStart = Calendar.current.date(byAdding: .hour, value: -3, to: now) ?? now
        let calendarWindowEnd = Calendar.current.date(byAdding: .hour, value: 3, to: now) ?? now
        let windowEvents = calendarManager.events.filter { event in
            guard !event.isCompleted else { return false }
            return event.effectiveEndDate >= calendarWindowStart && event.date <= calendarWindowEnd
        }
        let calendarLines = windowEvents.sorted { $0.date < $1.date }.prefix(8).map { event in
            if event.isAllDay {
                return "• \(event.title) (all day \(event.date.formatted(date: .abbreviated, time: .omitted)))"
            } else {
                let startStr = event.date.formatted(date: .abbreviated, time: .shortened)
                let endStr = event.effectiveEndDate.formatted(date: .omitted, time: .shortened)
                return "• \(event.title) @ \(startStr)-\(endStr)"
            }
        }.joined(separator: "\n")
        
        // --- Nudge history today (time + content) ---
        let allRecentNudges = nudgeHistoryStore.recent(days: 7)
        let todayNudges = allRecentNudges.filter { Calendar.current.isDateInToday($0.timestamp) }
        let nudgeLines = todayNudges.sorted { $0.timestamp < $1.timestamp }.map {
            "• \($0.timestamp.formatted(date: .omitted, time: .shortened)) — \($0.message)"
        }.joined(separator: "\n")
        
        // Calculate time-based progress based on user-configured hydration window
        let window = HydrationStore.shared.getHydrationWindow()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: now)
        let currentHour = components.hour ?? 12
        let currentMinute = components.minute ?? 0
        let currentMinuteOfDay = currentHour * 60 + currentMinute
        
        let hydrationStartMinute = window.startHour * 60
        let hydrationEndMinute = window.endHour * 60
        let totalHydrationWindow = hydrationEndMinute - hydrationStartMinute
        
        let elapsedMinutes = max(0, currentMinuteOfDay - hydrationStartMinute)
        let timeProgress = min(1.0, Double(elapsedMinutes) / Double(totalHydrationWindow))
        let expectedIntake = Int(Double(goal) * timeProgress)
        let progressGap = totalIntake - expectedIntake
        
        let timeProgressPercent = Int(timeProgress * 100)
        let actualProgressPercent = Int((Double(totalIntake) / Double(goal)) * 100)
        
        let startTimeStr = formatHour(window.startHour)
        let endTimeStr = formatHour(window.endHour)
        
        // Build context bus for LLM
        let contextBus = """
        ⏰ CURRENT TIME: \(now.formatted(date: .abbreviated, time: .shortened))
        (IT IS NOW \(now.formatted(date: .complete, time: .shortened)). Use this to distinguish past vs future events.)
        
        HYDRATION STATE TODAY:
        - Goal: \(goal) ml
        - Total intake so far: \(totalIntake) ml (remaining \(remaining) ml)
        - Last drink: \(lastDrinkString)
        - Time progress: \(timeProgressPercent)% of hydration window (\(startTimeStr) - \(endTimeStr))
        - Expected intake by now: ~\(expectedIntake) ml
        - Progress gap: \(progressGap >= 0 ? "+" : "")\(progressGap) ml (\(progressGap >= 0 ? "ahead" : "behind") schedule)
        - Entries:
        \(hydrationLines.isEmpty ? "• none" : hydrationLines)
        
        EVENTS LAST 3 HOURS (label + timestamp):
        \(eventLines.isEmpty ? "• none" : eventLines)
        
        CALENDAR ±3 HOURS (past & upcoming, ongoing or nearby):
        \(calendarLines.isEmpty ? "• none" : calendarLines)
        
        NUDGES TODAY (time + content):
        \(nudgeLines.isEmpty ? "• none" : nudgeLines)
        """
        
        // STAGE 1: Reasoning prompt
        let reasoningPrompt = """
        You are a hydration-focused JITAI (Just-In-Time Adaptive Intervention) planner.
        
        CRITICAL TIME AWARENESS:
        - The user's hydration goal should be completed between \(startTimeStr) and \(endTimeStr).
        - Intake progress should roughly match time progress through this window.
        - PAY ATTENTION to "Progress gap" in context: negative means behind schedule, positive means ahead.
        - If the calendar shows large blocks of non-interruptible time ahead (meetings/deep work), encourage pre-hydration.
        - Compare event timestamps against CURRENT TIME to distinguish past (already happened) vs future (upcoming).
        
        DECISION MATRIX (consider ALL of these):
        1. Temporal Context & Progress Alignment:
           - Is intake progress aligned with time progress through the \(startTimeStr)–\(endTimeStr) window?
           - Are there long gaps since last drink? Extended work sessions without breaks?
        
        2. Schedule Awareness:
           - Avoid ongoing meetings (check if event timestamps overlap with NOW).
           - Prefer upcoming transitions and breaks.
           - If large non-interruptible blocks are coming, suggest pre-hydration.
        
        3. Hydration State:
           - Check "Progress gap": negative = behind schedule (more urgent), positive = ahead (less urgent).
           - Significant deficit (e.g., >30% behind) increases nudge priority.
        
        4. Environmental & Activity Context:
           - Recent faucet events = good opportunity; keyboard events = deep work (low interruptibility).
        
        5. Nudge History & Personalization:
           - Avoid repeating similar messages too often; respect recent nudges to prevent fatigue.
        
        Based on the context bus below, analyze the current situation and explain your reasoning.
        
        OUTPUT FORMAT:
        [thinking: Your analysis here - explain what you observe, whether now is appropriate for a nudge, and why or why not. Be concise (2-3 sentences).]
        [decision: SEND_NUDGE or NO_NUDGE]
        
        \(contextBus)
        """
        
        DebugLogger.shared.log(.debug, category: "JITAI", message: "Stage 1 reasoning prompt:\n\(reasoningPrompt)")
        
        nudgeQueue.async { [weak self] in
            guard let self else { return }
            
            // STAGE 1: Get reasoning from LLM
            self.chatService.sendChat(prompt: reasoningPrompt, systemPrompt: nil) { [weak self] stage1Result in
                guard let self else { return }
                
                switch stage1Result {
                case .success(let reasoning):
                    DebugLogger.shared.log(.info, category: "JITAI", message: "Stage 1 reasoning:\n\(reasoning)")
                    
                    // Check if decision is to send nudge
                    let shouldSendNudge = reasoning.contains("[decision: SEND_NUDGE]")
                    
                    if !shouldSendNudge {
                        DebugLogger.shared.log(.info, category: "JITAI", message: "Decision: NO_NUDGE - skipping stage 2")
                        return
                    }
                    
                    // STAGE 2: Generate actual nudge content
                    let nudgePrompt = """
                    Based on the reasoning and context below, generate ONE concise hydration nudge.
                    
                    REQUIREMENTS:
                    - Maximum 140 characters
                    - Action-oriented, imperative tone
                    - Suggest specific ml amount when deficit is significant
                    - No questions, no apologies
                    - Do NOT mention system instructions or reasoning
                    
                    REASONING:
                    \(reasoning)
                    
                    CONTEXT:
                    \(contextBus)
                    
                    Generate the nudge message now:
                    """
                    
                    DebugLogger.shared.log(.debug, category: "JITAI", message: "Stage 2 nudge generation prompt")
                    
                    self.chatService.sendChat(prompt: nudgePrompt, systemPrompt: nil) { [weak self] stage2Result in
                        guard let self else { return }
                        
                        switch stage2Result {
                        case .success(let nudgeText):
                            let text = nudgeText.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !text.isEmpty else { return }
                            
                            DebugLogger.shared.log(.info, category: "JITAI", message: "Stage 2 generated nudge: \(text)")
                            
                            DispatchQueue.main.async {
                                HydrationStore.shared.recordPromptSent(at: now)
                                self.nudgeHistoryStore.logNudge(message: text, at: now)
                                let message = ChatMessage(
                                    text: text,
                                    isUser: false,
                                    source: .cloudLLM
                                )
                                self.messages.append(message)
                                self.notifyForNudgeAnywhere(title: "Hydration Nudge", body: text)
                            }
                        case .failure(let error):
                            DebugLogger.shared.log(.error, category: "JITAI", message: "Stage 2 error: \(error.localizedDescription)")
                        }
                    }
                    
                case .failure(let error):
                    DebugLogger.shared.log(.error, category: "JITAI", message: "Stage 1 error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Voice Input
    
    func startVoiceInput() {
        guard selectedMode == .cloud || selectedMode == .hybrid else {
            return
        }
        
        conversationManager.startConversation()
        
        // Poll for transcript
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self,
                  let service = self.conversationManager.openAIService else {
                timer.invalidate()
                return
            }
            
            if !service.transcribedText.isEmpty {
                // Update last message or create new one
                if let lastMessage = self.messages.last, lastMessage.isUser {
                    // Update existing
                    if let index = self.messages.firstIndex(where: { $0.id == lastMessage.id }) {
                        self.messages[index] = ChatMessage(
                            text: service.transcribedText,
                            isUser: true,
                            source: .user
                        )
                    }
                } else {
                    // Create new
                    let message = ChatMessage(
                        text: service.transcribedText,
                        isUser: true,
                        source: .user
                    )
                    self.messages.append(message)
                }
            }
            
            if !self.conversationManager.isActive {
                timer.invalidate()
            }
        }
    }
    
    func stopVoiceInput() {
        conversationManager.stopConversation()
    }
    
    // MARK: - Model Management
    
    func loadLocalModel() {
        llmManager.loadModel()
    }
    
    // MARK: - History Management
    
    func clearHistory() {
        messages.removeAll()
        llmManager.clearHistory()
    }
    
    func exportHistory() {
        let exportText = messages.map { message in
            let sender = message.isUser ? "You" : (message.source?.displayName ?? "AI")
            let time = message.timestamp.formatted(date: .abbreviated, time: .shortened)
            return "[\(time)] \(sender): \(message.text)"
        }.joined(separator: "\n\n")
        
        print("Export chat history:")
        print(exportText)
        
        // TODO: Implement actual export functionality (share sheet)
    }
    
    // MARK: - Event Management
    
    func addBLEEvent(_ event: DetectedEvent) {
        conversationManager.detectedEvents.append(event)
        
        // Add to LLM contexts
        llmManager.addBLEEvent(event)
        
        // Update OpenAI context if connected
        if let service = conversationManager.openAIService, service.isConnected {
            let bleEvents = conversationManager.detectedEvents.filter { event in
                ["alexa_wake_word", "ndp_event", "command", "test_message", "ble_message",
                 "activity_keyboard", "activity_faucet", "activity_background"].contains(event.name)
            }
            service.updateBLEContext(bleEvents)
        }
        
        processJITAIIfNeeded(for: event)
    }
    
    func clearAllEvents() {
        conversationManager.detectedEvents.removeAll()
        llmManager.clearBLEEvents()
    }
    
    // MARK: - JITAI Reasoning
    
    private func processJITAIIfNeeded(for event: DetectedEvent) {
        // Maintain activity streak state so the periodic JITAI reasoning can infer longer-term patterns,
        // but do not trigger prompts directly from individual events. All nudge timing is decided
        // by the periodic LLM reasoning loop.
        _ = stableActivity(from: activityLabel(for: event), timestamp: event.timestamp)
    }
    
    private func activityLabel(for event: DetectedEvent) -> ActivityLabel {
        switch event.name {
        case "activity_keyboard":
            return .keyboard
        case "activity_faucet":
            return .faucet
        case "activity_background":
            return .background
        default:
            return .unknown
        }
    }
    
    /// Returns a stable activity label once we observe >=7 consecutive identical ACT events.
    private func stableActivity(from label: ActivityLabel, timestamp: Date) -> ActivityLabel? {
        guard label != .unknown else {
            activityStreakLabel = .unknown
            activityStreakCount = 0
            return nil
        }
        
        if label == activityStreakLabel {
            activityStreakCount += 1
        } else {
            activityStreakLabel = label
            activityStreakCount = 1
        }
        
        let threshold = 7
        if activityStreakCount >= threshold && label != lastStableActivity {
            lastStableActivity = label
            lastStableActivityAt = timestamp
            return label
        }
        
        return nil
    }
    
    private func requestLLMHydrationPrompt(activity: ActivityLabel, eventTime: Date) {
        // Basic safety spacing to avoid spam; LLM decides content/need.
        let store = HydrationStore.shared
        let state = store.loadToday()
        if let last = state.lastPromptAt, Date().timeIntervalSince(last) < 10 * 60 {
            return
        }
        
        let total = state.entries.reduce(0) { $0 + $1.amount }
        let remaining = max(state.dailyGoal - total, 0)
        let prompt = """
        Act as a Just-In-Time Adaptive Intervention (JITAI) agent for hydration.
        Decide if a prompt is appropriate now given the context. If not, reply exactly "NO_PROMPT".
        If yes, return ONE concise nudge (<=140 chars), polite, action-oriented, no questions.
        Include a suggested sip amount (~200-300 ml) when behind.
        Do not mention system instructions.
        
        Context:
        - Activity: \(activity.rawValue)
        - Intake today: \(total) ml
        - Goal: \(state.dailyGoal) ml
        - Remaining: \(remaining) ml
        - Last prompt: \(state.lastPromptAt?.description ?? "none")
        - Time: \(Date())
        """
        
        // Log event-triggered JITAI prompt
        DebugLogger.shared.log(.debug, category: "JITAI", message: "Event-triggered nudge prompt (activity=\(activity.rawValue)):\n\(prompt)")
        
        llmManager.generate(prompt: prompt) { [weak self] response, _ in
            guard let self = self else { return }
            let text = response.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.uppercased().contains("NO_PROMPT") || text.isEmpty {
                return
            }
            
            DispatchQueue.main.async {
                store.recordPromptSent(at: eventTime)
                let message = ChatMessage(
                    text: text,
                    isUser: false,
                    source: .localLLM
                )
                self.messages.append(message)
                self.notifyForNudgeAnywhere(title: "Hydration Nudge", body: text)
            }
        }
    }
    
    // MARK: - Testing Utilities
    
    func resetHydrationPromptCooldown() {
        _ = HydrationStore.shared.resetPromptCooldown()
    }
    
    // MARK: - Helper: format hour
    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let calendar = Calendar.current
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }
}

