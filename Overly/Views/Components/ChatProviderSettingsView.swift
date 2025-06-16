//
//  ProviderSettingsView.swift
//  Overly
//
//  Created by AI Assistant on 1/27/25.
//

import SwiftUI

struct ChatProviderSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var chatManager = ChatManager.shared
    @State private var selectedProvider: ChatProviderType = .openai
    @State private var selectedModel: String = ""
    @State private var temperature: Double = 0.7
    @State private var maxTokens: Int = 2000
    @State private var showingAPIKeySetup = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Content
            ScrollView {
                VStack(spacing: 24) {
                    // Provider selection
                    providerSelectionView
                    
                    // Model settings
                    if !chatManager.availableProviders.isEmpty {
                        modelSettingsView
                        
                        // Generation parameters
                        generationParametersView
                        
                        // Session management
                        sessionManagementView
                    } else {
                        emptyStateView
                    }
                }
                .padding(24)
            }
            
            // Footer
            footerView
        }
        .frame(width: 500, height: 600)
        .background(VisualEffectView(material: .sheet, blendingMode: .behindWindow))
        .onAppear {
            loadSettings()
            // Fetch models for the current provider
            Task {
                await chatManager.fetchModelsForProvider(selectedProvider)
            }
        }
        .onChange(of: selectedProvider) { _, _ in
            loadModelForProvider()
            // Fetch models for the new provider
            Task {
                await chatManager.fetchModelsForProvider(selectedProvider)
            }
        }
        .sheet(isPresented: $showingAPIKeySetup) {
            APIKeySetupView()
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                
                Text("Provider Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Text("Configure AI models and chat parameters")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .background(
            VisualEffectView(material: .titlebar, blendingMode: .withinWindow)
        )
    }
    
    // MARK: - Provider Selection
    
    private var providerSelectionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Provider")
                .font(.headline)
                .foregroundColor(.primary)
            
            if !chatManager.availableProviders.isEmpty {
                Picker("Provider", selection: $selectedProvider) {
                    ForEach(chatManager.availableProviders, id: \.self) { provider in
                        HStack(spacing: 8) {
                            providerIcon(provider)
                            Text(provider.displayName)
                        }
                        .tag(provider)
                    }
                }
                .pickerStyle(.segmented)
            } else {
                Button("Setup API Keys") {
                    showingAPIKeySetup = true
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    private func providerIcon(_ provider: ChatProviderType) -> some View {
        Group {
            if provider.isSystemIcon {
                Image(systemName: provider.iconName)
                    .font(.system(size: 12, weight: .medium))
            } else {
                Image(provider.iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 12, height: 12)
            }
        }
        .foregroundColor(.primary)
    }
    
    // MARK: - Model Settings
    
    private var modelSettingsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Model Configuration")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 16) {
                // Model selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Model")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Picker("Model", selection: $selectedModel) {
                        ForEach(chatManager.availableModels.isEmpty ? selectedProvider.supportedModels : chatManager.availableModels, id: \.self) { model in
                            Text(model)
                                .tag(model)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Model info
                modelInfoView
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
        }
    }
    
    private var modelInfoView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Model Information")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text(modelDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private var modelDescription: String {
        switch selectedProvider {
        case .openai:
            switch selectedModel {
            case "gpt-4":
                return "Most capable model, best for complex tasks requiring deep understanding."
            case "gpt-4-turbo":
                return "Faster version of GPT-4 with improved performance and lower latency."
            case "gpt-3.5-turbo":
                return "Fast and efficient model, good for most conversational tasks."
            default:
                return "OpenAI language model optimized for chat conversations."
            }
        case .gemini:
            switch selectedModel {
            case "gemini-pro":
                return "Google's most capable model for text generation and understanding."
            case "gemini-pro-vision":
                return "Multimodal model that can process both text and images."
            default:
                return "Google's Gemini model for advanced AI conversations."
            }
        case .groq:
            switch selectedModel {
            case "mixtral-8x7b-32768":
                return "High-performance mixture of experts model with 32k context."
            case "llama2-70b-4096":
                return "Large language model with 70B parameters and 4k context."
            case "gemma-7b-it":
                return "Instruction-tuned model optimized for following directions."
            default:
                return "High-speed inference model powered by Groq's LPU technology."
            }
        case .ollama:
            switch selectedModel {
            case "llama3.2":
                return "Meta's latest Llama model running locally via Ollama."
            case "llama3.1":
                return "Previous version of Meta's Llama model with strong performance."
            case "codellama":
                return "Specialized model for code generation and programming tasks."
            case "mistral":
                return "Efficient open-source model with good reasoning capabilities."
            default:
                return "Local AI model running through Ollama server."
            }
        }
    }
    
    // MARK: - Generation Parameters
    
    private var generationParametersView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Generation Parameters")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 16) {
                // Temperature
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Temperature")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text(String(format: "%.1f", temperature))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    
                    Slider(value: $temperature, in: 0.0...2.0, step: 0.1)
                    
                    Text("Controls randomness. Lower values make responses more focused and deterministic.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Max tokens
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Max Tokens")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text("\(maxTokens)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    
                    Slider(value: Binding(
                        get: { Double(maxTokens) },
                        set: { maxTokens = Int($0) }
                    ), in: 100...4000, step: 100)
                    
                    Text("Maximum number of tokens in the response. Higher values allow longer responses.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Session Management
    
    private var sessionManagementView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session Management")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                // Active sessions count
                HStack {
                    Text("Active Sessions")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(chatManager.sessions.count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Sessions for current provider
                HStack {
                    Text("Sessions for \(selectedProvider.displayName)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(chatManager.getSessionsForProvider(selectedProvider).count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Actions
                VStack(spacing: 8) {
                    Button("Clear All Sessions") {
                        chatManager.clearAllSessions()
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    
                    Button("Export Current Session") {
                        exportCurrentSession()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(chatManager.currentSession == nil)
                }
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "key.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                Text("No API Keys Configured")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Add your API keys to configure provider settings")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Setup API Keys") {
                showingAPIKeySetup = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: 300)
    }
    
    // MARK: - Footer
    
    private var footerView: some View {
        HStack {
            Button("Reset to Defaults") {
                resetToDefaults()
            }
            .foregroundColor(.secondary)
            
            Spacer()
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                
                Button("Save") {
                    saveSettings()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .background(
            VisualEffectView(material: .titlebar, blendingMode: .withinWindow)
        )
    }
    
    // MARK: - Actions
    
    private func loadSettings() {
        selectedProvider = chatManager.selectedProvider
        loadModelForProvider()
        
        // Load other settings from UserDefaults or use defaults
        temperature = UserDefaults.standard.object(forKey: "chatTemperature") as? Double ?? 0.7
        maxTokens = UserDefaults.standard.object(forKey: "chatMaxTokens") as? Int ?? 2000
    }
    
    private func loadModelForProvider() {
        if let currentSession = chatManager.currentSession,
           currentSession.provider == selectedProvider {
            selectedModel = currentSession.model
        } else {
            selectedModel = selectedProvider.defaultModel
        }
    }
    
    private func saveSettings() {
        // Update chat manager
        chatManager.switchProvider(selectedProvider)
        
        // Update current session model if it exists
        if let currentSession = chatManager.currentSession {
            currentSession.model = selectedModel
        }
        
        // Save to UserDefaults
        UserDefaults.standard.set(temperature, forKey: "chatTemperature")
        UserDefaults.standard.set(maxTokens, forKey: "chatMaxTokens")
        UserDefaults.standard.synchronize()
    }
    
    private func resetToDefaults() {
        temperature = 0.7
        maxTokens = 2000
        selectedModel = selectedProvider.defaultModel
    }
    
    private func exportCurrentSession() {
        guard let session = chatManager.currentSession else { return }
        
        let exportString = chatManager.exportSession(session)
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "\(session.title).txt"
        
        savePanel.begin { result in
            if result == .OK, let url = savePanel.url {
                do {
                    try exportString.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    print("Failed to export session: \(error)")
                }
            }
        }
    }
}

#Preview {
    ChatProviderSettingsView()
} 