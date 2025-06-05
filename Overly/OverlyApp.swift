//
//  OverlyApp.swift
//  Overly
//
//  Created by hypackel on 5/20/25.
//

import SwiftUI
import SettingsKit

@main
struct OverlyApp: App {
    // Keep a reference to the WindowManager instance
    // Use @NSApplicationDelegateAdaptor to manage the lifecycle of the manager
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate // We might need a simple App Delegate to hold the WindowManager

    var body: some Scene {
        // A minimal WindowGroup just to satisfy macOS app structure requirements.
        // The main UI is in the custom borderless window managed by the WindowManager.
//         WindowGroup {
//           // This content is not intended to be the primary visible UI.
//           // We can leave it minimal or empty.
//            Text("Placeholder Window - Use Menu Bar")
//                .frame(width: 1, height: 1) // Make it very small, might help keep it from showing prominently
//                .hidden() // Attempt to hide this placeholder view
//         }

        // Define the menu bar extra
        MenuBarExtra {
            Button("Toggle Window") {
                WindowManager.shared.toggleCustomWindowVisibility()
            }
            
            Divider()
            
            SettingsLink {
                HStack {
                    Text("Settings")
                }
            }
            
            Button("Check for Updates") {
                // TODO: Implement update checking functionality
                if let url = URL(string: "https://github.com/overly-app/Overly") {
                    NSWorkspace.shared.open(url)
                }
            }
            
            Divider() // Add a separator line
            
            Button("Quit") {
                NSApplication.shared.terminate(nil) // Add a Quit button
            }
            .keyboardShortcut("q", modifiers: .command)
        } label: {
            // Custom label view - menu bar icon that will render in white
            Image("MenuBarIcon")
                .renderingMode(.template)
                .frame(width: 18, height: 18)
        }
        .settings(design: .sidebar) {
            SettingsTab(.new(title: "General", image: .init(systemName: "gearshape")), id: "general", color: .gray) {
                SettingsSubtab(.noSelection, id: "general") { 
                    GeneralSettingsView()
                        .frame(width: 500)
                        .fixedSize()
                        .padding()
                }
            }
            .frame()
            
            SettingsTab(.new(title: "Providers", image: .init(systemName: "puzzlepiece")), id: "providers", color: .blue) {
                SettingsSubtab(.noSelection, id: "providers") { 
                    ProviderSettingsView()
                        .frame(width: 500)
                        .fixedSize()
                        .padding()
                }
            }
            .frame()
        }
    }
}