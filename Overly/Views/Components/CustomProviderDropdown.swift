//
//  CustomProviderDropdown.swift
//  Overly
//
//  Created by AI Assistant on 1/27/25.
//

import SwiftUI

// Custom dropdown that mimics macOS Picker style
struct CustomProviderDropdown: View {
    let title: String
    @Binding var selectedProviderId: String
    let providers: [ChatProvider]
    @ObservedObject var settings: AppSettings
    @State private var isExpanded = false
    
    var selectedProvider: ChatProvider? {
        providers.first { $0.id == selectedProviderId }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    if selectedProviderId == "none" {
                        Text("No Default (First Active)")
                            .foregroundColor(.primary)
                    } else if let provider = selectedProvider {
                        HStack(spacing: 6) {
                            ServiceIconViewSettings(provider: provider, settings: settings, size: 16)
                            Text(provider.name)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundColor(.secondary)
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(height: 22)
                .background(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
                .cornerRadius(4)
            }
            .buttonStyle(.plain)
            
            // Dropdown menu
            if isExpanded {
                VStack(alignment: .leading, spacing: 1) {
                    // No Default option
                    Button(action: {
                        selectedProviderId = "none"
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isExpanded = false
                        }
                    }) {
                        HStack {
                            Text("No Default (First Active)")
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedProviderId == "none" {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                                    .font(.system(size: 12, weight: .medium))
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .frame(height: 22)
                        .background(selectedProviderId == "none" ? Color.accentColor.opacity(0.1) : Color.clear)
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        // Add hover effect if needed
                    }
                    
                    // Provider options
                    ForEach(providers, id: \.id) { provider in
                        Button(action: {
                            selectedProviderId = provider.id
                            withAnimation(.easeInOut(duration: 0.15)) {
                                isExpanded = false
                            }
                        }) {
                            HStack {
                                HStack(spacing: 6) {
                                    ServiceIconViewSettings(provider: provider, settings: settings, size: 16)
                                    Text(provider.name)
                                        .foregroundColor(.primary)
                                }
                                Spacer()
                                if selectedProviderId == provider.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                        .font(.system(size: 12, weight: .medium))
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .frame(height: 22)
                            .background(selectedProviderId == provider.id ? Color.accentColor.opacity(0.1) : Color.clear)
                        }
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            // Add hover effect if needed
                        }
                    }
                }
                .background(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
                .cornerRadius(4)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                .zIndex(1000)
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
        .frame(maxWidth: 200)
        .onTapGesture {
            // Close dropdown when tapping outside
            if isExpanded {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded = false
                }
            }
        }
    }
} 