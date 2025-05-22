//
//  ProviderSettingsView.swift
//  Overly
//
//  Created by hypackel on 5/23/25.
//

import SwiftUI

// Extracted view for a single provider row
struct ProviderRowView: View {
    @ObservedObject var settings: AppSettings // Observe AppSettings
    let provider: ChatProvider

    var body: some View {
        HStack {
            // Display icon: Try favicon, then system image, then asset
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
                    Image(provider.iconName) // Assuming iconName is a valid asset or placeholder
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                }
            }
            .onAppear {
                // Attempt to fetch favicon if it's a web provider without a cached icon
                if provider.url != nil && settings.faviconCache[provider.id] == nil {
                    Task {
                        await settings.fetchFavicon(for: provider)
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

// Extracted view for adding a new provider
struct AddProviderView: View {
    @ObservedObject var settings: AppSettings
    @Binding var newProviderName: String
    @Binding var newProviderURLString: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add Custom Provider")
                .font(.headline)

            TextField("Name", text: $newProviderName)
            TextField("URL", text: $newProviderURLString)

            Button("Add Provider") {
                if !newProviderName.isEmpty && !newProviderURLString.isEmpty {
                    var urlString = newProviderURLString
                    // Prepend https:// if no scheme is present
                    if !urlString.lowercased().hasPrefix("http://") && !urlString.lowercased().hasPrefix("https://") {
                        urlString = "https://" + urlString
                    }

                    if let url = URL(string: urlString) {
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
                    } else {
                         // Optionally, show an alert to the user that the URL is invalid
                         print("Invalid URL entered: \(newProviderURLString)")
                    }
                }
            }
            .disabled(newProviderName.isEmpty || newProviderURLString.isEmpty)
        }
    }
}

struct ProviderSettingsView: View {
     @ObservedObject var settings = AppSettings.shared // Use the shared settings instance

     @State private var newProviderName: String = ""
     @State private var newProviderURLString: String = ""

     // Computed property for the list of all providers to simplify the ForEach
     private var allProviders: [ChatProvider] {
         settings.allBuiltInProviders + settings.customProviders
     }

     var body: some View {
         VStack(alignment: .leading, spacing: 20) {
             Text("Provider Settings")
                 .font(.largeTitle)

             // Section for managing providers
             ScrollView {
                 VStack(alignment: .leading, spacing: 10) {
                     Text("Manage Providers")
                         .font(.headline)

                     // List of all providers (built-in and custom)
                     ForEach(allProviders) {
                         provider in
                         ProviderRowView(settings: settings, provider: provider) // Use the extracted view
                     }
                 }
             }

             Divider()

             // Section for adding custom providers
             AddProviderView(settings: settings, newProviderName: $newProviderName, newProviderURLString: $newProviderURLString) // Use the extracted view

             Spacer()
         }
         .padding()
         .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading) // Align content to top leading
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

#Preview {
    ProviderSettingsView()
}