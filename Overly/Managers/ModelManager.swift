//
//  ModelManager.swift
//  Overly
//
//  Created by AI Assistant on 1/27/25.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Model Data Structures

struct ProviderModel: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let provider: ChatProviderType
    let displayName: String
    let description: String?
    
    init(name: String, provider: ChatProviderType, description: String? = nil) {
        self.id = "\(provider.rawValue)_\(name)"
        self.name = name
        self.provider = provider
        self.displayName = name
        self.description = description
    }
}

struct ModelGroup: Identifiable {
    let id: String
    let provider: ChatProviderType
    let models: [ProviderModel]
    let isEnabled: Bool
    
    init(provider: ChatProviderType, models: [ProviderModel], isEnabled: Bool) {
        self.id = provider.rawValue
        self.provider = provider
        self.models = models
        self.isEnabled = isEnabled
    }
}

// MARK: - Model Manager

@MainActor
class ModelManager: ObservableObject {
    static let shared = ModelManager()
    
    // MARK: - Published Properties
    @Published var availableModels: [ProviderModel] = []
    @Published var enabledModelIds: Set<String> = []
    @Published var modelGroups: [ModelGroup] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let chatManager = ChatManager.shared
    private let apiManager = ChatAPIManager.shared
    private let ollamaManager = OllamaManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // UserDefaults keys
    private let enabledModelsKey = "enabledModelIds"
    
    private init() {
        loadEnabledModels()
        setupObservers()
    }
    
    // MARK: - Setup
    
    private func setupObservers() {
        // Observe changes in available providers
        chatManager.$availableProviders
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.refreshAllModels()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Model Management
    
    func refreshAllModels() async {
        isLoading = true
        errorMessage = nil
        
        var allModels: [ProviderModel] = []
        var groups: [ModelGroup] = []
        
        for provider in chatManager.availableProviders {
            do {
                let modelNames = try await fetchModelsForProvider(provider)
                let providerModels = modelNames.map { modelName in
                    ProviderModel(
                        name: modelName,
                        provider: provider,
                        description: getModelDescription(modelName, provider: provider)
                    )
                }
                
                allModels.append(contentsOf: providerModels)
                
                let group = ModelGroup(
                    provider: provider,
                    models: providerModels,
                    isEnabled: chatManager.availableProviders.contains(provider)
                )
                groups.append(group)
                
            } catch {
                print("Failed to fetch models for \(provider.displayName): \(error)")
                // Add fallback models
                let fallbackModels = provider.supportedModels.map { modelName in
                    ProviderModel(
                        name: modelName,
                        provider: provider,
                        description: getModelDescription(modelName, provider: provider)
                    )
                }
                allModels.append(contentsOf: fallbackModels)
                
                let group = ModelGroup(
                    provider: provider,
                    models: fallbackModels,
                    isEnabled: chatManager.availableProviders.contains(provider)
                )
                groups.append(group)
            }
        }
        
        availableModels = allModels
        modelGroups = groups
        
        // Enable default models if none are enabled
        if enabledModelIds.isEmpty {
            enableDefaultModels()
        }
        
        isLoading = false
    }
    
    private func fetchModelsForProvider(_ provider: ChatProviderType) async throws -> [String] {
        switch provider {
        case .ollama:
            await ollamaManager.fetchModels()
            return ollamaManager.availableModels.map { $0.name }
        default:
            return try await apiManager.fetchAvailableModels(for: provider)
        }
    }
    
    private func getModelDescription(_ modelName: String, provider: ChatProviderType) -> String? {
        switch provider {
        case .openai:
            if modelName.contains("gpt-4o") {
                return "Latest GPT-4 model with improved performance"
            } else if modelName.contains("gpt-4") {
                return "Most capable model for complex tasks"
            } else if modelName.contains("gpt-3.5") {
                return "Fast and efficient for most tasks"
            }
        case .gemini:
            if modelName.contains("pro") {
                return "Most capable Gemini model"
            } else if modelName.contains("flash") {
                return "Fast and efficient Gemini model"
            }
        case .groq:
            if modelName.contains("mixtral") {
                return "High-performance mixture of experts model"
            } else if modelName.contains("llama") {
                return "Open-source language model"
            }
        case .ollama:
            if let ollamaModel = ollamaManager.availableModels.first(where: { $0.name == modelName }) {
                return "Size: \(ollamaModel.sizeFormatted)"
            }
        }
        return nil
    }
    
    // MARK: - Model Enable/Disable
    
    func toggleModel(_ model: ProviderModel) {
        if enabledModelIds.contains(model.id) {
            enabledModelIds.remove(model.id)
        } else {
            enabledModelIds.insert(model.id)
        }
        saveEnabledModels()
    }
    
    func enableAllModelsForProvider(_ provider: ChatProviderType) {
        let providerModels = availableModels.filter { $0.provider == provider }
        for model in providerModels {
            enabledModelIds.insert(model.id)
        }
        saveEnabledModels()
    }
    
    func disableAllModelsForProvider(_ provider: ChatProviderType) {
        let providerModels = availableModels.filter { $0.provider == provider }
        for model in providerModels {
            enabledModelIds.remove(model.id)
        }
        saveEnabledModels()
    }
    
    func enableDefaultModels() {
        // Enable default model for each provider
        for provider in chatManager.availableProviders {
            if let defaultModel = availableModels.first(where: { 
                $0.provider == provider && $0.name == provider.defaultModel 
            }) {
                enabledModelIds.insert(defaultModel.id)
            } else if let firstModel = availableModels.first(where: { $0.provider == provider }) {
                // If default model not found, enable the first available model
                enabledModelIds.insert(firstModel.id)
            }
        }
        saveEnabledModels()
    }
    
    // MARK: - Utility Methods
    
    func isModelEnabled(_ model: ProviderModel) -> Bool {
        return enabledModelIds.contains(model.id)
    }
    
    func getEnabledModels() -> [ProviderModel] {
        return availableModels.filter { enabledModelIds.contains($0.id) }
    }
    
    func getEnabledModelsForProvider(_ provider: ChatProviderType) -> [ProviderModel] {
        return availableModels.filter { 
            $0.provider == provider && enabledModelIds.contains($0.id) 
        }
    }
    
    // MARK: - Persistence
    
    private func loadEnabledModels() {
        if let data = UserDefaults.standard.data(forKey: enabledModelsKey),
           let decodedIds = try? JSONDecoder().decode(Set<String>.self, from: data) {
            enabledModelIds = decodedIds
        }
    }
    
    private func saveEnabledModels() {
        if let data = try? JSONEncoder().encode(enabledModelIds) {
            UserDefaults.standard.set(data, forKey: enabledModelsKey)
        }
    }
} 