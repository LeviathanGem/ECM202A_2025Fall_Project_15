//
//  OpenAIChatService.swift
//  OdysseyTest
//
//  Minimal text Chat API client for cloud responses.
//

import Foundation

enum OpenAIChatError: Error {
    case invalidResponse
    case requestFailed(String)
}

final class OpenAIChatService {
    private let apiKey: String
    private let session: URLSession
    private let model = "gpt-4o-mini"
    
    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }
    
    func sendChat(prompt: String, systemPrompt: String? = nil, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            completion(.failure(OpenAIChatError.requestFailed("Bad URL")))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var messages: [[String: String]] = []
        if let systemPrompt = systemPrompt, !systemPrompt.isEmpty {
            messages.append(["role": "system", "content": systemPrompt])
        }
        messages.append(["role": "user", "content": prompt])
        
        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": 0.7
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: body) else {
            completion(.failure(OpenAIChatError.requestFailed("Failed to encode body")))
            return
        }
        
        request.httpBody = data
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard
                let data = data,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let choices = json["choices"] as? [[String: Any]],
                let first = choices.first,
                let message = first["message"] as? [String: Any],
                let content = message["content"] as? String
            else {
                let text = String(data: data ?? Data(), encoding: .utf8) ?? "nil data"
                completion(.failure(OpenAIChatError.invalidResponse))
                DebugLogger.shared.log(.error, category: "OpenAIChat", message: "Invalid response: \(text)")
                return
            }
            
            completion(.success(content))
        }
        task.resume()
    }
}

