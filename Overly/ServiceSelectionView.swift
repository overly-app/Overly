import SwiftUI

struct ServiceSelectionView: View {
    // Add a binding or action to dismiss this view and proceed
    let onCompletion: () -> Void

    @ObservedObject var settings = AppSettings.shared // Observe AppSettings

    @State private var newCustomProviderName: String = ""
    @State private var newCustomProviderURLString: String = ""

    var body: some View {
        VStack {
            Text("Select Your Services")
                .font(.largeTitle)
                .padding(.bottom)
                .padding(.top)

            // Section for Built-in Services
            VStack(alignment: .leading) {
                Text("Default Services")
                    .font(.headline)
                    .padding(.leading)

                List {
                    ForEach(settings.allBuiltInProviders) {
                        provider in
                        Toggle(isOn: Binding( // Use Binding to allow toggling Set<String>
                            get: { settings.activeProviderIds.contains(provider.id) },
                            set: { isActive in
                                settings.toggleActiveProvider(id: provider.id)
                            }
                        )) {
                            HStack {
                                // Display icon
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
                                }
                                Text(provider.name)
                            }
                        }
                        .disabled(provider.url == nil) // Disable toggle for providers without a URL (like Settings)
                    }
                }
                .frame(height: 200) // Give the list a fixed height for now
            }
            .padding(.horizontal)

            // Section for Custom Services
            VStack(alignment: .leading) {
                Text("Add Custom Service")
                    .font(.headline)
                    .padding(.leading)

                HStack {
                    TextField("Service Name", text: $newCustomProviderName)
                        .textFieldStyle(.roundedBorder)
                    TextField("Service URL", text: $newCustomProviderURLString)
                        .textFieldStyle(.roundedBorder)
                    Button("Add") {
                        // Add action to add custom provider
                        if !newCustomProviderName.isEmpty && !newCustomProviderURLString.isEmpty,
                           let url = URL(string: newCustomProviderURLString) {
                            let newProvider = ChatProvider(
                                id: UUID().uuidString, // Generate a unique ID
                                name: newCustomProviderName,
                                url: url,
                                iconName: "link", // Default icon for custom services
                                isSystemImage: true // Treat custom services as system images for simplicity for now
                            )
                            settings.addCustomProvider(newProvider)
                            // Clear text fields after adding
                            newCustomProviderName = ""
                            newCustomProviderURLString = ""
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)

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
            .buttonStyle(.borderedProminent)

            Spacer() // Pushes content to the bottom
        }
        .padding()
        .frame(width: 700, height: 400) // Match the onboarding window size
    }
}

#Preview {
    ServiceSelectionView(onCompletion: { // Dummy action for preview
        print("Service Selection Finished!")
    })
} 