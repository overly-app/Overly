//
//  AppDelegate.swift
//  Overly
//
//  Created by hypackel on 5/20/25.
//

import AppKit

// A simple App Delegate to hold and manage the WindowManager
class AppDelegate: NSObject, NSApplicationDelegate {
    var windowManager: WindowManager? // Use optional to allow lazy initialization
    
    // Static method to access the WindowManager from anywhere
    static var shared: AppDelegate? {
        return NSApp.delegate as? AppDelegate
    }

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize the WindowManager when the application finishes launching
        windowManager = WindowManager()

        // Read the initial showInDock setting and set the activation policy
        if AppSettings.shared.showInDock {
            NSApp.setActivationPolicy(.regular) // Show in Dock
            // Show the window immediately on launch if showing in dock
            windowManager?.toggleCustomWindowVisibility()
        } else {
            NSApp.setActivationPolicy(.accessory) // Hide from Dock
            // When hiding the dock icon on launch, explicitly activate the application
            // so the menu bar icon is immediately available and the app is responsive.
            NSApp.activate(ignoringOtherApps: true)
            // Do NOT show the window immediately on launch if hiding from dock.
            // The user will use the hotkey to show it.
        }

        // Removed code that was setting actions from a temporary ContentView
    }

    // Other optional NSApplicationDelegate methods can be added here if needed
} 