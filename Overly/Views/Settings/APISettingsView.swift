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
                
                // Only show Ollama base URL override
                providerSection(for: .ollama)
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
            Text("Ollama Configuration")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Configure your Ollama base URL override. This allows you to connect to a remote Ollama instance.")
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
                // Base URL field for Ollama
                VStack(alignment: .leading, spacing: 4) {
                    Text("Base URL")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("Enter base URL (default: http://localhost:11434)", text: binding(for: provider, type: .baseURL))
                        .textFieldStyle(.roundedBorder)
                }
            }
            
            HStack {
                Button("Save") {
                    saveCredentials(for: provider)
                }
                .buttonStyle(.borderedProminent)
                
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
        // Only load Ollama base URL
        baseURLs[.ollama] = KeychainManager.shared.getBaseURL(for: .ollama) ?? KeychainManager.APIProvider.ollama.defaultBaseURL
    }
    
    private func saveCredentials(for provider: KeychainManager.APIProvider) {
        saveStatus[provider] = .saving
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            var success = true
            
            // Save base URL for Ollama
            if let baseURL = baseURLs[provider], !baseURL.isEmpty {
                success = success && KeychainManager.shared.saveBaseURL(baseURL, for: provider)
            }
            
            saveStatus[provider] = success ? .success : .error
            
            // Clear status after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                saveStatus[provider] = SaveStatus.none
            }
        }
    }
    
    private func clearCredentials(for provider: KeychainManager.APIProvider) {
        _ = KeychainManager.shared.deleteBaseURL(for: provider)
        
        baseURLs[provider] = provider.defaultBaseURL
        
        saveStatus[provider] = SaveStatus.none
    }
    
    private func hasStoredCredentials(for provider: KeychainManager.APIProvider) -> Bool {
        return KeychainManager.shared.getBaseURL(for: provider) != provider.defaultBaseURL
    }
}

#Preview {
    APISettingsView()
        .frame(width: 600, height: 800)
} 