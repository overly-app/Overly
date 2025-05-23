import SwiftUI
import Foundation // Import Foundation for URL

// Custom button style to ensure proper color handling
struct OnboardingButtonStyleServiceSelection: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(colorScheme == .dark ? Color.white : Color.black)
            .foregroundColor(colorScheme == .dark ? Color.black : Color.white)
            .cornerRadius(8)
    }
}

// Custom view for the provider chip design
struct ProviderChipView: View {
    @Environment(\.colorScheme) var colorScheme
    let provider: ChatProvider
    @ObservedObject var settings: AppSettings
    let onDelete: (String) -> Void // Action to perform when deleting a custom provider

    var isSelected: Bool {
        settings.activeProviderIds.contains(provider.id)
    }

    var body: some View {
        Button(action: {
            settings.toggleActiveProvider(id: provider.id)
        }) {
            HStack {
                ServiceIconView(provider: provider, settings: settings)
                Text(provider.name)
                    .foregroundColor(isSelected ? (colorScheme == .dark ? .black : .white) : .primary)
                    .fontWeight(isSelected ? .bold : .regular)

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
            .contentShape(RoundedRectangle(cornerRadius: 16)) // Make the whole chip tappable
        }
        .buttonStyle(.plain) // Use plain button style to avoid default button appearance
        .contextMenu { // Add context menu for deletion, only for custom providers
            if settings.customProviders.contains(where: { $0.id == provider.id }) {
                Button("Delete", role: .destructive) {
                    onDelete(provider.id)
                }
            }
        }
        .onAppear { // Add onAppear to fetch favicon when the view appears
            if provider.url != nil && settings.faviconCache[provider.id] == nil {
                Task {
                    await settings.fetchFavicon(for: provider)
                }
            }
        }
    }
}

struct ServiceSelectionView: View {
    // Add a binding or action to dismiss this view and proceed
    let onCompletion: () -> Void

    @ObservedObject var settings = AppSettings.shared // Observe AppSettings

    @State private var newCustomProviderName: String = ""
    @State private var newCustomProviderURLString: String = ""

    var body: some View {
        VStack {
            Text("Select Your Providers")
                .font(.largeTitle)
                .padding(.top) // Add top padding

            // Section for Built-in Providers
            VStack(alignment: .leading) {
                Text("Providers")
                    .font(.headline)
                    .padding(.leading)

                ScrollView(.horizontal, showsIndicators: false) { // Use ScrollView for horizontal scrolling
                    HStack {
                        // Show all built-in providers except 'Settings'
                        ForEach(settings.allBuiltInProviders.filter { $0.url != nil }) { provider in
                            ProviderChipView(provider: provider, settings: settings, onDelete: deleteCustomProvider) // Use the new chip view
                        }
                    }
                    .padding(.horizontal) // Add horizontal padding to the HStack inside the ScrollView
                }
                .frame(height: 60) // Give the ScrollView a fixed height
            }
            // No padding bottom here, let the divider handle spacing

            Divider() // Add a divider between sections
                .padding(.vertical, 20) // Adjusted padding

            // Section for Custom Providers
            VStack(alignment: .leading) {
                Text("Custom Providers")
                    .font(.headline)
                    .padding(.leading)

                ScrollView(.horizontal, showsIndicators: false) { // Use ScrollView for horizontal scrolling
                    HStack {
                        // Show Custom Providers
                        ForEach(settings.customProviders) { provider in
                            ProviderChipView(provider: provider, settings: settings, onDelete: deleteCustomProvider) // Use the new chip view
                        }
                    }
                    .padding(.horizontal) // Add horizontal padding to the HStack inside the ScrollView
                }
                .frame(height: 60) // Give the ScrollView a fixed height
            }
            .padding(.bottom) // Add padding bottom after the custom providers section

            // Section for Add Custom Provider
            VStack(alignment: .leading) {
                Text("Add Custom Provider")
                    .font(.headline)
                    .padding(.leading)

                HStack {
                    TextField("Provider Name", text: $newCustomProviderName)
                        .textFieldStyle(.roundedBorder)
                    TextField("Provider URL", text: $newCustomProviderURLString)
                        .textFieldStyle(.roundedBorder)
                    Button("Add") {
                        // Add action to add custom provider
                        if !newCustomProviderName.isEmpty && !newCustomProviderURLString.isEmpty {
                            // Add https:// if missing
                            var urlString = newCustomProviderURLString
                            if !urlString.contains("://") {
                                urlString = "https://" + urlString
                            }

                            if let url = URL(string: urlString) {
                                let newProvider = ChatProvider(
                                    id: UUID().uuidString, // Generate a unique ID
                                    name: newCustomProviderName,
                                    url: url,
                                    iconName: "link", // Default icon for custom providers
                                    isSystemImage: true // Treat custom providers as system images for simplicity for now
                                )
                                settings.addCustomProvider(newProvider) // Add and make active
                                
                                // Fetch favicon for the new provider
                                Task { // Use a Task to call the async function
                                    await settings.fetchFavicon(for: newProvider)
                                }

                                // Clear text fields after adding
                                newCustomProviderName = ""
                                newCustomProviderURLString = ""
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
            }
            .padding(.bottom) // Add padding after the add custom provider section

            Spacer() // Pushes content to the top

            Button("Finish Setup") {
                // Save settings and call the completion action
                settings.saveSettings() // Ensure latest changes are saved
                onCompletion()
            }
            .padding()
            .buttonStyle(OnboardingButtonStyleServiceSelection()) // Apply the custom button style

            // No longer need Spacer() here because content is pushed by the one above
            // Spacer() // Pushes content to the bottom
        }
        .padding()
        .frame(width: 800, height: 500) // Match the onboarding window size
    }

    // Function to handle deleting custom providers by ID
    func deleteCustomProvider(id: String) {
        settings.customProviders.removeAll { $0.id == id }
        settings.activeProviderIds.remove(id)
        settings.faviconCache.removeValue(forKey: id)
        settings.saveSettings()
    }
}

// Helper view to display service icons based on type and cache
struct ServiceIconView: View {
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
                          // Attempt to fetch favicon if it's a custom provider without a cached icon
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

#Preview {
    ServiceSelectionView(onCompletion: { // Dummy action for preview
        print("Service Selection Finished!")
    })
} 