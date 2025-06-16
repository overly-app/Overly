import SwiftUI

struct ModelManagementView: View {
    @StateObject private var providerManager = AIProviderManager.shared
    @State private var selectedProvider: AIProvider?
    
    var body: some View {
        NavigationSplitView {
            // Sidebar with providers
            providerSidebar
        } detail: {
            // Main content area
            if let provider = selectedProvider {
                providerDetailView(provider)
            } else {
                emptyStateView
            }
        }
        .navigationTitle("Model Management")
        .onAppear {
            if selectedProvider == nil {
                selectedProvider = providerManager.availableProviders.first
            }
            Task {
                await providerManager.refreshAllModels()
            }
        }
    }
    
    // MARK: - Provider Sidebar
    
    private var providerSidebar: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                HStack {
                    Text("AI Providers")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button(action: {
                        Task {
                            await providerManager.refreshAllModels()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Refresh models")
                }
                
                if providerManager.isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading models...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            // Provider list
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(providerManager.availableProviders) { provider in
                        providerRow(provider)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            
            if providerManager.availableProviders.isEmpty {
                Spacer()
                
                VStack(spacing: 12) {
                    Image(systemName: "key.slash")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    
                    Text("No providers available")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Add API keys in Settings → API Keys")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                
                Spacer()
            }
        }
        .frame(minWidth: 200, idealWidth: 250)
    }
    
    private func providerRow(_ provider: AIProvider) -> some View {
        Button(action: {
            selectedProvider = provider
        }) {
            HStack(spacing: 12) {
                // Provider icon
                Group {
                    if provider.iconName.contains(".") {
                        Image(systemName: provider.iconName)
                            .font(.system(size: 16, weight: .medium))
                    } else {
                        Image(provider.iconName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 18, height: 18)
                    }
                }
                .foregroundColor(selectedProvider == provider ? .white : .primary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(selectedProvider == provider ? .white : .primary)
                    
                    let providerModels = providerManager.availableModels.filter { $0.provider == provider }
                    let enabledCount = providerModels.filter { $0.isEnabled }.count
                    
                    Text("\(enabledCount)/\(providerModels.count) enabled")
                        .font(.caption)
                        .foregroundColor(selectedProvider == provider ? .white.opacity(0.8) : .secondary)
                }
                
                Spacer()
                
                if !provider.requiresAPIKey {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(selectedProvider == provider ? .white : .green)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedProvider == provider ? Color.accentColor : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Provider Detail View
    
    private func providerDetailView(_ provider: AIProvider) -> some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                HStack {
                    Group {
                        if provider.iconName.contains(".") {
                            Image(systemName: provider.iconName)
                                .font(.system(size: 24, weight: .medium))
                        } else {
                            Image(provider.iconName)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 28, height: 28)
                        }
                    }
                    .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(provider.displayName)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        if provider.requiresAPIKey {
                            Text("API key required")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("No API key required")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    
                    Spacer()
                    
                    // Bulk actions
                    HStack(spacing: 8) {
                        Button("Enable All") {
                            providerManager.enableAllModels(for: provider)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button("Disable All") {
                            providerManager.disableAllModels(for: provider)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                
                let providerModels = providerManager.availableModels.filter { $0.provider == provider }
                let enabledCount = providerModels.filter { $0.isEnabled }.count
                
                HStack {
                    Text("\(enabledCount) of \(providerModels.count) models enabled")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Models list
            ScrollView {
                LazyVStack(spacing: 8) {
                    let models = providerManager.availableModels.filter { $0.provider == provider }
                    
                    if models.isEmpty {
                        emptyModelsView(for: provider)
                    } else {
                        ForEach(models) { model in
                            modelRow(model)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
        }
    }
    
    private func modelRow(_ model: AIModel) -> some View {
        HStack(spacing: 16) {
            // Toggle switch
            Toggle("", isOn: Binding(
                get: { model.isEnabled },
                set: { _ in providerManager.toggleModel(model) }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(model.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(model.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fontDesign(.monospaced)
            }
            
            Spacer()
            
            // Current selection indicator
            if model.name == providerManager.selectedModel && model.provider == providerManager.selectedProvider {
                Text("Current")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .opacity(model.isEnabled ? 1.0 : 0.6)
    }
    
    private func emptyModelsView(for provider: AIProvider) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No models available")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if provider == .ollama {
                    Text("Make sure Ollama is running and has models installed")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("Run 'ollama pull llama3.2' to install a model")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fontDesign(.monospaced)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Text("Check your API key and try refreshing")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            Button("Refresh Models") {
                Task {
                    await providerManager.refreshAllModels()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: 400)
        .padding(.vertical, 40)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "brain")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                Text("Select a Provider")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Choose a provider from the sidebar to manage its models")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: 400)
    }
}

#Preview {
    ModelManagementView()
        .frame(width: 800, height: 600)
} 