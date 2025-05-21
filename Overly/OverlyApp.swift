//
//  OverlyApp.swift
//  Overly
//
//  Created by hypackel on 5/20/25.
//

import SwiftUI
import AppKit
import Combine
import HotKey

// Class to manage the window and hotkey
class WindowManager: NSObject {
    private var customWindow: NSWindow?
    private var hotKey: HotKey?

    override init() {
        super.init()
        // Create the global hotkey for Cmd + J
        hotKey = HotKey(key: .j, modifiers: [.command])
        hotKey?.keyDownHandler = { [weak self] in
            // Call the toggle window method when the hotkey is pressed
            self?.toggleCustomWindowVisibility()
        }
    }

    // Method to toggle the custom window's visibility
    func toggleCustomWindowVisibility() {
        print("toggleCustomWindowVisibility called. customWindow is currently: \(customWindow == nil ? "nil" : "not nil")")
        if customWindow == nil {
            print("customWindow is nil, creating new window.")
            // If the window hasn't been created yet, create it
            let newWindow = BorderlessWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 500), // Initial size
                styleMask: [.borderless, .resizable], // No title bar or traffic lights + resizable
                backing: .buffered,
                defer: false
            )

            newWindow.isOpaque = false // Make it non-opaque
            newWindow.backgroundColor = NSColor.clear // Clear background
            newWindow.level = .floating // Keep it floating
            newWindow.center() // Center the window initially
            newWindow.isMovableByWindowBackground = true // Allow dragging by background

            // Create an NSHostingView to wrap the SwiftUI ContentView
            let hostingView = NSHostingView(rootView: ContentView(window: newWindow))
            newWindow.contentView = hostingView // Set the SwiftUI view as the window's content

            // Store the window in the class property
            customWindow = newWindow
        }

        // Now that we are sure customWindow is not nil, toggle its visibility
        if let window = customWindow {
            let isVisible = window.isVisible
            print("customWindow is not nil. Current visibility: \(isVisible).")
            window.setIsVisible(!isVisible)

            // Always attempt to make it key and order front when showing
            if !isVisible { // If the window *was* hidden and is now visible
                print("Window was hidden, making visible and ordering front.")
                NSApp.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
            }
             else { // If the window *was* visible and is now hidden
                 print("Window was visible, hiding.")
                 // Optionally, you might want to resign key window status when hiding
                 // window.resignKey()
             }
        }
    }
}

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
        MenuBarExtra("Overly", systemImage: "globe") { // "Overly" is the text, "globe" is the icon
            Divider() // Add a separator line
            Button("Quit") {
                NSApplication.shared.terminate(nil) // Add a Quit button
            }
        }
    }
}

// A simple App Delegate to hold and manage the WindowManager
class AppDelegate: NSObject, NSApplicationDelegate {
    var windowManager: WindowManager? // Use optional to allow lazy initialization

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize the WindowManager when the application finishes launching
        windowManager = WindowManager()
    }

    // Other optional NSApplicationDelegate methods can be added here if needed
}