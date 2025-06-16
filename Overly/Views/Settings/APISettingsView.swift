import SwiftUI

struct APISettingsView: View {
    @State private var apiKeys: [KeychainManager.APIProvider: String] = [:]
    @State private var baseURLs: [KeychainManager.APIProvider: String] = [:]
    @State private var showingPasswords: [KeychainManager.APIProvider: Bool] = [:]
    @State private var saveStatus: [KeychainManager.APIProvider: SaveStatus] = [:]
    
    enum SaveStatus {
        case none
        case saving
        case success
        case error
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                
                ForEach(KeychainManager.APIProvider.allCases, id: \.self) { provider in
                    providerSection(for: provider)
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            loadStoredCredentials()
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("API Configuration")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Configure your API keys and endpoints for different AI providers. All credentials are securely stored in your system keychain.")
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private func providerSection(for provider: KeychainManager.APIProvider) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(provider.displayName)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
                
                if let status = saveStatus[provider] {
                    statusIndicator(for: status)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                // API Key field
                VStack(alignment: .leading, spacing: 4) {
                    Text("API Key")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack {
                        Group {
                            if showingPasswords[provider] == true {
                                TextField("Enter your \(provider.displayName) API key", text: binding(for: provider, type: .apiKey))
                            } else {
                                SecureField("Enter your \(provider.displayName) API key", text: binding(for: provider, type: .apiKey))
                            }
                        }
                        .textFieldStyle(.roundedBorder)
                        
                        Button(action: {
                            showingPasswords[provider] = !(showingPasswords[provider] ?? false)
                        }) {
                            Image(systemName: showingPasswords[provider] == true ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help(showingPasswords[provider] == true ? "Hide API key" : "Show API key")
                    }
                }
                
                // Base URL field (for providers that support custom endpoints)
                if provider == .ollama || provider == .customOpenAI {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Base URL")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        TextField("Enter base URL", text: binding(for: provider, type: .baseURL))
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
            
            HStack {
                Button("Save") {
                    saveCredentials(for: provider)
                }
                .buttonStyle(.borderedProminent)
                .disabled(apiKeys[provider]?.isEmpty != false)
                
                if hasStoredCredentials(for: provider) {
                    Button("Clear") {
                        clearCredentials(for: provider)
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func statusIndicator(for status: SaveStatus) -> some View {
        Group {
            switch status {
            case .none:
                EmptyView()
            case .saving:
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Saving...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            case .success:
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Saved")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            case .error:
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                    Text("Error")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    private enum CredentialType {
        case apiKey
        case baseURL
    }
    
    private func binding(for provider: KeychainManager.APIProvider, type: CredentialType) -> Binding<String> {
        switch type {
        case .apiKey:
            return Binding(
                get: { apiKeys[provider] ?? "" },
                set: { apiKeys[provider] = $0 }
            )
        case .baseURL:
            return Binding(
                get: { baseURLs[provider] ?? "" },
                set: { baseURLs[provider] = $0 }
            )
        }
    }
    
    private func loadStoredCredentials() {
        for provider in KeychainManager.APIProvider.allCases {
            apiKeys[provider] = KeychainManager.shared.getAPIKey(for: provider) ?? ""
            baseURLs[provider] = KeychainManager.shared.getBaseURL(for: provider) ?? provider.defaultBaseURL
            showingPasswords[provider] = false
        }
    }
    
    private func saveCredentials(for provider: KeychainManager.APIProvider) {
        saveStatus[provider] = .saving
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            var success = true
            
            // Save API key
            if let apiKey = apiKeys[provider], !apiKey.isEmpty {
                success = success && KeychainManager.shared.saveAPIKey(apiKey, for: provider)
            }
            
            // Save base URL if applicable
            if provider == .ollama || provider == .customOpenAI {
                if let baseURL = baseURLs[provider], !baseURL.isEmpty {
                    success = success && KeychainManager.shared.saveBaseURL(baseURL, for: provider)
                }
            }
            
            saveStatus[provider] = success ? .success : .error
            
            // Clear status after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                saveStatus[provider] = SaveStatus.none
            }
        }
    }
    
    private func clearCredentials(for provider: KeychainManager.APIProvider) {
        _ = KeychainManager.shared.deleteAPIKey(for: provider)
        _ = KeychainManager.shared.deleteBaseURL(for: provider)
        
        apiKeys[provider] = ""
        baseURLs[provider] = provider.defaultBaseURL
        
        saveStatus[provider] = SaveStatus.none
    }
    
    private func hasStoredCredentials(for provider: KeychainManager.APIProvider) -> Bool {
        return KeychainManager.shared.getAPIKey(for: provider) != nil
    }
}

#Preview {
    APISettingsView()
        .frame(width: 600, height: 800)
} 