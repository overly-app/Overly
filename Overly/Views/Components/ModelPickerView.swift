//
//  ModelPickerView.swift
//  Overly
//
//  Created by AI Assistant on 1/27/25.
//

import SwiftUI

struct ModelPickerView: View {
    @StateObject private var providerManager = AIProviderManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProvider: AIProvider?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Select AI Model")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Refresh") {
                    Task {
                        await providerManager.refreshAllModels()
                    }
                }
                .font(.caption)
            }
            
            // Provider selector
            if providerManager.availableProviders.count > 1 {
                HStack {
                    Text("Provider:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("Provider", selection: Binding(
                        get: { selectedProvider ?? providerManager.selectedProvider },
                        set: { newProvider in
                            selectedProvider = newProvider
                            providerManager.setSelectedProvider(newProvider)
                        }
                    )) {
                        ForEach(providerManager.availableProviders) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(.caption)
                }
            }
            
            if providerManager.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading models...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 20)
            } else if providerManager.currentProviderModels.isEmpty {
                VStack(spacing: 8) {
                    Text("No models found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if providerManager.selectedProvider == .ollama {
                        Text("Make sure Ollama is running and has models installed")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("Check your API key and try refreshing")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.vertical, 20)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(providerManager.currentProviderModels) { model in
                            AIModelRow(
                                model: model,
                                isSelected: model.name == providerManager.selectedModel
                            ) {
                                providerManager.setSelectedModel(model.name)
                                dismiss()
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
            
            if let error = providerManager.error {
                Text("Error: \(error)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 8)
            }
        }
        .padding(16)
        .frame(minWidth: 320)
        .onAppear {
            selectedProvider = providerManager.selectedProvider
            if providerManager.availableModels.isEmpty {
                Task {
                    await providerManager.refreshAllModels()
                }
            }
        }
    }
}

struct AIModelRow: View {
    let model: AIModel
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text(model.provider.displayName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        if !model.isEnabled {
                            Text("Disabled")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 16))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .opacity(model.isEnabled ? 1.0 : 0.6)
        }
        .buttonStyle(.plain)
        .disabled(!model.isEnabled)
    }
} 