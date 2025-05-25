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
    
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    
    // State variables for the update check alert
    @State private var showingUpdateAlert = false
    @State private var updateMessage = ""
    @State private var updateURL: URL? = nil
    
    // State for hotkey recording
    @State private var isRecordingHotkey = false
    
    var body: some View {
        Form { // Use a standard SwiftUI Form
            Section(header: Text("General")) { // Use a standard SwiftUI Section
                // Show in Dock Toggle
                Toggle("Show in Dock", isOn: $settings.showInDock)
                    .onChange(of: settings.showInDock) { _, newValue in
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

                // Interactive Hotkey Recorder
                HStack {
                    KeybindRecorderView(
                        key: $settings.toggleHotkeyKey,
                        modifiers: $settings.toggleHotkeyModifiers,
                        isRecording: $isRecordingHotkey,
                        showLabel: true
                    )
                    
                    Button(isRecordingHotkey ? "Cancel" : "Change") {
                        isRecordingHotkey.toggle()
                    }
                    .foregroundColor(isRecordingHotkey ? .red : .blue)
                }

                // Reset Onboarding Button
                Button("Reset Onboarding") {
                    hasCompletedOnboarding = false
                }

                // Check for Updates Button
                Button("Check for Updates") {
                    Task { // Use a Task to call the async function
                        await checkForUpdates()
                    }
                }

                // Current Version Display
                if let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                    HStack {
                        Text("Current Version:")
                        Spacer()
                        Text("\(currentVersion)")
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
            } else if v1 < v2 {
                return .orderedAscending
            }
        }
        
        return .orderedSame // Versions are equal
    }
}

#Preview {
    GeneralSettingsView()
} 
