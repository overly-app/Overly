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
import WebKit

// Custom window class for command palette that ensures proper key handling
class CommandPaletteWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
    
    override func keyDown(with event: NSEvent) {
        // Let SwiftUI handle the key events first
        super.keyDown(with: event)
    }
}

// Class to manage the window and hotkey
class WindowManager: NSObject, ObservableObject {
    static let shared = WindowManager()
    
    private var customWindow: BorderlessWindow? // Use BorderlessWindow type
    private var commandPaletteWindow: CommandPaletteWindow? // Separate window for command palette
    private var hotKey: HotKey?
    private var reloadHotKey: HotKey?
    private var nextServiceHotKey: HotKey?
    private var settingsHotKey: HotKey?
    private var commandPaletteHotKey: HotKey?
    private var isHotkeyDisabled = false // Track if hotkey is intentionally disabled

    // Closures to trigger actions on the visible ContentView
    // These closures will be set by the visible ContentView instance
    private var reloadWebViewAction: (() -> Void)?
    private var switchToNextServiceAction: (() -> Void)?
    var showCommandPaletteAction: (() -> Void)?

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
        
        // Create a global hotkey for Option + Space (command palette)
        commandPaletteHotKey = HotKey(key: .space, modifiers: [.option])
        commandPaletteHotKey?.keyDownHandler = { [weak self] in
            Task { @MainActor in
                self?.showCommandPaletteGlobally()
            }
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

    // Method to ensure the custom window is always shown (not toggle)
    @MainActor
    func showCustomWindow() {
        print("ShowCustomWindow called")
        
        if customWindow == nil {
            print("Creating new window")
            // Create the window if it doesn't exist
            let settings = AppSettings.shared
            let newWindow = BorderlessWindow(
                contentRect: settings.windowFrame,
                styleMask: [.borderless, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )

            // Only center the window if it's the first time (default frame)
            let defaultFrame = NSRect(x: 0, y: 0, width: 500, height: 600)
            if settings.windowFrame == defaultFrame {
                newWindow.center()
            } else {
                let screenFrame = NSScreen.main?.visibleFrame ?? NSScreen.main?.frame ?? .zero
                let adjustedFrame = settings.windowFrame
                
                if adjustedFrame.maxX < screenFrame.minX || adjustedFrame.minX > screenFrame.maxX ||
                   adjustedFrame.maxY < screenFrame.minY || adjustedFrame.minY > screenFrame.maxY {
                    newWindow.center()
                } else {
                    newWindow.setFrame(adjustedFrame, display: false)
                }
            }

            let contentView = ContentView(window: newWindow, windowManager: self)
            let hostingView = NSHostingView(rootView: AnyView(contentView))
            
            if let maskedContentView = newWindow.contentView as? MaskedVisualEffectView {
                 maskedContentView.addSubview(hostingView)
                 hostingView.translatesAutoresizingMaskIntoConstraints = false
                 NSLayoutConstraint.activate([
                     hostingView.topAnchor.constraint(equalTo: maskedContentView.topAnchor),
                     hostingView.bottomAnchor.constraint(equalTo: maskedContentView.bottomAnchor),
                     hostingView.leadingAnchor.constraint(equalTo: maskedContentView.leadingAnchor),
                     hostingView.trailingAnchor.constraint(equalTo: maskedContentView.trailingAnchor)
                 ])
             } else {
                 newWindow.contentView = hostingView
             }

            customWindow = newWindow
            setupWindowFrameObserver()
        }
        
        // Always ensure the window is visible and focused
        if let window = customWindow {
            print("Making window visible and focused")
            
            // Special handling for dock-less apps
            if NSApp.activationPolicy() == .accessory {
                print("App is dock-less, using special activation")
                // For dock-less apps, we need to temporarily change activation policy
                NSApp.setActivationPolicy(.regular)
                window.setIsVisible(true)
                NSApp.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
                
                // Change back to accessory after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NSApp.setActivationPolicy(.accessory)
                }
            } else {
                print("App is in dock, using normal activation")
                window.setIsVisible(true)
                NSApp.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
            }
            
            enableContextHotkeys()
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
            print("Focusing custom window")
            
            // Special handling for dock-less apps
            if NSApp.activationPolicy() == .accessory {
                print("App is dock-less, using special focus")
                // For dock-less apps, temporarily change activation policy
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
                
                // Change back to accessory after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NSApp.setActivationPolicy(.accessory)
                }
            } else {
                print("App is in dock, using normal focus")
                NSApp.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
            }
        }
    }

    // Method to show command palette globally (Option+Space)
    @MainActor
    func showCommandPaletteGlobally() {
        // Toggle behavior: if window is visible, hide it; if hidden, show it
        if let window = commandPaletteWindow, window.isVisible {
            // Hide the window if it's already visible
            window.orderOut(nil)
        } else {
            // Create or show the standalone command palette window
            if commandPaletteWindow == nil {
                createCommandPaletteWindow()
            }
            
            if let window = commandPaletteWindow {
                NSApp.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
                
                // Ensure the window can receive keyboard events
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    window.makeKey()
                }
            }
        }
    }

    // Create a standalone command palette window
    @MainActor
    private func createCommandPaletteWindow() {
        let windowFrame = NSRect(x: 0, y: 0, width: 600, height: 400)
        
        let window = CommandPaletteWindow(
            contentRect: windowFrame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.level = .floating
        window.acceptsMouseMovedEvents = true
        window.center()
        
        // Create the command palette view
        let commandPaletteView = StandaloneCommandPalette { [weak self] url in
            self?.navigateToURL(url)
        }
        
        let hostingView = NSHostingView(rootView: commandPaletteView)
        window.contentView = hostingView
        
        commandPaletteWindow = window
    }
    
    // Navigate to URL in the main window's WebView
    @MainActor
    private func navigateToURL(_ url: URL) {
        print("NavigateToURL called with: \(url)")
        
        // First dismiss the command palette window
        commandPaletteWindow?.orderOut(nil)
        
        // Check if we need to handle dock-less mode before any window operations
        let isDockless = NSApp.activationPolicy() == .accessory
        if isDockless {
            print("App is dock-less, switching to regular policy first")
            NSApp.setActivationPolicy(.regular)
            
            // Give macOS time to process the activation policy change
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.performWindowOperations(url: url, isDockless: true)
            }
        } else {
            // If not dock-less, proceed immediately
            performWindowOperations(url: url, isDockless: false)
        }
    }
    
    @MainActor
    private func performWindowOperations(url: URL, isDockless: Bool) {
        // Ensure the main window is visible - always show it, don't toggle
        if customWindow == nil {
            print("CustomWindow is nil, creating new window")
            // Create the window if it doesn't exist
            showCustomWindow()
            // After creating, ensure it's visible and focused
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let window = self.customWindow {
                    print("Window created, making it visible and key")
                    NSApp.activate(ignoringOtherApps: true)
                    window.makeKeyAndOrderFront(nil)
                    window.setIsVisible(true)
                    window.orderFrontRegardless()
                }
            }
        } else if !customWindow!.isVisible {
            print("CustomWindow exists but is hidden, showing it")
            // Show the window if it exists but is hidden
            let window = customWindow!
            NSApp.activate(ignoringOtherApps: true)
            window.setIsVisible(true)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            enableContextHotkeys()
        } else {
            print("CustomWindow is already visible, focusing it")
            // Window is already visible, just make sure it's focused
            let window = customWindow!
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
        
        // Revert to accessory policy if we were dock-less
        if isDockless {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                print("Reverting to accessory policy")
                NSApp.setActivationPolicy(.accessory)
            }
        }
        
        // Navigate in the WebView after a longer delay to ensure window is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            print("Attempting to navigate WebView")
            if let window = self.customWindow,
               let webView = window.contentView?.findSubview(ofType: WKWebView.self) {
                print("Found WebView, loading URL: \(url)")
                let request = URLRequest(url: url)
                webView.load(request)
            } else {
                print("Could not find WebView in window")
            }
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

    // Method to toggle the custom window's visibility
    @MainActor
    func toggleCustomWindowVisibility() {
        if customWindow == nil {
            // If window doesn't exist, create and show it
            showCustomWindow()
        } else if let window = customWindow {
            let isVisible = window.isVisible
            window.setIsVisible(!isVisible)

            // Always attempt to make it key and order front when showing
            if !isVisible { // If the window *was* hidden and is now visible
                NSApp.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
                enableContextHotkeys()
            } else { // If the window *was* visible and is now hidden
                disableContextHotkeys()
            }
        }
    }
} 