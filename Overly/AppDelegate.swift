//
//  AppDelegate.swift
//  Overly
//
//  Created by hypackel on 5/20/25.
//

import AppKit

// A simple App Delegate to hold and manage the WindowManager
class AppDelegate: NSObject, NSApplicationDelegate {
    var windowManager: WindowManager? {
        return WindowManager.shared
    }
    
    // Static method to access the WindowManager from anywhere
    static var shared: AppDelegate? {
        return NSApp.delegate as? AppDelegate
    }

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Use the shared WindowManager instance
        let windowManager = WindowManager.shared

        // Ensure AppSettings is fully loaded and UserDefaults is synchronized
        _ = AppSettings.shared
        UserDefaults.standard.synchronize() // Force synchronization
        
        // Check the showInDock setting directly from UserDefaults for immediate access
        let showInDock = UserDefaults.standard.object(forKey: "showInDock") as? Bool ?? true
        
        // Set the activation policy immediately based on the setting
        if showInDock {
            NSApp.setActivationPolicy(.regular) // Show in Dock
            print("AppDelegate: Setting activation policy to .regular (show in dock)")
        } else {
            NSApp.setActivationPolicy(.accessory) // Hide from Dock
            print("AppDelegate: Setting activation policy to .accessory (hide from dock)")
        }
        
        // Add a small delay to ensure settings are fully processed before other setup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if showInDock {
                // Show the window immediately on launch if showing in dock
                windowManager.toggleCustomWindowVisibility()
            } else {
                // When hiding the dock icon on launch, explicitly activate the application
                // so the menu bar icon is immediately available and the app is responsive.
                NSApp.activate(ignoringOtherApps: true)
                // Do NOT show the window immediately on launch if hiding from dock.
                // The user will use the hotkey to show it.
            }
        }

        // Removed code that was setting actions from a temporary ContentView
    }

    // Other optional NSApplicationDelegate methods can be added here if needed
} 