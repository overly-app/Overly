//
//  ProviderChipViewSettings.swift
//  Overly
//
//  Created by AI Assistant on 1/27/25.
//

import SwiftUI

// Chip-style provider view for settings (similar to ServiceSelectionView)
struct ProviderChipViewSettings: View {
    @Environment(\.colorScheme) var colorScheme
    let provider: ChatProvider
    @ObservedObject var settings: AppSettings
    let onDelete: (String) -> Void
    @State private var isRenaming: Bool = false
    @State private var newProviderName: String = ""

    var isSelected: Bool {
        settings.activeProviderIds.contains(provider.id)
    }

    var body: some View {
        Button(action: {
            if provider.url != nil {
                settings.toggleActiveProvider(id: provider.id)
            }
        }) {
            HStack(spacing: 8) {
                // Checkbox indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .font(.system(size: 14))
                
                // Service icon
                ServiceIconViewSettings(provider: provider, settings: settings, size: 16)
                
                // Service name (editable for custom providers)
                if isRenaming && settings.customProviders.contains(where: { $0.id == provider.id }) {
                    TextField("Provider Name", text: $newProviderName, onCommit: {
                        settings.updateCustomProviderName(id: provider.id, newName: newProviderName)
                        isRenaming = false
                    })
                    .textFieldStyle(.plain)
                    .foregroundColor(.primary)
                    .font(.system(size: 14))
                    .onAppear {
                        newProviderName = provider.name
                    }
                } else {
                    Text(provider.name)
                        .foregroundColor(isSelected ? .white : .primary)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .font(.system(size: 14))
                        .onTapGesture(count: 2) {
                            if settings.customProviders.contains(where: { $0.id == provider.id }) {
                                isRenaming = true
                                newProviderName = provider.name
                            }
                        }
                }
                
                // Delete button for custom providers
                if settings.customProviders.contains(where: { $0.id == provider.id }) {
                    Button(action: {
                        onDelete(provider.id)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                    .opacity(isSelected ? 1.0 : 0.7)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.clear : Color(NSColor.separatorColor), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(provider.url == nil)
        .opacity(provider.url == nil ? 0.5 : 1.0)
    }
} 