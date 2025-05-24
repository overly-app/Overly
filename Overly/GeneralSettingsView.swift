//
//  GeneralSettingsView.swift
//  Overly
//
//  Created by hypackel on 5/23/25.
//

import SwiftUI
import AppKit
import HotKey

// Define a struct to decode the GitHub release JSON
struct GitHubRelease: Decodable {
    let name: String
    let tagName: String
    let htmlUrl: URL
    
    private enum CodingKeys: String, CodingKey {
        case name
        case tagName = "tag_name"
        case htmlUrl = "html_url"
    }
}

struct GeneralSettingsView: View {
    @ObservedObject var settings = AppSettings.shared // Use the shared settings instance
    
    // We no longer need the localShowInDock state
    // @State private var localShowInDock: Bool = false // Local state for the toggle
    
    // Access the AppStorage variable to reset onboarding
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    
    // State variables for the update check alert
    @State private var showingUpdateAlert = false
    @State private var updateMessage = ""
    @State private var updateURL: URL? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("General Settings")
                .font(.largeTitle)
            
            // Bind Toggle directly to the settings property
            Toggle("Show in Dock", isOn: $settings.showInDock)
                .onChange(of: settings.showInDock) { newValue in
                    // Explicitly set the activation policy when the toggle changes
                    if newValue {
                        NSApp.setActivationPolicy(.regular)
                    } else {
                        NSApp.setActivationPolicy(.accessory)
                        // Explicitly activate the application when hiding the dock icon
                        // This might be necessary for the change to take effect immediately.
                        NSApp.activate(ignoringOtherApps: true)
                    }
                }
            
            Divider() // Add a separator
            
            // Keybind recorder
            KeybindRecorderView(
                key: $settings.toggleHotkeyKey,
                modifiers: $settings.toggleHotkeyModifiers,
                isRecording: .constant(false)
            )
            .padding(.vertical)
            
            Divider() // Add another separator
            
            // Button to reset onboarding
            Button("Reset Onboarding") {
                hasCompletedOnboarding = false // Set the flag to false
            }
            .padding(.top)
            
            // Add the Check for Updates button
            Button("Check for Updates") {
                Task { // Use a Task to call the async function
                    await checkForUpdates()
                }
            }
            .padding(.top)
            
            // Add a Text view to display the current app version
            if let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                Text("Current Version: \(currentVersion)")
                    .font(.footnote)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading) // Align content to top leading
        // Remove the onReceive as the onChange on the Toggle is more direct
        //.onReceive(settings.objectWillChange) { _ in
        //    if settings.showInDock {
        //        NSApp.setActivationPolicy(.regular)
        //    } else {
        //        NSApp.setActivationPolicy(.accessory)
        //    }
        //}
        .onAppear {
            // Set the initial policy on appear
             if settings.showInDock {
                 NSApp.setActivationPolicy(.regular)
             } else {
                 NSApp.setActivationPolicy(.accessory)
             }
        }
        // Add the alert modifier
        .alert(isPresented: $showingUpdateAlert) {
            if let url = updateURL {
                Alert(
                    title: Text("Update Available"),
                    message: Text(updateMessage),
                    primaryButton: .default(Text("Download Update")) {
                        // Open the release page in the browser
                        NSWorkspace.shared.open(url)
                    },
                    secondaryButton: .cancel()
                )
            } else {
                Alert(
                    title: Text("Check for Updates"),
                    message: Text(updateMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    // Function to check for updates
    private func checkForUpdates() async {
        guard let url = URL(string: "https://api.github.com/repos/hypackel/Overly/releases/latest") else {
            updateMessage = "Invalid update URL."
            updateURL = nil
            showingUpdateAlert = true
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            let release = try decoder.decode(GitHubRelease.self, from: data)
            
            // Get the current app version
            guard let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
                updateMessage = "Could not determine current app version."
                updateURL = nil
                showingUpdateAlert = true
                return
            }
            
            // Simple version comparison (assumes semantic versioning where string comparison works)
            // A more robust comparison would parse version components.
            // Replace simple string comparison with robust version comparison
            if compareVersions(release.tagName, currentVersion) == .orderedDescending {
                // Newer version available
                updateMessage = "Version \(release.name) (\(release.tagName)) is available."
                updateURL = release.htmlUrl
            } else {
                // App is up to date
                updateMessage = "Your app is up to date (Version \(currentVersion))."
                updateURL = nil
            }
            
        } catch {
            // Handle errors during fetch or decode
            updateMessage = "Failed to check for updates: \(error.localizedDescription)"
            updateURL = nil
        }
        
        showingUpdateAlert = true // Show the alert after the check
    }
    
    // Helper function for robust semantic version comparison
    private func compareVersions(_ version1: String, _ version2: String) -> ComparisonResult {
        // Remove leading 'v' if present and split by '.'
        let components1 = version1.trimmingCharacters(in: CharacterSet(charactersIn: "vV")).split(separator: ".").map { Int($0) ?? 0 }
        let components2 = version2.trimmingCharacters(in: CharacterSet(charactersIn: "vV")).split(separator: ".").map { Int($0) ?? 0 }
        
        let count = max(components1.count, components2.count)
        
        for i in 0..<count {
            let v1 = i < components1.count ? components1[i] : 0
            let v2 = i < components2.count ? components2[i] : 0
            
            if v1 < v2 {
                return .orderedAscending
            } else if v1 > v2 {
                return .orderedDescending
            }
        }
        
        return .orderedSame // Versions are equal
    }
}

#Preview {
    GeneralSettingsView()
} 
