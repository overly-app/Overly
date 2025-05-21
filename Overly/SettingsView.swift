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

    var body: some View {
        VStack(alignment: .leading) {
            Text("Settings")
                .font(.largeTitle)
                .padding(.bottom)

            Toggle("Show in Dock", isOn: $settings.showInDock) // Bind to the settings property
                .padding(.bottom)
                .onChange(of: settings.showInDock) { newValue in
                    // Update the application's activation policy
                    if newValue {
                        // Show in Dock
                        NSApp.setActivationPolicy(.regular)
                    } else {
                        // Hide from Dock
                        NSApp.setActivationPolicy(.accessory)
                    }
                }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Expand to fill the window
    }
}

// Create a simple ObservableObject for settings
class AppSettings: ObservableObject {
    static let shared = AppSettings() // Singleton instance
    
    @Published var showInDock: Bool = UserDefaults.standard.bool(forKey: "showInDock") {
        didSet {
            // Save the setting to UserDefaults whenever it changes
            UserDefaults.standard.set(showInDock, forKey: "showInDock")
            // When the app launches, set the initial activation policy based on the saved setting
            if showInDock {
                NSApp.setActivationPolicy(.regular)
            } else {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
    
    // Private initializer to prevent creating multiple instances
    private init() {
        // Set the initial activation policy when the settings are initialized
        if showInDock {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(windowManager: nil) // Pass nil for preview
    }
} 