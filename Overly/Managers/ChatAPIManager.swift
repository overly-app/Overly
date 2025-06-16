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
    
    // Map ChatProviderType to KeychainManager.APIProvider
    private func mapToAPIProvider(_ chatProvider: ChatProviderType) -> KeychainManager.APIProvider? {
        switch chatProvider {
        case .openai:
            return .openai
        case .gemini:
            return .gemini
        case .groq:
            return .customOpenAI // Groq uses OpenAI-compatible API
        }
    }
    
    private init() {}
    
    // MARK: - Main Chat Method
    
    func sendMessage(
        _ message: String,
        to provider: ChatProviderType,
        model: String,
        conversationHistory: [ChatMessage] = [],
        temperature: Double = 0.7
    ) async throws -> String {
        
        guard let apiProvider = mapToAPIProvider(provider),
              let apiKey = keychainManager.getAPIKey(for: apiProvider) else {
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
                guard let apiProvider = mapToAPIProvider(provider),
                      let apiKey = keychainManager.getAPIKey(for: apiProvider) else {
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
                    try await sendGeminiMessageStream(
                        message,
                        model: model,
                        apiKey: apiKey,
                        conversationHistory: conversationHistory,
                        temperature: temperature,
                        onChunk: onChunk,
                        onComplete: onComplete
                    )
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
    
    private func sendGeminiMessageStream(
        _ message: String,
        model: String,
        apiKey: String,
        conversationHistory: [ChatMessage],
        temperature: Double,
        onChunk: @escaping (String) -> Void,
        onComplete: @escaping () -> Void
    ) async throws {
        
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):streamGenerateContent?key=\(apiKey)")!
        
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
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (asyncBytes, response) = try await urlSession.bytes(for: request)
        
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
        
        var fullContent = ""
        
        for try await line in asyncBytes.lines {
            if line.hasPrefix("data: ") {
                let jsonString = String(line.dropFirst(6))
                
                if jsonString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continue
                }
                
                if let data = jsonString.data(using: .utf8),
                   let streamResponse = try? JSONDecoder().decode(GeminiStreamResponse.self, from: data),
                   let candidate = streamResponse.candidates.first,
                   let part = candidate.content.parts.first {
                    
                    let chunk = part.text
                    fullContent += chunk
                    
                    await MainActor.run {
                        onChunk(chunk)
                    }
                }
            }
        }
        
        onComplete()
    }
    
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
    
    // MARK: - Model Fetching
    
    func fetchAvailableModels(for provider: ChatProviderType) async throws -> [String] {
        guard let apiProvider = mapToAPIProvider(provider),
              let apiKey = keychainManager.getAPIKey(for: apiProvider) else {
            throw ChatError.invalidAPIKey
        }
        
        switch provider {
        case .openai:
            return try await fetchOpenAIModels(apiKey: apiKey)
        case .gemini:
            return try await fetchGeminiModels(apiKey: apiKey)
        case .groq:
            return try await fetchGroqModels(apiKey: apiKey)
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
                // Log the response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Gemini API Error Response: \(responseString)")
                }
                throw ChatError.apiError("HTTP \(httpResponse.statusCode)")
            }
            
            // Debug: Print raw response
            if let responseString = String(data: data, encoding: .utf8) {
                print("Raw Gemini API Response: \(responseString)")
            }
            
            let modelsResponse = try JSONDecoder().decode(GeminiModelsResponse.self, from: data)
            
            // Debug: Print all models before filtering
            print("All Gemini models from API:")
            for model in modelsResponse.models {
                let displayName = model.displayName ?? "No display name"
                let baseModel = model.baseModelId ?? "No base model"
                print("  - \(model.name) (\(displayName)) - Base: \(baseModel) - Methods: \(model.supportedGenerationMethods)")
            }
            
            // Filter for generateContent models and extract model names
            let allGenerativeModels = modelsResponse.models
                .filter { model in
                    // Check for any generation method (not just generateContent)
                    let hasGenerativeMethod = model.supportedGenerationMethods.contains { method in
                        method.lowercased().contains("generate")
                    }
                    print("Model \(model.name): hasGenerativeMethod = \(hasGenerativeMethod), methods = \(model.supportedGenerationMethods)")
                    return hasGenerativeMethod
                }
            
            let availableModels = allGenerativeModels
                .map { model in
                    // Extract model name from full path (e.g., "models/gemini-pro" -> "gemini-pro")
                    return String(model.name.split(separator: "/").last ?? "")
                }
                .filter { !$0.isEmpty }
                .sorted { model1, model2 in
                    // Custom sort: prioritize newer models
                    return geminiModelPriority(model1) < geminiModelPriority(model2)
                }
            
            print("✅ Filtered \(availableModels.count) Gemini models: \(availableModels)")
            return availableModels.isEmpty ? ChatProviderType.gemini.supportedModels : availableModels
            
        } catch let error as ChatError {
            throw error
        } catch {
            print("❌ Gemini model fetch error: \(error)")
            throw ChatError.networkError(error.localizedDescription)
        }
    }
    
    private func geminiModelPriority(_ modelId: String) -> Int {
        let id = modelId.lowercased()
        // Lower numbers = higher priority (shown first)
        if id.contains("2.5") { return 0 }
        if id.contains("2.0") { return 1 }
        if id.contains("1.5") && id.contains("pro") { return 2 }
        if id.contains("1.5") && id.contains("flash") { return 3 }
        if id.contains("pro") { return 4 }
        if id.contains("flash") { return 5 }
        return 10 // Everything else
    }
    
    private func fetchOpenAIModels(apiKey: String) async throws -> [String] {
        let url = URL(string: "https://api.openai.com/v1/models")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
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
            
            let modelsResponse = try JSONDecoder().decode(OpenAIModelsResponse.self, from: data)
            
            // Filter for chat models (exclude embedding, whisper, etc.)
            let chatModels = modelsResponse.data
                .filter { model in
                    let id = model.id.lowercased()
                    return (id.contains("gpt") || id.contains("o1")) && 
                           !id.contains("embedding") && 
                           !id.contains("whisper") &&
                           !id.contains("tts") &&
                           !id.contains("dall-e")
                }
                .map { $0.id }
                .sorted { model1, model2 in
                    // Sort with newest/best models first
                    let priority1 = getModelPriority(model1)
                    let priority2 = getModelPriority(model2)
                    return priority1 < priority2
                }
            
            print("Fetched \(chatModels.count) OpenAI models: \(chatModels)")
            return chatModels.isEmpty ? ChatProviderType.openai.supportedModels : chatModels
            
        } catch let error as ChatError {
            throw error
        } catch {
            throw ChatError.networkError(error.localizedDescription)
        }
    }
    
    private func fetchGroqModels(apiKey: String) async throws -> [String] {
        let url = URL(string: "https://api.groq.com/openai/v1/models")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
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
            
            let modelsResponse = try JSONDecoder().decode(OpenAIModelsResponse.self, from: data)
            
            // Get all available models
            let availableModels = modelsResponse.data
                .map { $0.id }
                .sorted()
            
            print("Fetched \(availableModels.count) Groq models: \(availableModels)")
            return availableModels.isEmpty ? ChatProviderType.groq.supportedModels : availableModels
            
        } catch let error as ChatError {
            throw error
        } catch {
            throw ChatError.networkError(error.localizedDescription)
        }
    }
    
    private func getModelPriority(_ modelId: String) -> Int {
        let id = modelId.lowercased()
        // Lower numbers = higher priority (shown first)
        if id.contains("o1") { return 0 }
        if id.contains("gpt-4") && id.contains("turbo") { return 1 }
        if id.contains("gpt-4") { return 2 }
        if id.contains("gpt-3.5") { return 3 }
        return 10 // Everything else
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