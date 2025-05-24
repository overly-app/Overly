//
//  GeneralSettingsView.swift
//  Overly
//
//  Created by hypackel on 5/23/25.
//

import SwiftUI
import AppKit
import HotKey
import SettingsKit // Import SettingsKit

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

// NSViewRepresentable to bridge AppKit's SettingsTableView to SwiftUI
struct SettingsTableViewRepresentable: NSViewRepresentable {
    @Binding var showInDock: Bool
    @Binding var toggleHotkeyKey: Key
    @Binding var toggleHotkeyModifiers: NSEvent.ModifierFlags
    @Binding var hasCompletedOnboarding: Bool
    var checkForUpdatesAction: () -> Void
    var currentVersion: String?

    func makeNSView(context: Context) -> SettingsTableView {
        let settingsView = SettingsTableView()
        settingsView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add Show in Dock row
        let dockToggle = NSSwitch()
        dockToggle.state = showInDock ? .on : .off
        dockToggle.target = context.coordinator
        dockToggle.action = #selector(Coordinator.toggleShowInDock(_:))
        dockToggle.tag = 1001
        settingsView.addRow(labelText: "Show in Dock:", control: dockToggle)

        // Add Hotkey row - Using a text field as integrating the custom SwiftUI KeybindRecorderView here is complex
        let hotkeyLabel = NSTextField(labelWithString: "Press hotkey to record") // Placeholder
         hotkeyLabel.translatesAutoresizingMaskIntoConstraints = false
        // You would need a more complex setup to integrate a real Hotkey recorder in AppKit
        // For now, we'll just display a placeholder or the current hotkey string.
        let currentHotkeyDisplay = NSTextField(labelWithString: "Current Hotkey: \(toggleHotkeyModifiers)\(toggleHotkeyKey.description)")
        currentHotkeyDisplay.isEditable = false
        currentHotkeyDisplay.isSelectable = false
        currentHotkeyDisplay.backgroundColor = .clear
        currentHotkeyDisplay.drawsBackground = false
        currentHotkeyDisplay.bezelStyle = .roundedBezel
        currentHotkeyDisplay.isBordered = false
        currentHotkeyDisplay.tag = 1002
        settingsView.addRow(labelText: "Toggle Hotkey:", control: currentHotkeyDisplay)

        // Add Reset Onboarding row
        let resetButton = NSButton(title: "Reset Onboarding", target: context.coordinator, action: #selector(Coordinator.resetOnboarding))
        resetButton.tag = 1003
        settingsView.addRow(labelText: "", control: resetButton) // No label for button row

        // Add Check for Updates row
        let updateButton = NSButton(title: "Check for Updates", target: context.coordinator, action: #selector(Coordinator.checkForUpdates))
        updateButton.tag = 1004
        settingsView.addRow(labelText: "", control: updateButton) // No label for button row

        // Add Current Version row
        if let version = currentVersion {
            let versionLabel = NSTextField(labelWithString: "Current Version: \(version)")
            versionLabel.isEditable = false
            versionLabel.isSelectable = false
             versionLabel.backgroundColor = .clear
            versionLabel.drawsBackground = false
            versionLabel.bezelStyle = .roundedBezel
            versionLabel.isBordered = false
            versionLabel.tag = 1005
            settingsView.addRow(labelText: "", control: versionLabel) // No label for this info row
        }
        
        // Add a spacer to push content to the top (already handled in SettingsTableView but ensuring here)
         let spacer = NSView()
         settingsView.stackView.addArrangedSubview(spacer)
         settingsView.stackView.setViews([spacer], in: .bottom)
         spacer.setContentHuggingPriority(.defaultLow, for: .vertical)

        return settingsView
    }

    func updateNSView(_ nsView: SettingsTableView, context: Context) {
        // Update the state of the controls based on SwiftUI state changes
        // This part is more involved for bidirectional binding. For simplicity,
        // we handle AppKit to SwiftUI updates via the Coordinator.
        // SwiftUI to AppKit updates would require finding the specific control
        // in the NSView hierarchy and updating its state.
        // For the dock toggle:
         if let dockToggle = nsView.stackView.viewWithTag(1001) as? NSSwitch {
             dockToggle.state = showInDock ? .on : .off
         }

        // For the hotkey display (update the text)
        // Find the NSTextField displaying the hotkey
        if let hotkeyDisplayLabel = nsView.stackView.viewWithTag(1002) as? NSTextField {
            hotkeyDisplayLabel.stringValue = "Current Hotkey: \(toggleHotkeyModifiers)\(toggleHotkeyKey.description)"
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: SettingsTableViewRepresentable

        init(_ parent: SettingsTableViewRepresentable) {
            self.parent = parent
        }

        @objc func toggleShowInDock(_ sender: NSSwitch) {
            parent.showInDock = sender.state == .on
            // Explicitly set the activation policy when the toggle changes
             if parent.showInDock {
                 NSApp.setActivationPolicy(.regular)
             } else {
                 NSApp.setActivationPolicy(.accessory)
                 // Explicitly activate the application when hiding the dock icon
                 // This might be necessary for the change to take effect immediately.
                 NSApp.activate(ignoringOtherApps: true)
             }
        }

        @objc func resetOnboarding() {
            parent.hasCompletedOnboarding = false
        }

        @objc func checkForUpdates() {
            parent.checkForUpdatesAction()
        }
    }
}

struct GeneralSettingsView: View {
    @ObservedObject var settings = AppSettings.shared // Use the shared settings instance
    
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    
    // State variables for the update check alert
    @State private var showingUpdateAlert = false
    @State private var updateMessage = ""
    @State private var updateURL: URL? = nil
    
    var body: some View {
        Form { // Use a standard SwiftUI Form
            Section(header: Text("General")) { // Use a standard SwiftUI Section
                // Show in Dock Toggle
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

                // Hotkey Display (SettingsKit doesn't have a direct KeybindRecorder, display current)
                HStack {
                    Text("Toggle Hotkey:")
                    Spacer()
                    Text("\(settings.toggleHotkeyModifiers)\(settings.toggleHotkeyKey.description)") // Display current hotkey
                }
                // Note: Integrating a full KeybindRecorderView here would require custom implementation

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
