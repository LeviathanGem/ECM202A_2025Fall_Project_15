//
//  Config.swift
//  OdysseyTest
//
//  Configuration and API key management
//

import Foundation

struct Config {
    // IMPORTANT: Never commit your actual API key to version control!
    // Best practice: Use environment variables or Keychain
    
    // For development, you can temporarily put your key here:
    static let openAIAPIKey = "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"
    
    // Alternative: Load from environment variable
    static var openAIAPIKeyFromEnv: String {
        ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? openAIAPIKey
    }
    
    // Use this in your app
    static var apiKey: String {
        openAIAPIKeyFromEnv
    }
    
    // Validate API key
    static var isAPIKeyConfigured: Bool {
        !apiKey.isEmpty && apiKey != "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"
    }
}

