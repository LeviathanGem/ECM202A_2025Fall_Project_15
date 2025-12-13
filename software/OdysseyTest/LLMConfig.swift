//
//  LLMConfig.swift
//  OdysseyTest
//
//  Configuration for local LLM
//

import Foundation

struct LLMConfig {
    // Model configuration
    static let modelName = "tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"
    static let modelURL = "https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"
    static let modelSize: Int64 = 669_000_000 // ~669 MB
    
    // Model path in documents directory
    static var modelPath: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent(modelName)
    }
    
    // Check if model exists
    static var isModelDownloaded: Bool {
        FileManager.default.fileExists(atPath: modelPath.path)
    }
    
    // Generation parameters
    static let maxTokens = 64   // Shorter local replies to reduce repetition
    static let temperature: Float = 0.5   // lower temperature for less randomness
    static let topP: Float = 0.85         // slightly tighter nucleus sampling
    static let repeatPenalty: Float = 1.1
    static let generationTimeout: TimeInterval = 30.0  // 30 second timeout
    
    // System prompt for hydration JITAI assistant
    static let systemPrompt = """
    You are a hydration coach. Give brief, encouraging responses. When detecting user intents, include [FUNCTION:function_name] tags:
    - log_water_intake: user drinks water
    - hydration_status: user asks progress
    - set_hydration_goal: user changes goal
    - hydration_prompt: suggest drinking water
    """
}

