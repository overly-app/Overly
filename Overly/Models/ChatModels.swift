//
//  ChatModels.swift
//  Overly
//
//  Created by AI Assistant on 1/27/25.
//

import Foundation
import SwiftUI

// MARK: - Chat Message Models
struct ChatMessage: Identifiable, Codable, Equatable {
    let id = UUID()
    var content: String
    let role: MessageRole
    let timestamp: Date
    let provider: String
    var isStreaming: Bool = false
    
    enum MessageRole: String, Codable, CaseIterable {
        case user = "user"
        case assistant = "assistant"
        case system = "system"
    }
    
    init(content: String, role: MessageRole, provider: String, isStreaming: Bool = false) {
        self.content = content
        self.role = role
        self.timestamp = Date()
        self.provider = provider
        self.isStreaming = isStreaming
    }
}

// MARK: - Chat Provider Models
enum ChatProviderType: String, CaseIterable, Identifiable {
    case openai = "OpenAI"
    case gemini = "Gemini"
    case groq = "Groq"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .gemini: return "Gemini"
        case .groq: return "Groq"
        }
    }
    
    var iconName: String {
        switch self {
        case .openai: return "openai"
        case .gemini: return "gemini"
        case .groq: return "cpu"
        }
    }
    
    var isSystemIcon: Bool {
        switch self {
        case .openai, .gemini: return false
        case .groq: return true
        }
    }
    
    var baseURL: String {
        switch self {
        case .openai: return "https://api.openai.com/v1"
        case .gemini: return "https://generativelanguage.googleapis.com/v1beta"
        case .groq: return "https://api.groq.com/openai/v1"
        }
    }
    
    var defaultModel: String {
        switch self {
        case .openai: return "gpt-4o"
        case .gemini: return "gemini-1.5-flash"
        case .groq: return "mixtral-8x7b-32768"
        }
    }
    
    var supportedModels: [String] {
        // Minimal fallback models - only used if API fetch fails
        switch self {
        case .openai:
            return ["gpt-4o", "gpt-4", "gpt-3.5-turbo"]
        case .gemini:
            return ["gemini-1.5-flash", "gemini-1.5-pro"]
        case .groq:
            return ["mixtral-8x7b-32768", "llama-3.1-8b-instant"]
        }
    }
}

// MARK: - Chat Session Model
class ChatSession: ObservableObject, Identifiable {
    let id = UUID()
    @Published var messages: [ChatMessage] = []
    @Published var title: String
    @Published var provider: ChatProviderType
    @Published var model: String
    let createdAt: Date
    @Published var isActive: Bool = false
    
    init(provider: ChatProviderType, model: String? = nil, title: String? = nil) {
        self.provider = provider
        self.model = model ?? provider.defaultModel
        self.title = title ?? "New Chat"
        self.createdAt = Date()
    }
    
    func addMessage(_ message: ChatMessage) {
        DispatchQueue.main.async {
            self.messages.append(message)
            
            // Auto-generate title from first user message
            if self.title == "New Chat" && message.role == .user {
                self.title = String(message.content.prefix(50))
                if message.content.count > 50 {
                    self.title += "..."
                }
            }
        }
    }
    
    func updateLastMessage(content: String) {
        DispatchQueue.main.async {
            if let lastIndex = self.messages.indices.last {
                var updatedMessage = self.messages[lastIndex]
                updatedMessage.content = content
                self.messages[lastIndex] = updatedMessage
            }
        }
    }
    
    func setLastMessageStreaming(_ isStreaming: Bool) {
        DispatchQueue.main.async {
            if let lastIndex = self.messages.indices.last {
                var updatedMessage = self.messages[lastIndex]
                updatedMessage.isStreaming = isStreaming
                self.messages[lastIndex] = updatedMessage
            }
        }
    }
}

// MARK: - API Request/Response Models

// OpenAI API Models
struct OpenAIRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let stream: Bool
    let temperature: Double
    let maxTokens: Int?
    
    private enum CodingKeys: String, CodingKey {
        case model, messages, stream, temperature
        case maxTokens = "max_tokens"
    }
}

struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

struct OpenAIResponse: Codable {
    let choices: [OpenAIChoice]
}

struct OpenAIChoice: Codable {
    let message: OpenAIMessage
    let finishReason: String?
    
    private enum CodingKeys: String, CodingKey {
        case message
        case finishReason = "finish_reason"
    }
}

// Gemini API Models
struct GeminiRequest: Codable {
    let contents: [GeminiContent]
    let generationConfig: GeminiGenerationConfig
}

struct GeminiContent: Codable {
    let parts: [GeminiPart]
    let role: String?
}

struct GeminiPart: Codable {
    let text: String
}

struct GeminiGenerationConfig: Codable {
    let temperature: Double
    let maxOutputTokens: Int?
    
    private enum CodingKeys: String, CodingKey {
        case temperature
        case maxOutputTokens = "maxOutputTokens"
    }
}

struct GeminiResponse: Codable {
    let candidates: [GeminiCandidate]
}

struct GeminiCandidate: Codable {
    let content: GeminiContent
    let finishReason: String?
    
    private enum CodingKeys: String, CodingKey {
        case content
        case finishReason = "finishReason"
    }
}

// Gemini Streaming Response
struct GeminiStreamResponse: Codable {
    let candidates: [GeminiCandidate]
}

// OpenAI Models API Response
struct OpenAIModelsResponse: Codable {
    let data: [OpenAIModelInfo]
}

struct OpenAIModelInfo: Codable {
    let id: String
    let object: String
    let created: Int?
    let ownedBy: String?
    
    private enum CodingKeys: String, CodingKey {
        case id, object, created
        case ownedBy = "owned_by"
    }
}

// Gemini Models API Response
struct GeminiModelsResponse: Codable {
    let models: [GeminiModel]
}

struct GeminiModel: Codable {
    let name: String
    let displayName: String?
    let description: String?
    let supportedGenerationMethods: [String]
    let baseModelId: String?
    let version: String?
    let inputTokenLimit: Int?
    let outputTokenLimit: Int?
    
    private enum CodingKeys: String, CodingKey {
        case name, description, version
        case displayName = "displayName"
        case supportedGenerationMethods = "supportedGenerationMethods"
        case baseModelId = "baseModelId"
        case inputTokenLimit = "inputTokenLimit"
        case outputTokenLimit = "outputTokenLimit"
    }
}

// MARK: - Error Models
enum ChatError: LocalizedError {
    case invalidAPIKey
    case networkError(String)
    case apiError(String)
    case invalidResponse
    case rateLimited
    case modelNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid API key. Please check your credentials."
        case .networkError(let message):
            return "Network error: \(message)"
        case .apiError(let message):
            return "API error: \(message)"
        case .invalidResponse:
            return "Invalid response from server."
        case .rateLimited:
            return "Rate limit exceeded. Please try again later."
        case .modelNotAvailable:
            return "Selected model is not available."
        }
    }
} 