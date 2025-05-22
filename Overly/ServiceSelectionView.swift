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
                Text("Default Providers")
                    .font(.headline)
                    .padding(.leading)

                List {
                    // Show all built-in providers except 'Settings'
                    ForEach(settings.allBuiltInProviders.filter { $0.url != nil }) {
                        provider in
                        Toggle(isOn: Binding( // Use Binding to allow toggling Set<String>
                            get: { settings.activeProviderIds.contains(provider.id) },
                            set: { isActive in
                                settings.toggleActiveProvider(id: provider.id)
                            }
                        )) {
                            HStack {
                                // Display icon - consolidated logic
                                ServiceIconView(provider: provider, settings: settings)
                                Text(provider.name)
                            }
                        }
                    }
                    
                    // Show Custom Providers
                    Section(header: Text("Custom Providers")) { // Add Section header
                        ForEach(settings.customProviders) {
                            provider in
                            Toggle(isOn: Binding( // Use Binding to allow toggling Set<String>
                                get: { settings.activeProviderIds.contains(provider.id) },
                                set: { isActive in
                                    settings.toggleActiveProvider(id: provider.id)
                                }
                            )) {
                                HStack {
                                    // Display icon - consolidated logic
                                    ServiceIconView(provider: provider, settings: settings)
                                    Text(provider.name)

                                    Spacer() // Push the minus button to the right

                                    // Minus button to delete custom provider
                                    Button(action: {
                                        deleteCustomProvider(id: provider.id) // Call delete function with provider ID
                                    }) {
                                        Image(systemName: "minus.circle")
                                            .foregroundColor(.red) // Make the minus button red
                                    }
                                    .buttonStyle(.plain) // Use plain button style
                                }
                                .contextMenu { // Add context menu for deletion
                                    Button("Delete", role: .destructive) {
                                        deleteCustomProvider(id: provider.id) // Call delete function with provider ID
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(height: 200) // Give the list a fixed height for now
            }
            .padding(.horizontal)

            Divider() // Add a divider between sections
                .padding(.vertical, 30) // Increase vertical padding for bigger separation

            // Section for Custom Providers
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

                // We are now showing custom providers in the main list
                // This separate list is commented out
                // List of Custom Services (Optional - could add later)
                // List {
                //     ForEach(settings.customProviders) { provider in
                //         Text(provider.name)
                //     }
                // }
            }
            .padding(.bottom)

            Spacer() // Pushes content to the top

            Button("Finish Setup") {
                // Save settings and call the completion action
                settings.saveProviders() // Ensure latest changes are saved
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

    // Function to handle deleting custom providers
    func deleteCustomProvider(at offsets: IndexSet) {
        settings.customProviders.remove(atOffsets: offsets)
        // Also remove the corresponding IDs from activeProviderIds
        for index in offsets {
            let providerId = settings.customProviders[index].id // Get the ID BEFORE removal
            settings.activeProviderIds.remove(providerId)
             // Remove favicon data for the deleted provider
             settings.faviconCache.removeValue(forKey: providerId)
        }
        settings.saveProviders()
    }

    // Function to handle deleting a custom provider by ID
    func deleteCustomProvider(id: String) {
        settings.customProviders.removeAll { $0.id == id }
        settings.activeProviderIds.remove(id)
        settings.faviconCache.removeValue(forKey: id)
        settings.saveProviders()
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