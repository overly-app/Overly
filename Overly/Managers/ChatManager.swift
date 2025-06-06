//
//  ChatManager.swift
//  Overly
//
//  Created by AI Assistant on 1/27/25.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class ChatManager: ObservableObject {
    static let shared = ChatManager()
    
    // MARK: - Published Properties
    @Published var sessions: [ChatSession] = []
    @Published var currentSession: ChatSession?
    @Published var selectedProvider: ChatProviderType = .openai
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showingAPIKeySetup: Bool = false
    @Published var availableProviders: [ChatProviderType] = []
    @Published var availableModels: [String] = []
    
    // MARK: - Private Properties
    private let apiManager = ChatAPIManager.shared
    private let keychainManager = KeychainManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - UserDefaults Keys
    private let selectedProviderKey = "selectedChatProvider"
    private let defaultProviderKey = "defaultChatProvider"
    
    private init() {
        loadSettings()
        updateAvailableProviders()
        createInitialSessionIfNeeded()
    }
    
    // MARK: - Settings Management
    
    private func loadSettings() {
        // Load selected provider
        if let savedProvider = UserDefaults.standard.string(forKey: selectedProviderKey),
           let provider = ChatProviderType(rawValue: savedProvider) {
            selectedProvider = provider
        }
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(selectedProvider.rawValue, forKey: selectedProviderKey)
    }
    
    func updateAvailableProviders() {
        availableProviders = keychainManager.getAllStoredProviders()
        
        // If current provider is not available, switch to first available or show setup
        if !availableProviders.contains(selectedProvider) {
            if let firstAvailable = availableProviders.first {
                selectedProvider = firstAvailable
                saveSettings()
            } else {
                showingAPIKeySetup = true
            }
        }
    }
    
    // MARK: - Session Management
    
    func createNewSession(provider: ChatProviderType? = nil) {
        let sessionProvider = provider ?? selectedProvider
        let newSession = ChatSession(provider: sessionProvider)
        
        // Deactivate current session
        currentSession?.isActive = false
        
        // Add and activate new session
        sessions.insert(newSession, at: 0)
        currentSession = newSession
        newSession.isActive = true
        
        // Limit to 10 sessions
        if sessions.count > 10 {
            sessions = Array(sessions.prefix(10))
        }
    }
    
    func selectSession(_ session: ChatSession) {
        currentSession?.isActive = false
        currentSession = session
        session.isActive = true
        selectedProvider = session.provider
        saveSettings()
    }
    
    func deleteSession(_ session: ChatSession) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions.remove(at: index)
            
            // If this was the current session, select another
            if currentSession?.id == session.id {
                currentSession = sessions.first
                currentSession?.isActive = true
            }
        }
    }
    
    func createInitialSessionIfNeeded() {
        if sessions.isEmpty && !availableProviders.isEmpty {
            createNewSession()
        }
    }
    
    // MARK: - Provider Management
    
    func switchProvider(_ provider: ChatProviderType) {
        guard availableProviders.contains(provider) else {
            showingAPIKeySetup = true
            return
        }
        
        selectedProvider = provider
        saveSettings()
        
        // Fetch available models for the new provider
        Task {
            await fetchModelsForProvider(provider)
        }
        
        // Update current session provider or create new session
        if let current = currentSession {
            current.provider = provider
            // Update model to provider's default if current model isn't available
            if !availableModels.contains(current.model) {
                current.model = provider.defaultModel
            }
        } else {
            createNewSession(provider: provider)
        }
    }
    
    func fetchModelsForProvider(_ provider: ChatProviderType) async {
        do {
            print("Fetching models for \(provider.rawValue)...")
            let models = try await apiManager.fetchAvailableModels(for: provider)
            await MainActor.run {
                self.availableModels = models
                print("✅ Successfully loaded \(models.count) models for \(provider.rawValue)")
                
                // Update current session model if it's not in the available list
                if let currentSession = self.currentSession,
                   currentSession.provider == provider,
                   !models.contains(currentSession.model) {
                    print("⚠️ Current model '\(currentSession.model)' not available, switching to default")
                    currentSession.model = provider.defaultModel
                }
            }
        } catch {
            print("❌ Failed to fetch models for \(provider.rawValue): \(error)")
            await MainActor.run {
                // Use fallback models
                self.availableModels = provider.supportedModels
                print("🔄 Using fallback models: \(provider.supportedModels)")
            }
        }
    }
    
    // MARK: - Message Sending
    
    func sendMessage(_ content: String) {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let session = currentSession else {
            createNewSession()
            guard let session = currentSession else { return }
            sendMessage(content)
            return
        }
        
        // Clear any previous error
        errorMessage = nil
        isLoading = true
        
        // Add user message
        let userMessage = ChatMessage(
            content: content,
            role: .user,
            provider: session.provider.rawValue
        )
        session.addMessage(userMessage)
        
        // Add placeholder assistant message for streaming
        let assistantMessage = ChatMessage(
            content: "",
            role: .assistant,
            provider: session.provider.rawValue,
            isStreaming: true
        )
        session.addMessage(assistantMessage)
        
        // Send message with streaming
        apiManager.sendMessageStream(
            content,
            to: session.provider,
            model: session.model,
            conversationHistory: Array(session.messages.dropLast(2)), // Exclude the two messages we just added
            temperature: 0.7,
            onChunk: { [weak self, weak session] chunk in
                guard let self = self, let session = session else { return }
                
                // Update the last message content
                if let lastMessage = session.messages.last {
                    let updatedContent = lastMessage.content + chunk
                    session.updateLastMessage(content: updatedContent)
                }
            },
            onComplete: { [weak self, weak session] in
                guard let self = self, let session = session else { return }
                
                self.isLoading = false
                session.setLastMessageStreaming(false)
            },
            onError: { [weak self, weak session] error in
                guard let self = self, let session = session else { return }
                
                self.isLoading = false
                self.errorMessage = error.localizedDescription
                
                // Remove the failed assistant message
                if let lastIndex = session.messages.indices.last {
                    session.messages.remove(at: lastIndex)
                }
                
                // Handle specific errors
                if case ChatError.invalidAPIKey = error {
                    self.showingAPIKeySetup = true
                }
            }
        )
    }
    
    // MARK: - API Key Management
    
    func storeAPIKey(_ key: String, for provider: ChatProviderType) -> Bool {
        let success = keychainManager.storeAPIKey(key, for: provider)
        if success {
            updateAvailableProviders()
            
            // Fetch models for the new provider
            Task {
                await fetchModelsForProvider(provider)
            }
            
            // If this is the first API key, create a session
            if currentSession == nil {
                createNewSession(provider: provider)
            }
        }
        return success
    }
    
    func hasAPIKey(for provider: ChatProviderType) -> Bool {
        return keychainManager.hasAPIKey(for: provider)
    }
    
    func deleteAPIKey(for provider: ChatProviderType) {
        _ = keychainManager.deleteAPIKey(for: provider)
        updateAvailableProviders()
        
        // If we deleted the current provider's key, switch or show setup
        if selectedProvider == provider {
            if let firstAvailable = availableProviders.first {
                switchProvider(firstAvailable)
            } else {
                showingAPIKeySetup = true
            }
        }
    }
    
    func testAPIKey(for provider: ChatProviderType) async -> Bool {
        return await apiManager.testAPIKey(for: provider)
    }
    
    // MARK: - Utility Methods
    
    func clearAllSessions() {
        sessions.removeAll()
        currentSession = nil
    }
    
    func exportSession(_ session: ChatSession) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        var export = "# \(session.title)\n"
        export += "Provider: \(session.provider.displayName)\n"
        export += "Model: \(session.model)\n"
        export += "Created: \(formatter.string(from: session.createdAt))\n\n"
        
        for message in session.messages {
            let role = message.role == .user ? "**You**" : "**Assistant**"
            export += "\(role): \(message.content)\n\n"
        }
        
        return export
    }
    
    func getSessionsForProvider(_ provider: ChatProviderType) -> [ChatSession] {
        return sessions.filter { $0.provider == provider }
    }
} 