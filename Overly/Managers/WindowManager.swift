//
//  WindowManager.swift
//  Overly
//
//  Created by hypackel on 5/20/25.
//

import SwiftUI
import AppKit
import Combine
import HotKey

// Class to manage the window and hotkey
class WindowManager: NSObject, ObservableObject {
    static let shared = WindowManager()
    
    private var customWindow: BorderlessWindow? // Use BorderlessWindow type
    private var hotKey: HotKey?
    private var reloadHotKey: HotKey?
    private var nextServiceHotKey: HotKey?
    private var settingsHotKey: HotKey?
    private var isHotkeyDisabled = false // Track if hotkey is intentionally disabled

    // Closures to trigger actions on the visible ContentView
    // These closures will be set by the visible ContentView instance
    private var reloadWebViewAction: (() -> Void)?
    private var switchToNextServiceAction: (() -> Void)?

    override init() {
        super.init()
        // Set up the toggle hotkey from settings
        Task { @MainActor in
            setupToggleHotkey()
        }
        
        // Listen for hotkey changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hotkeySettingsChanged),
            name: NSNotification.Name("HotkeySettingsChanged"),
            object: nil
        )
        
        // Listen for new windows opening (like settings window)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )

        // Don't create the hotkeys immediately - they'll be created when window becomes visible
        
        // Create a global hotkey for Cmd + , (settings shortcut)
        settingsHotKey = HotKey(key: .comma, modifiers: [.command])
        settingsHotKey?.keyDownHandler = { [weak self] in
            // Hide the floating window when Cmd+, is pressed (settings shortcut)
            self?.hideCustomWindow()
        }
    }
    
    // Method to set up the toggle hotkey from settings
    @MainActor
    private func setupToggleHotkey() {
        print("WindowManager: setupToggleHotkey called")
        let settings = AppSettings.shared
        
        // Convert NSEvent.ModifierFlags to HotKey modifiers
        var hotkeyModifiers: NSEvent.ModifierFlags = []
        if settings.toggleHotkeyModifiers.contains(.command) {
            hotkeyModifiers.insert(.command)
        }
        if settings.toggleHotkeyModifiers.contains(.option) {
            hotkeyModifiers.insert(.option)
        }
        if settings.toggleHotkeyModifiers.contains(.control) {
            hotkeyModifiers.insert(.control)
        }
        if settings.toggleHotkeyModifiers.contains(.shift) {
            hotkeyModifiers.insert(.shift)
        }
        
        // Create the hotkey
        print("WindowManager: Creating hotkey with key: \(settings.toggleHotkeyKey) and modifiers: \(hotkeyModifiers)")
        hotKey = HotKey(key: settings.toggleHotkeyKey, modifiers: hotkeyModifiers)
        hotKey?.keyDownHandler = { [weak self] in
            print("WindowManager: Toggle hotkey pressed!")
            self?.toggleCustomWindowVisibility()
        }
        print("WindowManager: Hotkey created and handler set")
    }
    
    // Method called when hotkey settings change
    @MainActor
    @objc private func hotkeySettingsChanged() {
        if !isHotkeyDisabled {
            setupToggleHotkey()
        }
    }

    // Method called when a window becomes key (like settings window)
    @objc private func windowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        
        // Check if this is not our custom window and hide our floating window
        if window != customWindow {
            // Check if it's likely a settings window by checking the window title or class
            let windowTitle = window.title
            let windowClass = String(describing: type(of: window))
            
            // Hide our floating window if a settings-like window opens
            if windowTitle.contains("Settings") || windowTitle.contains("Preferences") || 
               windowClass.contains("Settings") || windowClass.contains("Preferences") {
                hideCustomWindow()
            }
        }
    }

    // Method to temporarily disable the global hotkey (for onboarding)
    func disableGlobalHotkey() {
        print("WindowManager: disableGlobalHotkey called")
        isHotkeyDisabled = true
        if hotKey != nil {
            print("WindowManager: HotKey exists, setting to nil")
            hotKey = nil
            print("WindowManager: HotKey set to nil")
        } else {
            print("WindowManager: HotKey was already nil")
        }
    }
    
    // Method to re-enable the global hotkey (after onboarding)
    @MainActor
    func enableGlobalHotkey() {
        print("WindowManager: enableGlobalHotkey called")
        isHotkeyDisabled = false
        setupToggleHotkey()
        print("WindowManager: setupToggleHotkey completed")
    }

    // Method to enable context-sensitive hotkeys when window is visible
    private func enableContextHotkeys() {
        // Create the global hotkey for Cmd + R
        reloadHotKey = HotKey(key: .r, modifiers: [.command])
        reloadHotKey?.keyDownHandler = { [weak self] in
            // Call the reload action closure stored in the window
            self?.customWindow?.reloadAction?()
        }

        // Create the global hotkey for Cmd + /
        nextServiceHotKey = HotKey(key: .slash, modifiers: [.command])
        nextServiceHotKey?.keyDownHandler = { [weak self] in
            // Call the switch service action closure stored in the window
            self?.customWindow?.nextServiceAction?()
        }
    }
    
    // Method to disable context-sensitive hotkeys when window is hidden
    private func disableContextHotkeys() {
        reloadHotKey = nil
        nextServiceHotKey = nil
    }

    // Method to toggle the custom window's visibility
    @MainActor
    func toggleCustomWindowVisibility() {
        // print("toggleCustomWindowVisibility called. customWindow is currently: \(customWindow == nil ? "nil" : "not nil")")
        if customWindow == nil {
            //print("customWindow is nil, creating new window.")
            // If the window hasn't been created yet, create it
            let settings = AppSettings.shared
            let newWindow = BorderlessWindow(
                // Use saved window frame from settings
                contentRect: settings.windowFrame,
                styleMask: [.borderless, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )

            // Only center the window if it's the first time (default frame)
            let defaultFrame = NSRect(x: 0, y: 0, width: 500, height: 600)
            if settings.windowFrame == defaultFrame {
                newWindow.center() // Center the window only for first launch
            } else {
                // Ensure the saved frame is visible on screen
                let screenFrame = NSScreen.main?.visibleFrame ?? NSScreen.main?.frame ?? .zero
                let adjustedFrame = settings.windowFrame
                
                // Adjust if window is completely off-screen
                if adjustedFrame.maxX < screenFrame.minX || adjustedFrame.minX > screenFrame.maxX ||
                   adjustedFrame.maxY < screenFrame.minY || adjustedFrame.minY > screenFrame.maxY {
                    newWindow.center()
                } else {
                    newWindow.setFrame(adjustedFrame, display: false)
                }
            }

            // Create an NSHostingView to wrap the SwiftUI ContentView
            // ContentView will set the actions on the window in its onAppear
            // Set the ContentView as the root view of the HostingView once
            let contentView = ContentView(window: newWindow, windowManager: self) // Pass windowManager
            let hostingView = NSHostingView(rootView: AnyView(contentView)) // Wrap in AnyView
            // Set the HostingView as the contentView of the MaskedVisualEffectView
            if let maskedContentView = newWindow.contentView as? MaskedVisualEffectView {
                 maskedContentView.addSubview(hostingView)
                 // Set constraints to make hostingView fill the maskedContentView
                 hostingView.translatesAutoresizingMaskIntoConstraints = false
                 NSLayoutConstraint.activate([
                     hostingView.topAnchor.constraint(equalTo: maskedContentView.topAnchor),
                     hostingView.bottomAnchor.constraint(equalTo: maskedContentView.bottomAnchor),
                     hostingView.leadingAnchor.constraint(equalTo: maskedContentView.leadingAnchor),
                     hostingView.trailingAnchor.constraint(equalTo: maskedContentView.trailingAnchor)
                 ])
             } else { // Fallback if contentView is not MaskedVisualEffectView
                 newWindow.contentView = hostingView // Set directly if necessary
             }

            // Store the window in the class property
            customWindow = newWindow
            
            // Set up window frame change notification
            setupWindowFrameObserver()

            // Actions will be set on customWindow by ContentView in its onAppear

        }

        // Now that we are sure customWindow is not nil, toggle its visibility
        if let window = customWindow {
            let isVisible = window.isVisible
            // print("customWindow is not nil. Current visibility: \(isVisible).")
            window.setIsVisible(!isVisible)

            // Always attempt to make it key and order front when showing
            if !isVisible { // If the window *was* hidden and is now visible
                // print("Window was hidden, making visible and ordering front.")
                // Activate the application to ensure the window can become key
                NSApp.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
                // Don't center every time - preserve the saved position
                // Enable context-sensitive hotkeys when window becomes visible
                enableContextHotkeys()
            }
             else { // If the window *was* visible and is now hidden
                 //print("Window was visible, hiding.")
                 // Disable context-sensitive hotkeys when window becomes hidden
                 disableContextHotkeys()
                 // Optionally, you might want to resign key window status when hiding
                 // window.resignKey()
             }
        }
    }
    
    // Method to hide the custom window (for settings)
    func hideCustomWindow() {
        if let window = customWindow, window.isVisible {
            window.setIsVisible(false)
            // Disable context-sensitive hotkeys when window becomes hidden
            disableContextHotkeys()
        }
    }

    // Method to ensure the custom window is focused and brought to front
    func focusCustomWindow() {
        if let window = customWindow, window.isVisible {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }

    // Method to set up window frame observer
    private func setupWindowFrameObserver() {
        guard let window = customWindow else { return }
        
        // Listen for window frame changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResize),
            name: NSWindow.didResizeNotification,
            object: window
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMove),
            name: NSWindow.didMoveNotification,
            object: window
        )
    }
    
    // Method called when window is resized
    @MainActor
    @objc private func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window == customWindow else { return }
        
        // Save the new frame to settings
        AppSettings.shared.updateWindowFrame(window.frame)
    }
    
    // Method called when window is moved
    @MainActor
    @objc private func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window == customWindow else { return }
        
        // Save the new frame to settings
        AppSettings.shared.updateWindowFrame(window.frame)
    }

    // Clean up observers when WindowManager is deallocated
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // We no longer need the perform helper methods here
} 