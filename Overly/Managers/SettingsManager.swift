//
//  SettingsManager.swift
//  Overly
//
//  Created by hypackel on 5/23/25.
//

import SwiftUI
import AppKit

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    private var settingsWindow: NSWindow?
    
    private init() {}
    
    func openSettings() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let contentView = SettingsWindowView()
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Overly Settings"
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        window.setFrameAutosaveName("SettingsWindow")
        window.isReleasedWhenClosed = false
        
        // Set minimum size
        window.minSize = NSSize(width: 700, height: 500)
        
        self.settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func closeSettings() {
        settingsWindow?.close()
    }
} 