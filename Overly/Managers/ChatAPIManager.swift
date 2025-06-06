//
//  ChatAPIManager.swift
//  Overly
//
//  Created by AI Assistant on 1/27/25.
//

import Foundation
import Combine

class ChatAPIManager: ObservableObject {
    static let shared = ChatAPIManager()
    
    private let keychainManager = KeychainManager.shared
    private let urlSession = URLSession.shared
    
    private init() {}
    
    // MARK: - Main Chat Method
    
    func sendMessage(
        _ message: String,
        to provider: ChatProviderType,
        model: String,
        conversationHistory: [ChatMessage] = [],
        temperature: Double = 0.7
    ) async throws -> String {
        
        guard let apiKey = keychainManager.retrieveAPIKey(for: provider) else {
            throw ChatError.invalidAPIKey
        }
        
        switch provider {
        case .openai, .groq:
            return try await sendOpenAICompatibleMessage(
                message,
                provider: provider,
                model: model,
                apiKey: apiKey,
                conversationHistory: conversationHistory,
                temperature: temperature
            )
        case .gemini:
            return try await sendGeminiMessage(
                message,
                model: model,
                apiKey: apiKey,
                conversationHistory: conversationHistory,
                temperature: temperature
            )
        }
    }
    
    // MARK: - Streaming Chat Method
    
    func sendMessageStream(
        _ message: String,
        to provider: ChatProviderType,
        model: String,
        conversationHistory: [ChatMessage] = [],
        temperature: Double = 0.7,
        onChunk: @escaping (String) -> Void,
        onComplete: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) {
        Task {
            do {
                guard let apiKey = keychainManager.retrieveAPIKey(for: provider) else {
                    throw ChatError.invalidAPIKey
                }
                
                switch provider {
                case .openai, .groq:
                    try await sendOpenAICompatibleMessageStream(
                        message,
                        provider: provider,
                        model: model,
                        apiKey: apiKey,
                        conversationHistory: conversationHistory,
                        temperature: temperature,
                        onChunk: onChunk,
                        onComplete: onComplete
                    )
                case .gemini:
                    // Gemini doesn't support streaming in the same way, so we'll simulate it
                    let response = try await sendGeminiMessage(
                        message,
                        model: model,
                        apiKey: apiKey,
                        conversationHistory: conversationHistory,
                        temperature: temperature
                    )
                    
                    // Simulate streaming by sending chunks
                    await simulateStreaming(response: response, onChunk: onChunk)
                    onComplete()
                }
            } catch {
                onError(error)
            }
        }
    }
    
    // MARK: - OpenAI/Groq Compatible API
    
    private func sendOpenAICompatibleMessage(
        _ message: String,
        provider: ChatProviderType,
        model: String,
        apiKey: String,
        conversationHistory: [ChatMessage],
        temperature: Double
    ) async throws -> String {
        
        let url = URL(string: "\(provider.baseURL)/chat/completions")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Convert conversation history to API format
        var apiMessages: [OpenAIMessage] = conversationHistory.map { chatMessage in
            OpenAIMessage(role: chatMessage.role.rawValue, content: chatMessage.content)
        }
        
        // Add the new user message
        apiMessages.append(OpenAIMessage(role: "user", content: message))
        
        let requestBody = OpenAIRequest(
            model: model,
            messages: apiMessages,
            stream: false,
            temperature: temperature,
            maxTokens: 2000
        )
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            throw ChatError.invalidResponse
        }
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ChatError.networkError("Invalid response")
            }
            
            if httpResponse.statusCode == 401 {
                throw ChatError.invalidAPIKey
            } else if httpResponse.statusCode == 429 {
                throw ChatError.rateLimited
            } else if httpResponse.statusCode != 200 {
                throw ChatError.apiError("HTTP \(httpResponse.statusCode)")
            }
            
            let apiResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            
            guard let firstChoice = apiResponse.choices.first else {
                throw ChatError.invalidResponse
            }
            
            return firstChoice.message.content
            
        } catch let error as ChatError {
            throw error
        } catch {
            throw ChatError.networkError(error.localizedDescription)
        }
    }
    
    private func sendOpenAICompatibleMessageStream(
        _ message: String,
        provider: ChatProviderType,
        model: String,
        apiKey: String,
        conversationHistory: [ChatMessage],
        temperature: Double,
        onChunk: @escaping (String) -> Void,
        onComplete: @escaping () -> Void
    ) async throws {
        
        let url = URL(string: "\(provider.baseURL)/chat/completions")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Convert conversation history to API format
        var apiMessages: [OpenAIMessage] = conversationHistory.map { chatMessage in
            OpenAIMessage(role: chatMessage.role.rawValue, content: chatMessage.content)
        }
        
        // Add the new user message
        apiMessages.append(OpenAIMessage(role: "user", content: message))
        
        let requestBody = OpenAIRequest(
            model: model,
            messages: apiMessages,
            stream: true,
            temperature: temperature,
            maxTokens: 2000
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (asyncBytes, response) = try await urlSession.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatError.networkError("Invalid response")
        }
        
        if httpResponse.statusCode == 401 {
            throw ChatError.invalidAPIKey
        } else if httpResponse.statusCode == 429 {
            throw ChatError.rateLimited
        } else if httpResponse.statusCode != 200 {
            throw ChatError.apiError("HTTP \(httpResponse.statusCode)")
        }
        
        for try await line in asyncBytes.lines {
            if line.hasPrefix("data: ") {
                let jsonString = String(line.dropFirst(6))
                
                if jsonString == "[DONE]" {
                    onComplete()
                    return
                }
                
                if let data = jsonString.data(using: .utf8),
                   let streamResponse = try? JSONDecoder().decode(OpenAIStreamResponse.self, from: data),
                   let choice = streamResponse.choices.first,
                   let content = choice.delta.content {
                    
                    await MainActor.run {
                        onChunk(content)
                    }
                }
            }
        }
        
        onComplete()
    }
    
    // MARK: - Gemini API
    
    private func sendGeminiMessage(
        _ message: String,
        model: String,
        apiKey: String,
        conversationHistory: [ChatMessage],
        temperature: Double
    ) async throws -> String {
        
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Convert conversation history to Gemini format
        var contents: [GeminiContent] = []
        
        for chatMessage in conversationHistory {
            let role = chatMessage.role == .user ? "user" : "model"
            contents.append(GeminiContent(
                parts: [GeminiPart(text: chatMessage.content)],
                role: role
            ))
        }
        
        // Add the new user message
        contents.append(GeminiContent(
            parts: [GeminiPart(text: message)],
            role: "user"
        ))
        
        let requestBody = GeminiRequest(
            contents: contents,
            generationConfig: GeminiGenerationConfig(
                temperature: temperature,
                maxOutputTokens: 2000
            )
        )
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            throw ChatError.invalidResponse
        }
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ChatError.networkError("Invalid response")
            }
            
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw ChatError.invalidAPIKey
            } else if httpResponse.statusCode == 429 {
                throw ChatError.rateLimited
            } else if httpResponse.statusCode != 200 {
                throw ChatError.apiError("HTTP \(httpResponse.statusCode)")
            }
            
            let apiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
            
            guard let firstCandidate = apiResponse.candidates.first,
                  let firstPart = firstCandidate.content.parts.first else {
                throw ChatError.invalidResponse
            }
            
            return firstPart.text
            
        } catch let error as ChatError {
            throw error
        } catch {
            throw ChatError.networkError(error.localizedDescription)
        }
    }
    
    // MARK: - Utility Methods
    
    private func simulateStreaming(response: String, onChunk: @escaping (String) -> Void) async {
        let words = response.components(separatedBy: " ")
        
        for (index, word) in words.enumerated() {
            let chunk = index == 0 ? word : " \(word)"
            
            await MainActor.run {
                onChunk(chunk)
            }
            
            // Small delay to simulate streaming
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
    }
    
    // MARK: - Model Fetching
    
    func fetchAvailableModels(for provider: ChatProviderType) async throws -> [String] {
        guard let apiKey = keychainManager.retrieveAPIKey(for: provider) else {
            throw ChatError.invalidAPIKey
        }
        
        switch provider {
        case .gemini:
            return try await fetchGeminiModels(apiKey: apiKey)
        case .openai, .groq:
            // OpenAI and Groq don't have public model listing endpoints
            return provider.supportedModels
        }
    }
    
    private func fetchGeminiModels(apiKey: String) async throws -> [String] {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models?key=\(apiKey)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ChatError.networkError("Invalid response")
            }
            
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw ChatError.invalidAPIKey
            } else if httpResponse.statusCode != 200 {
                throw ChatError.apiError("HTTP \(httpResponse.statusCode)")
            }
            
            let modelsResponse = try JSONDecoder().decode(GeminiModelsResponse.self, from: data)
            
            // Filter for generateContent models and extract model names
            let availableModels = modelsResponse.models
                .filter { $0.supportedGenerationMethods.contains("generateContent") }
                .map { model in
                    // Extract model name from full path (e.g., "models/gemini-pro" -> "gemini-pro")
                    return String(model.name.split(separator: "/").last ?? "")
                }
                .filter { !$0.isEmpty }
            
            return availableModels.isEmpty ? ChatProviderType.gemini.supportedModels : availableModels
            
        } catch let error as ChatError {
            throw error
        } catch {
            throw ChatError.networkError(error.localizedDescription)
        }
    }
    
    // MARK: - API Key Testing
    
    func testAPIKey(for provider: ChatProviderType) async -> Bool {
        do {
            _ = try await sendMessage(
                "Hello",
                to: provider,
                model: provider.defaultModel,
                conversationHistory: [],
                temperature: 0.1
            )
            return true
        } catch {
            print("API key test failed for \(provider.rawValue): \(error)")
            return false
        }
    }
}

// MARK: - Additional Models for Streaming

struct OpenAIStreamResponse: Codable {
    let choices: [OpenAIStreamChoice]
}

struct OpenAIStreamChoice: Codable {
    let delta: OpenAIStreamDelta
}

struct OpenAIStreamDelta: Codable {
    let content: String?
} 