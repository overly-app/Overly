import SwiftUI

struct ModelManagementView: View {
    @StateObject private var providerManager = AIProviderManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "server.rack")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ollama Models")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("No API key required")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    
                    Spacer()
                    
                    // Refresh button
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
                    
                    // Bulk actions
                    HStack(spacing: 8) {
                        Button("Enable All") {
                            providerManager.enableAllModels(for: .ollama)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button("Disable All") {
                            providerManager.disableAllModels(for: .ollama)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                
                let ollamaModels = providerManager.availableModels.filter { $0.provider == .ollama }
                let enabledCount = ollamaModels.filter { $0.isEnabled }.count
                
                HStack {
                    Text("\(enabledCount) of \(ollamaModels.count) models enabled")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
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
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Models list
            ScrollView {
                LazyVStack(spacing: 8) {
                    let models = providerManager.availableModels.filter { $0.provider == .ollama }
                    
                    if models.isEmpty {
                        emptyModelsView()
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
        .navigationTitle("Ollama Models")
        .onAppear {
            Task {
                await providerManager.refreshAllModels()
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
    
    private func emptyModelsView() -> some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No models available")
                    .font(.headline)
                    .foregroundColor(.primary)
                
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

}

#Preview {
    ModelManagementView()
        .frame(width: 800, height: 600)
} 