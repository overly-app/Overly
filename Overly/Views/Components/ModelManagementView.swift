//
//  ModelManagementView.swift
//  Overly
//
//  Created by AI Assistant on 1/27/25.
//

import SwiftUI

struct ModelManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var modelManager = ModelManager.shared
    @StateObject private var chatManager = ChatManager.shared
    @State private var selectedProvider: ChatProviderType?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Content
            if modelManager.isLoading {
                loadingView
            } else if modelManager.modelGroups.isEmpty {
                emptyStateView
            } else {
                contentView
            }
            
            // Footer
            footerView
        }
        .frame(width: 700, height: 600)
        .background(VisualEffectView(material: .sheet, blendingMode: .behindWindow))
        .onAppear {
            Task {
                await modelManager.refreshAllModels()
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                
                Text("Model Management")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Refresh") {
                    Task {
                        await modelManager.refreshAllModels()
                    }
                }
                .buttonStyle(.bordered)
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Text("Enable or disable AI models from all your configured providers")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .background(
            VisualEffectView(material: .titlebar, blendingMode: .withinWindow)
        )
    }
    
    // MARK: - Content Views
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading models...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                Text("No Models Available")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Configure your API keys to access AI models")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Setup API Keys") {
                chatManager.showingAPIKeySetup = true
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: 300)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var contentView: some View {
        HSplitView {
            // Sidebar - Provider list
            providerSidebar
                .frame(minWidth: 200, maxWidth: 250)
            
            // Main content - Model list
            modelListView
                .frame(minWidth: 400)
        }
    }
    
    // MARK: - Provider Sidebar
    
    private var providerSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Sidebar header
            HStack {
                Text("Providers")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(modelManager.modelGroups.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Provider list
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(modelManager.modelGroups) { group in
                        providerRow(group)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private func providerRow(_ group: ModelGroup) -> some View {
        HStack(spacing: 12) {
            // Provider icon
            Group {
                if group.provider.isSystemIcon {
                    Image(systemName: group.provider.iconName)
                        .font(.system(size: 16, weight: .medium))
                } else {
                    Image(group.provider.iconName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                }
            }
            .foregroundColor(selectedProvider == group.provider ? .white : .primary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(group.provider.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(selectedProvider == group.provider ? .white : .primary)
                
                Text("\(group.models.count) models")
                    .font(.caption)
                    .foregroundColor(selectedProvider == group.provider ? .white.opacity(0.8) : .secondary)
            }
            
            Spacer()
            
            // Enabled count
            let enabledCount = group.models.filter { modelManager.isModelEnabled($0) }.count
            Text("\(enabledCount)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(selectedProvider == group.provider ? .white : .primary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    (selectedProvider == group.provider ? Color.white.opacity(0.2) : Color(NSColor.separatorColor))
                )
                .cornerRadius(4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(selectedProvider == group.provider ? Color.accentColor : Color.clear)
        )
        .onTapGesture {
            selectedProvider = group.provider
        }
        .animation(.easeInOut(duration: 0.2), value: selectedProvider)
    }
    
    // MARK: - Model List View
    
    private var modelListView: some View {
        VStack(spacing: 0) {
            if let selectedProvider = selectedProvider,
               let group = modelManager.modelGroups.first(where: { $0.provider == selectedProvider }) {
                
                // Model list header
                modelListHeader(for: group)
                
                Divider()
                
                // Model list
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(group.models) { model in
                            modelRow(model)
                        }
                    }
                    .padding(16)
                }
                
            } else {
                // No provider selected
                VStack(spacing: 16) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    
                    Text("Select a provider to view models")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    private func modelListHeader(for group: ModelGroup) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(group.provider.displayName) Models")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                let enabledCount = group.models.filter { modelManager.isModelEnabled($0) }.count
                Text("\(enabledCount) of \(group.models.count) enabled")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button("Enable All") {
                    modelManager.enableAllModelsForProvider(group.provider)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("Disable All") {
                    modelManager.disableAllModelsForProvider(group.provider)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private func modelRow(_ model: ProviderModel) -> some View {
        HStack(spacing: 12) {
            // Enable/disable toggle
            Toggle("", isOn: Binding(
                get: { modelManager.isModelEnabled(model) },
                set: { _ in modelManager.toggleModel(model) }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(model.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                
                if let description = model.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Provider badge
            Text(model.provider.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(4)
        }
        .padding(12)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
    }
    
    // MARK: - Footer
    
    private var footerView: some View {
        HStack {
            let enabledCount = modelManager.getEnabledModels().count
            let totalCount = modelManager.availableModels.count
            
            Text("\(enabledCount) of \(totalCount) models enabled")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            HStack(spacing: 12) {
                Button("Enable Defaults") {
                    modelManager.enableDefaultModels()
                }
                .buttonStyle(.bordered)
                
                Button("Done") {
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
}

#Preview {
    ModelManagementView()
} 