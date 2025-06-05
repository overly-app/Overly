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
    @ObservedObject var settings = AppSettings.shared
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    
    // State variables for the update check alert
    @State private var showingUpdateAlert = false
    @State private var updateMessage = ""
    @State private var updateURL: URL? = nil
    
    // State for hotkey recording
    @State private var isRecordingHotkey = false
    
    var body: some View {
        Form {
            // System Features Section
            Section {
                Toggle("Show in Dock", isOn: $settings.showInDock)
                    .onChange(of: settings.showInDock) { _, newValue in
                        if newValue {
                            NSApp.setActivationPolicy(.regular)
                        } else {
                            NSApp.setActivationPolicy(.accessory)
                            NSApp.activate(ignoringOtherApps: true)
                        }
                        settings.saveSettings()
                    }
            } header: {
                Text("System Features")
            }
            
            // Hotkey Configuration Section
            Section {
                HStack {
                    Text("Toggle Hotkey")
                    Spacer()
                    KeybindRecorderView(
                        key: $settings.toggleHotkeyKey,
                        modifiers: $settings.toggleHotkeyModifiers,
                        isRecording: $isRecordingHotkey,
                        showLabel: false
                    )
                    .frame(width: 120)
                    
                    Button(isRecordingHotkey ? "Cancel" : "Change") {
                        isRecordingHotkey.toggle()
                    }
                    .controlSize(.small)
                    .foregroundColor(isRecordingHotkey ? .red : .accentColor)
                }
            } header: {
                Text("Keyboard Shortcuts")
            } footer: {
                Text("Set a global hotkey to quickly toggle the Overly window")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // App Information Section
            Section {
                HStack {
                    Text("Current Version")
                    Spacer()
                    if let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                        Text(currentVersion)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Unknown")
                            .foregroundColor(.secondary)
                    }
                }
                
                Button("Check for Updates") {
                    Task {
                        await checkForUpdates()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Button("Reset Onboarding") {
                    hasCompletedOnboarding = false
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } header: {
                Text("App Information")
            }
            
            // About Section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image("MenuBarIcon")
                            .resizable()
                            .frame(width: 32, height: 32)
                        VStack(alignment: .leading) {
                            Text("Overly")
                                .font(.headline)
                            Text("AI Chat Interface for macOS")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    
                    Text("A beautiful, native macOS application for seamless AI conversations with multiple providers.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .padding(.vertical, 4)
                
                Button("Visit GitHub Repository") {
                    if let url = URL(string: "https://github.com/hypackel/Overly") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } header: {
                Text("About")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .alert(isPresented: $showingUpdateAlert) {
            if let url = updateURL {
                Alert(
                    title: Text("Update Available"),
                    message: Text(updateMessage),
                    primaryButton: .default(Text("Download Update")) {
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
            
            guard let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
                updateMessage = "Could not determine current app version."
                updateURL = nil
                showingUpdateAlert = true
                return
            }
            
            if compareVersions(release.tagName, currentVersion) == .orderedDescending {
                updateMessage = "Version \(release.name) (\(release.tagName)) is available."
                updateURL = release.htmlUrl
            } else {
                updateMessage = "Your app is up to date (Version \(currentVersion))."
                updateURL = nil
            }
            
        } catch {
            updateMessage = "Failed to check for updates: \(error.localizedDescription)"
            updateURL = nil
        }
        
        showingUpdateAlert = true
    }
    
    // Helper function for robust semantic version comparison
    private func compareVersions(_ version1: String, _ version2: String) -> ComparisonResult {
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
        
        return .orderedSame
    }
}

#Preview {
    GeneralSettingsView()
} 
