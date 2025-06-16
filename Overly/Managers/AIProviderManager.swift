import Foundation
import SwiftUI

// MARK: - Provider Types

enum AIProvider: String, CaseIterable, Identifiable, Codable {
    case openai = "openai"
    case gemini = "gemini"
    case anthropic = "anthropic"
    case ollama = "ollama"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .gemini: return "Google Gemini"
        case .anthropic: return "Anthropic"
        case .ollama: return "Ollama"
        }
    }
    
    var iconName: String {
        switch self {
        case .openai: return "openai"
        case .gemini: return "gemini"
        case .anthropic: return "anthropic"
        case .ollama: return "server.rack"
        }
    }
    
    var requiresAPIKey: Bool {
        switch self {
        case .openai, .gemini, .anthropic: return true
        case .ollama: return false
        }
    }
    
    var defaultModels: [String] {
        switch self {
        case .openai:
            return ["gpt-4", "gpt-4-turbo", "gpt-3.5-turbo"]
        case .gemini:
            return ["gemini-pro", "gemini-pro-vision"]
        case .anthropic:
            return ["claude-3-opus", "claude-3-sonnet", "claude-3-haiku"]
        case .ollama:
            return [] // Fetched dynamically
        }
    }
    
    var baseURL: String {
        switch self {
        case .openai: return "https://api.openai.com/v1"
        case .gemini: return "https://generativelanguage.googleapis.com/v1beta"
        case .anthropic: return "https://api.anthropic.com"
        case .ollama: return "http://localhost:11434"
        }
    }
}

// MARK: - Model Types

struct AIModel: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let provider: AIProvider
    let displayName: String
    var isEnabled: Bool
    
    init(id: String, name: String, provider: AIProvider, displayName: String? = nil, isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.provider = provider
        self.displayName = displayName ?? name
        self.isEnabled = isEnabled
    }
}

// MARK: - Chat Message Types

struct AIProviderMessage: Codable {
    let role: String
    let content: String
}

// MARK: - Provider Manager

@MainActor
class AIProviderManager: ObservableObject {
    static let shared = AIProviderManager()
    
    @Published var availableModels: [AIModel] = []
    @Published var selectedProvider: AIProvider = .ollama
    @Published var selectedModel: String = ""
    @Published var isLoading: Bool = false
    @Published var error: String?
    
    private let keychainManager = KeychainManager.shared
    private let ollamaManager = OllamaManager.shared
    
    private init() {
        loadSettings()
        Task {
            await refreshAllModels()
        }
    }
    
    // MARK: - Settings Management
    
    private func loadSettings() {
        if let savedProvider = UserDefaults.standard.string(forKey: "selectedAIProvider"),
           let provider = AIProvider(rawValue: savedProvider) {
            selectedProvider = provider
        }
        
        selectedModel = UserDefaults.standard.string(forKey: "selectedAIModel") ?? ""
        loadModelPreferences()
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(selectedProvider.rawValue, forKey: "selectedAIProvider")
        UserDefaults.standard.set(selectedModel, forKey: "selectedAIModel")
        saveModelPreferences()
    }
    
    private func loadModelPreferences() {
        if let data = UserDefaults.standard.data(forKey: "enabledAIModels"),
           let preferences = try? JSONDecoder().decode([String: Bool].self, from: data) {
            
            for i in availableModels.indices {
                if let isEnabled = preferences[availableModels[i].id] {
                    availableModels[i].isEnabled = isEnabled
                }
            }
        }
    }
    
    private func saveModelPreferences() {
        let preferences = Dictionary(uniqueKeysWithValues: availableModels.map { ($0.id, $0.isEnabled) })
        if let data = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(data, forKey: "enabledAIModels")
        }
    }
    
    // MARK: - Provider Management
    
    var availableProviders: [AIProvider] {
        return AIProvider.allCases.filter { provider in
            if provider.requiresAPIKey {
                return hasAPIKey(for: provider)
            }
            return true // Ollama doesn't need API key
        }
    }
    
    func hasAPIKey(for provider: AIProvider) -> Bool {
        guard provider.requiresAPIKey else { return true }
        
        let keychainProvider: KeychainManager.APIProvider
        switch provider {
        case .openai: keychainProvider = .openai
        case .gemini: keychainProvider = .gemini
        case .anthropic: keychainProvider = .anthropic
        case .ollama: return true
        }
        
        return keychainManager.getAPIKey(for: keychainProvider) != nil
    }
    
    func setSelectedProvider(_ provider: AIProvider) {
        selectedProvider = provider
        
        // Auto-select first enabled model for this provider
        let providerModels = availableModels.filter { $0.provider == provider && $0.isEnabled }
        if let firstModel = providerModels.first {
            selectedModel = firstModel.name
        } else {
            selectedModel = ""
        }
        
        saveSettings()
    }
    
    func setSelectedModel(_ model: String) {
        selectedModel = model
        saveSettings()
    }
    
    // MARK: - Model Management
    
    func refreshAllModels() async {
        isLoading = true
        error = nil
        
        var allModels: [AIModel] = []
        
        // Add static models for providers with API keys
        for provider in availableProviders {
            switch provider {
            case .openai, .gemini, .anthropic:
                let models = provider.defaultModels.map { modelName in
                    AIModel(
                        id: "\(provider.rawValue)_\(modelName)",
                        name: modelName,
                        provider: provider,
                        displayName: modelName
                    )
                }
                allModels.append(contentsOf: models)
                
            case .ollama:
                // Fetch Ollama models dynamically
                do {
                    await ollamaManager.fetchModels()
                    let ollamaModels = ollamaManager.availableModels.map { ollamaModel in
                        AIModel(
                            id: "ollama_\(ollamaModel.name)",
                            name: ollamaModel.name,
                            provider: .ollama,
                            displayName: ollamaModel.displayName
                        )
                    }
                    allModels.append(contentsOf: ollamaModels)
                } catch {
                    self.error = "Failed to fetch Ollama models: \(error.localizedDescription)"
                }
            }
        }
        
        // Preserve enabled/disabled state
        let previousPreferences = Dictionary(uniqueKeysWithValues: availableModels.map { ($0.id, $0.isEnabled) })
        
        for i in allModels.indices {
            if let wasEnabled = previousPreferences[allModels[i].id] {
                allModels[i].isEnabled = wasEnabled
            }
        }
        
        availableModels = allModels
        isLoading = false
        
        // Auto-select model if none selected
        if selectedModel.isEmpty || !availableModels.contains(where: { $0.name == selectedModel && $0.provider == selectedProvider }) {
            let enabledModels = availableModels.filter { $0.provider == selectedProvider && $0.isEnabled }
            if let firstModel = enabledModels.first {
                selectedModel = firstModel.name
            }
        }
        
        saveSettings()
    }
    
    func toggleModel(_ model: AIModel) {
        if let index = availableModels.firstIndex(where: { $0.id == model.id }) {
            availableModels[index].isEnabled.toggle()
            saveModelPreferences()
        }
    }
    
    func enableAllModels(for provider: AIProvider) {
        for i in availableModels.indices {
            if availableModels[i].provider == provider {
                availableModels[i].isEnabled = true
            }
        }
        saveModelPreferences()
    }
    
    func disableAllModels(for provider: AIProvider) {
        for i in availableModels.indices {
            if availableModels[i].provider == provider {
                availableModels[i].isEnabled = false
            }
        }
        saveModelPreferences()
    }
    
    // MARK: - Chat Integration
    
    var enabledModels: [AIModel] {
        return availableModels.filter { $0.isEnabled }
    }
    
    var currentProviderModels: [AIModel] {
        return availableModels.filter { $0.provider == selectedProvider && $0.isEnabled }
    }
    
    func sendMessage(_ messages: [AIProviderMessage]) async throws -> AsyncThrowingStream<String, Error> {
        guard !selectedModel.isEmpty else {
            throw NSError(domain: "AIProviderManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No model selected"])
        }
        
        switch selectedProvider {
        case .ollama:
            let ollamaMessages = messages.map { OllamaChatMessage(role: $0.role, content: $0.content) }
            return try await ollamaManager.sendChatMessage(messages: ollamaMessages)
            
        case .openai:
            return try await sendOpenAIMessage(messages)
            
        case .gemini:
            return try await sendGeminiMessage(messages)
            
        case .anthropic:
            return try await sendAnthropicMessage(messages)
        }
    }
    
    // MARK: - Provider-specific implementations
    
    private func sendOpenAIMessage(_ messages: [AIProviderMessage]) async throws -> AsyncThrowingStream<String, Error> {
        guard let apiKey = keychainManager.getAPIKey(for: .openai) else {
            throw NSError(domain: "AIProviderManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "OpenAI API key not found"])
        }
        
        // TODO: Implement OpenAI API call
        return AsyncThrowingStream { continuation in
            continuation.yield("OpenAI integration coming soon...")
            continuation.finish()
        }
    }
    
    private func sendGeminiMessage(_ messages: [AIProviderMessage]) async throws -> AsyncThrowingStream<String, Error> {
        guard let apiKey = keychainManager.getAPIKey(for: .gemini) else {
            throw NSError(domain: "AIProviderManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Gemini API key not found"])
        }
        
        // TODO: Implement Gemini API call
        return AsyncThrowingStream { continuation in
            continuation.yield("Gemini integration coming soon...")
            continuation.finish()
        }
    }
    
    private func sendAnthropicMessage(_ messages: [AIProviderMessage]) async throws -> AsyncThrowingStream<String, Error> {
        guard let apiKey = keychainManager.getAPIKey(for: .anthropic) else {
            throw NSError(domain: "AIProviderManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Anthropic API key not found"])
        }
        
        // TODO: Implement Anthropic API call
        return AsyncThrowingStream { continuation in
            continuation.yield("Anthropic integration coming soon...")
            continuation.finish()
        }
    }
} 