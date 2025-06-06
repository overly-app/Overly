//
//  APIKeySetupView.swift
//  Overly
//
//  Created by AI Assistant on 1/27/25.
//

import SwiftUI

struct APIKeySetupView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var chatManager = ChatManager.shared
    @State private var selectedProvider: ChatProviderType = .openai
    @State private var apiKey: String = ""
    @State private var isSecureEntry: Bool = true
    @State private var isValidating: Bool = false
    @State private var validationResult: ValidationResult?
    @State private var showingDeleteConfirmation: Bool = false
    @State private var providerToDelete: ChatProviderType?
    
    enum ValidationResult {
        case success
        case failure(String)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Content
            ScrollView {
                VStack(spacing: 24) {
                    // Provider selection
                    providerSelectionView
                    
                    // API key input
                    apiKeyInputView
                    
                    // Existing keys
                    existingKeysView
                    
                    // Instructions
                    instructionsView
                }
                .padding(24)
            }
            
            // Footer
            footerView
        }
        .frame(width: 500, height: 600)
        .background(VisualEffectView(material: .sheet, blendingMode: .behindWindow))
        .onAppear {
            loadExistingKey()
        }
        .onChange(of: selectedProvider) { _, _ in
            loadExistingKey()
        }
        .alert("Delete API Key", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let provider = providerToDelete {
                    deleteAPIKey(for: provider)
                }
            }
        } message: {
            if let provider = providerToDelete {
                Text("Are you sure you want to delete the API key for \(provider.displayName)?")
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "key.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                
                Text("API Key Setup")
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
            
            Text("Add your API keys to start chatting with AI models")
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
            Text("Select Provider")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                ForEach(ChatProviderType.allCases, id: \.self) { provider in
                    providerCard(provider)
                }
            }
        }
    }
    
    private func providerCard(_ provider: ChatProviderType) -> some View {
        VStack(spacing: 8) {
            // Icon
            Group {
                if provider.isSystemIcon {
                    Image(systemName: provider.iconName)
                        .font(.system(size: 24, weight: .medium))
                } else {
                    Image(provider.iconName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 28, height: 28)
                }
            }
            .foregroundColor(selectedProvider == provider ? .white : .primary)
            
            // Name
            Text(provider.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(selectedProvider == provider ? .white : .primary)
            
            // Status indicator
            if chatManager.hasAPIKey(for: provider) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(selectedProvider == provider ? .white : .green)
            }
        }
        .frame(height: 80)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(selectedProvider == provider ? Color.accentColor : Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(selectedProvider == provider ? Color.clear : Color(NSColor.separatorColor), lineWidth: 1)
        )
        .onTapGesture {
            selectedProvider = provider
        }
        .scaleEffect(selectedProvider == provider ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedProvider)
    }
    
    // MARK: - API Key Input
    
    private var apiKeyInputView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(selectedProvider.displayName) API Key")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if chatManager.hasAPIKey(for: selectedProvider) {
                    Button("Delete") {
                        providerToDelete = selectedProvider
                        showingDeleteConfirmation = true
                    }
                    .foregroundColor(.red)
                    .font(.caption)
                }
            }
            
            // API Key input field
            VStack(spacing: 8) {
                HStack {
                    Group {
                        if isSecureEntry {
                            SecureField("Enter your API key", text: $apiKey)
                        } else {
                            TextField("Enter your API key", text: $apiKey)
                        }
                    }
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .disabled(isValidating)
                    
                    Button(action: { isSecureEntry.toggle() }) {
                        Image(systemName: isSecureEntry ? "eye" : "eye.slash")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(Color(NSColor.textBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(inputBorderColor, lineWidth: 1)
                )
                
                // Validation result
                if let result = validationResult {
                    validationResultView(result)
                }
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button("Test Key") {
                    testAPIKey()
                }
                .disabled(apiKey.isEmpty || isValidating)
                
                Button("Save Key") {
                    saveAPIKey()
                }
                .buttonStyle(.borderedProminent)
                .disabled(apiKey.isEmpty || isValidating)
                
                if isValidating {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
        }
    }
    
    private var inputBorderColor: Color {
        if let result = validationResult {
            switch result {
            case .success:
                return .green
            case .failure:
                return .red
            }
        }
        return Color(NSColor.separatorColor)
    }
    
    private func validationResultView(_ result: ValidationResult) -> some View {
        HStack(spacing: 6) {
            switch result {
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("API key is valid")
                    .foregroundColor(.green)
            case .failure(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text(message)
                    .foregroundColor(.red)
            }
            Spacer()
        }
        .font(.caption)
    }
    
    // MARK: - Existing Keys
    
    private var existingKeysView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Configured Providers")
                .font(.headline)
                .foregroundColor(.primary)
            
            if chatManager.availableProviders.isEmpty {
                Text("No API keys configured yet")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(chatManager.availableProviders, id: \.self) { provider in
                        existingKeyRow(provider)
                    }
                }
            }
        }
    }
    
    private func existingKeyRow(_ provider: ChatProviderType) -> some View {
        HStack(spacing: 12) {
            // Provider icon
            Group {
                if provider.isSystemIcon {
                    Image(systemName: provider.iconName)
                        .font(.system(size: 16, weight: .medium))
                } else {
                    Image(provider.iconName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                }
            }
            .foregroundColor(.primary)
            
            // Provider name
            Text(provider.displayName)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
            
            // Status
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
            
            // Delete button
            Button(action: {
                providerToDelete = provider
                showingDeleteConfirmation = true
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    // MARK: - Instructions
    
    private var instructionsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How to get API keys:")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 12) {
                instructionRow(
                    provider: .openai,
                    instruction: "Visit platform.openai.com → API Keys → Create new secret key",
                    url: "https://platform.openai.com/api-keys"
                )
                
                instructionRow(
                    provider: .gemini,
                    instruction: "Visit makersuite.google.com → Get API Key → Create API key",
                    url: "https://makersuite.google.com/app/apikey"
                )
                
                instructionRow(
                    provider: .groq,
                    instruction: "Visit console.groq.com → API Keys → Create API Key",
                    url: "https://console.groq.com/keys"
                )
            }
        }
    }
    
    private func instructionRow(provider: ChatProviderType, instruction: String, url: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Group {
                    if provider.isSystemIcon {
                        Image(systemName: provider.iconName)
                            .font(.system(size: 14, weight: .medium))
                    } else {
                        Image(provider.iconName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 16, height: 16)
                    }
                }
                .foregroundColor(.primary)
                
                Text(provider.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Text(instruction)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Open \(provider.displayName) Console") {
                if let url = URL(string: url) {
                    NSWorkspace.shared.open(url)
                }
            }
            .font(.caption)
            .foregroundColor(.accentColor)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Footer
    
    private var footerView: some View {
        HStack {
            Text("API keys are stored securely in your macOS Keychain")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .background(
            VisualEffectView(material: .titlebar, blendingMode: .withinWindow)
        )
    }
    
    // MARK: - Actions
    
    private func loadExistingKey() {
        if chatManager.hasAPIKey(for: selectedProvider) {
            apiKey = "••••••••••••••••" // Show masked key
        } else {
            apiKey = ""
        }
        validationResult = nil
    }
    
    private func testAPIKey() {
        guard !apiKey.isEmpty else { return }
        
        isValidating = true
        validationResult = nil
        
        Task {
            // First do basic validation
            let isValidFormat = await KeychainManager.shared.validateAPIKey(apiKey, for: selectedProvider)
            
            if !isValidFormat {
                await MainActor.run {
                    validationResult = .failure("Invalid API key format")
                    isValidating = false
                }
                return
            }
            
            // Store temporarily for testing
            let tempStored = KeychainManager.shared.storeAPIKey(apiKey, for: selectedProvider)
            
            if tempStored {
                let isValid = await chatManager.testAPIKey(for: selectedProvider)
                
                await MainActor.run {
                    if isValid {
                        validationResult = .success
                    } else {
                        validationResult = .failure("API key test failed. Please check your key.")
                        // Remove the invalid key
                        KeychainManager.shared.deleteAPIKey(for: selectedProvider)
                    }
                    isValidating = false
                }
            } else {
                await MainActor.run {
                    validationResult = .failure("Failed to store API key")
                    isValidating = false
                }
            }
        }
    }
    
    private func saveAPIKey() {
        guard !apiKey.isEmpty else { return }
        
        let success = chatManager.storeAPIKey(apiKey, for: selectedProvider)
        
        if success {
            validationResult = .success
            apiKey = "••••••••••••••••" // Mask the saved key
        } else {
            validationResult = .failure("Failed to save API key")
        }
    }
    
    private func deleteAPIKey(for provider: ChatProviderType) {
        chatManager.deleteAPIKey(for: provider)
        
        if selectedProvider == provider {
            apiKey = ""
            validationResult = nil
        }
    }
}

#Preview {
    APIKeySetupView()
} 