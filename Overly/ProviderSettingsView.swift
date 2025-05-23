//
//  ProviderSettingsView.swift
//  Overly
//
//  Created by hypackel on 5/23/25.
//

import SwiftUI

// Custom view for the provider chip design (same as ServiceSelectionView)
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
            if provider.url != nil { // Only toggle for web providers
                settings.toggleActiveProvider(id: provider.id)
            }
        }) {
            HStack {
                ServiceIconViewSettings(provider: provider, settings: settings)
                
                // Show TextField for renaming if in renaming mode and is a custom provider
                if isRenaming && settings.customProviders.contains(where: { $0.id == provider.id }) {
                    TextField("Provider Name", text: $newProviderName, onCommit: {
                        settings.updateCustomProviderName(id: provider.id, newName: newProviderName)
                        isRenaming = false
                    })
                    .textFieldStyle(.plain)
                    .foregroundColor(isSelected ? (colorScheme == .dark ? .black : .white) : .primary)
                    .fontWeight(isSelected ? .bold : .regular)
                    .onAppear {
                        newProviderName = provider.name
                    }
                } else {
                    Text(provider.name)
                        .foregroundColor(isSelected ? (colorScheme == .dark ? .black : .white) : .primary)
                        .fontWeight(isSelected ? .bold : .regular)
                        .onTapGesture(count: 2) {
                            if settings.customProviders.contains(where: { $0.id == provider.id }) {
                                isRenaming = true
                                newProviderName = provider.name
                            }
                        }
                }

                // Add remove button for custom providers
                if settings.customProviders.contains(where: { $0.id == provider.id }) {
                    Button(action: {
                        onDelete(provider.id)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? (colorScheme == .dark ? .white : .black) : (colorScheme == .dark ? Color.gray.opacity(0.2) : Color.gray.opacity(0.1)))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? (colorScheme == .dark ? .white : .black) : .clear, lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .contextMenu {
            if settings.customProviders.contains(where: { $0.id == provider.id }) {
                Button("Delete", role: .destructive) {
                    onDelete(provider.id)
                }
                Button("Rename") {
                    isRenaming = true
                    newProviderName = provider.name
                }
            }
        }
    }
}

// Helper view to display service icons (same as ServiceSelectionView)
struct ServiceIconViewSettings: View {
    let provider: ChatProvider
    @ObservedObject var settings: AppSettings
    
    var body: some View {
        Group {
            if let favicon = settings.faviconImage(for: provider) {
                favicon
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
            } else if provider.isSystemImage {
                 Image(systemName: provider.iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
            } else {
                 Image(provider.iconName)
                     .resizable()
                     .aspectRatio(contentMode: .fit)
                     .frame(width: 20, height: 20)
                     .onAppear {
                         if provider.url != nil && settings.faviconCache[provider.id] == nil && settings.customProviders.contains(where: { $0.id == provider.id }) {
                             Task {
                                 await settings.fetchFavicon(for: provider)
                             }
                         }
                     }
            }
        }
    }
}

// Extracted view for adding a new provider
struct AddProviderView: View {
    @ObservedObject var settings: AppSettings
    @Binding var newProviderName: String
    @Binding var newProviderURLString: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add Custom Provider")
                .font(.headline)
                .padding(.leading)

            HStack {
                TextField("Provider Name", text: $newProviderName)
                    .textFieldStyle(.roundedBorder)
                TextField("Provider URL", text: $newProviderURLString)
                    .textFieldStyle(.roundedBorder)
                Button("Add") {
                    if !newProviderName.isEmpty && !newProviderURLString.isEmpty {
                        var urlString = newProviderURLString
                        if !urlString.contains("://") {
                            urlString = "https://" + urlString
                        }

                        if let url = URL(string: urlString) {
                            let newProvider = ChatProvider(
                                id: UUID().uuidString,
                                name: newProviderName,
                                url: url,
                                iconName: "link",
                                isSystemImage: true
                            )
                            settings.addCustomProvider(newProvider)
                            
                            Task {
                                await settings.fetchFavicon(for: newProvider)
                            }

                            newProviderName = ""
                            newProviderURLString = ""
                        }
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
        }
    }
}

struct ProviderSettingsView: View {
     @ObservedObject var settings = AppSettings.shared

     @State private var newProviderName: String = ""
     @State private var newProviderURLString: String = ""

     var body: some View {
         VStack(alignment: .leading, spacing: 20) {
             Text("Provider Settings")
                 .font(.largeTitle)
                 .padding(.top)

             // Section for Built-in Providers
             VStack(alignment: .leading) {
                 Text("Built-in Providers")
                     .font(.headline)
                     .padding(.leading)

                 ScrollView(.horizontal, showsIndicators: false) {
                     HStack {
                         ForEach(settings.allBuiltInProviders.filter { $0.url != nil }) { provider in
                             ProviderChipViewSettings(provider: provider, settings: settings, onDelete: deleteCustomProvider)
                         }
                     }
                     .padding(.horizontal)
                 }
                 .frame(height: 60)
             }

             Divider()
                 .padding(.vertical, 20)

             // Section for Custom Providers
             VStack(alignment: .leading) {
                 Text("Custom Providers")
                     .font(.headline)
                     .padding(.leading)

                 ScrollView(.horizontal, showsIndicators: false) {
                     HStack {
                         ForEach(settings.customProviders) { provider in
                             ProviderChipViewSettings(provider: provider, settings: settings, onDelete: deleteCustomProvider)
                         }
                     }
                     .padding(.horizontal)
                 }
                 .frame(height: 60)
             }
             .padding(.bottom)

             Divider()

             // Section for adding custom providers
             AddProviderView(settings: settings, newProviderName: $newProviderName, newProviderURLString: $newProviderURLString)

             Spacer()
         }
         .padding()
         .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
         .onAppear {
             for provider in settings.allBuiltInProviders where settings.activeProviderIds.contains(provider.id) && provider.url != nil && settings.faviconCache[provider.id] == nil {
                  Task {
                       await settings.fetchFavicon(for: provider)
                   }
             }
         }
     }
     
     // Function to handle deleting custom providers by ID
     func deleteCustomProvider(id: String) {
         settings.customProviders.removeAll { $0.id == id }
         settings.activeProviderIds.remove(id)
         settings.faviconCache.removeValue(forKey: id)
         settings.saveSettings()
     }
}

#Preview {
    ProviderSettingsView()
}