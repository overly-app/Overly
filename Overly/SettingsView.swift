//
//  SettingsView.swift
//  Overly
//
//  Created by hypackel on 5/22/25.
//

import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared // Use the shared settings instance
    @Environment(\.presentationMode) var presentationMode // To dismiss the view, though we are replacing window content
    
    // Keep a reference to the WindowManager to allow switching back to the web view
    weak var windowManager: WindowManager? // Use weak to avoid retain cycles
    
    @State private var newProviderName: String = ""
    @State private var newProviderURLString: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.largeTitle)

            // Section for managing providers
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Manage Providers")
                        .font(.headline)

                    // List of all providers (built-in and custom)
                    ForEach(settings.allBuiltInProviders + settings.customProviders) {
                        provider in
                        HStack {
                            // Display favicon if available
                            if let favicon = settings.faviconImage(for: provider) {
                                favicon
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 20, height: 20)
                            } else if provider.isSystemImage {
                                // Use systemName for SF Symbols
                                Image(systemName: provider.iconName)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 20, height: 20)
                            } else {
                                // Use asset catalog or placeholder
                                Image(provider.iconName) // Assuming iconName is a valid asset or placeholder
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 20, height: 20)
                                    .onAppear {
                                        // Attempt to fetch favicon if it's a custom provider without a cached icon
                                        if provider.url != nil && settings.faviconCache[provider.id] == nil && settings.customProviders.contains(where: { $0.id == provider.id }) {
                                            Task {
                                                await settings.fetchFavicon(for: provider)
                                            }
                                        }
                                    }
                            }

                            Text(provider.name)

                            Spacer()

                            if provider.url != nil { // Only show toggle for web providers
                                Toggle("Active", isOn: Binding(get: {
                                    settings.activeProviderIds.contains(provider.id)
                                }, set: {
                                    isActive in
                                    settings.toggleActiveProvider(id: provider.id)
                                }))
                                .labelsHidden()
                            }

                            // Option to remove custom providers
                            if settings.customProviders.contains(where: { $0.id == provider.id }) {
                                Button(action: {
                                    settings.removeCustomProvider(id: provider.id)
                                }) {
                                    Image(systemName: "minus.circle")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Divider()

            // Section for adding custom providers
            VStack(alignment: .leading, spacing: 10) {
                Text("Add Custom Provider")
                    .font(.headline)

                TextField("Name", text: $newProviderName)
                TextField("URL", text: $newProviderURLString)

                Button("Add Provider") {
                    if !newProviderName.isEmpty && !newProviderURLString.isEmpty,
                       let url = URL(string: newProviderURLString) {
                        let newProvider = ChatProvider(
                            id: UUID().uuidString, // Unique ID for custom providers
                            name: newProviderName,
                            url: url,
                            iconName: "link", // Default placeholder icon
                            isSystemImage: true // Use system image for placeholder
                        )
                        settings.addCustomProvider(newProvider)
                        // Attempt to fetch favicon immediately after adding
                        Task {
                             await settings.fetchFavicon(for: newProvider)
                         }
                        // Clear input fields
                        newProviderName = ""
                        newProviderURLString = ""
                    }
                }
                .disabled(newProviderName.isEmpty || newProviderURLString.isEmpty)
            }

            Spacer()
            
            // Add a button to go back to the main web view (if windowManager is available)
            if windowManager != nil {
                Button("Back to Web View") {
                    windowManager?.showWebView()
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Expand to fill the window
        .onAppear {
            // Pre-fetch favicons for active built-in providers when settings appear
            for provider in settings.allBuiltInProviders where settings.activeProviderIds.contains(provider.id) && provider.url != nil && settings.faviconCache[provider.id] == nil {
                 Task {
                      await settings.fetchFavicon(for: provider)
                  }
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(windowManager: nil) // Pass nil for preview
    }
} 