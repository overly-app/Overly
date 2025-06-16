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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Select Ollama Model")
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
            
            if providerManager.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading models...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 20)
            } else if providerManager.availableModels.isEmpty {
                VStack(spacing: 8) {
                    Text("No models found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Make sure Ollama is running and has models installed")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 20)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(providerManager.availableModels) { model in
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