//
//  OverlyApp.swift
//  Overly
//
//  Created by hypackel on 5/20/25.
//

import SwiftUI
import AppKit
import Combine // Keep Combine for ObservableObject if needed elsewhere, or remove if not.
import HotKey // Import HotKey

@main
struct OverlyApp: App {
    // State to manage the custom window and its visibility
    @State private var customWindow: NSWindow?
    @State private var shouldLoadWebView: Bool = false // State to signal web view load

    // Property to hold the global hotkey
    private var hotKey: HotKey? // Add hotKey property

    init() {
        // Create the global hotkey for Cmd + J
        hotKey = HotKey(key: .j, modifiers: [.command])
        hotKey?.keyDownHandler = { [self] in
            // Call the toggle window method when the hotkey is pressed
            toggleCustomWindowVisibility()
        }
    }

    // Method to toggle the custom window's visibility
    private func toggleCustomWindowVisibility() {
         if let window = customWindow {
            let isVisible = window.isVisible
            window.setIsVisible(!isVisible)
            if !isVisible { // If making the window visible
                // Bring the app to the front and order the window when showing
                NSApp.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
            }
        } else {
            // If the window hasn't been created yet, create it
            let newWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 500), // Initial size
                styleMask: [.borderless, .resizable], // No title bar or traffic lights + resizable
                backing: .buffered,
                defer: false
            )

            newWindow.isOpaque = false // Make it non-opaque
            newWindow.backgroundColor = NSColor.clear // Clear background
            newWindow.level = .floating // Keep it floating
            newWindow.center() // Center the window initially

            // Create an NSHostingView to wrap the SwiftUI ContentView
            // Pass a binding to the state variable to ContentView
            let hostingView = NSHostingView(rootView: ContentView(shouldLoad: $shouldLoadWebView))
            newWindow.contentView = hostingView // Set the SwiftUI view as the window's content

            newWindow.setIsVisible(true) // Show the new window

            // Bring the app to the front and order the window when showing
            NSApp.activate(ignoringOtherApps: true)
            newWindow.makeKeyAndOrderFront(nil)

            // Store the window in the state variable
            customWindow = newWindow
        }
    }

    var body: some Scene {
        // A minimal WindowGroup just to satisfy macOS app structure requirements.
        // The main UI is in the custom borderless window managed by this App struct.
//         WindowGroup {
//           // This content is not intended to be the primary visible UI.
//           // We can leave it minimal or empty.
//            Text("Placeholder Window - Use Menu Bar")
//                .frame(width: 1, height: 1) // Make it very small, might help keep it from showing prominently
//                .hidden() // Attempt to hide this placeholder view
//         }

        // Define the menu bar extra
        MenuBarExtra("Overly", systemImage: "globe") { // "Overly" is the text, "globe" is the icon
            Divider() // Add a separator line
            Button("Quit") {
                NSApplication.shared.terminate(nil) // Add a Quit button
            }
        }
    }
}