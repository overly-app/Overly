//
//  WindowManager.swift
//  Overly
//
//  Created by hypackel on 5/20/25.
//

import SwiftUI
import AppKit
import Combine

// Custom window class for command palette that ensures proper key handling
class CommandPaletteWindow: NSWindow {
    private var globalMouseMonitor: Any?
    
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
    
    override func makeKeyAndOrderFront(_ sender: Any?) {
        super.makeKeyAndOrderFront(sender)
        startMonitoringGlobalClicks()
    }
    
    override func orderOut(_ sender: Any?) {
        stopMonitoringGlobalClicks()
        super.orderOut(sender)
    }
    
    private func startMonitoringGlobalClicks() {
        // Remove existing monitor if any
        stopMonitoringGlobalClicks()
        
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self else { return }
            
            // Get the click location in screen coordinates
            let clickLocation = event.locationInWindow
            let screenLocation = event.window?.convertToScreen(NSRect(origin: clickLocation, size: .zero)).origin ?? clickLocation
            
            // Check if the click is outside our window
            if !self.frame.contains(screenLocation) {
                DispatchQueue.main.async {
                    self.orderOut(nil)
                }
            }
        }
    }
    
    private func stopMonitoringGlobalClicks() {
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseMonitor = nil
        }
    }
    
    deinit {
        stopMonitoringGlobalClicks()
    }
}

// Class to manage the window and hotkey
class WindowManager: NSObject, ObservableObject {
    static let shared = WindowManager()
    
    private var customWindow: BorderlessWindow?
    private var commandPaletteWindow: CommandPaletteWindow?
    
    // Managers
    private let hotkeyManager = HotkeyManager()
    private let navigationManager = NavigationManager()
    
    override init() {
        super.init()
        setupManagerActions()
        setupNotificationObservers()
    }
    
    private func setupManagerActions() {
        // Connect hotkey manager actions
        hotkeyManager.toggleWindowAction = { [weak self] in
            Task { @MainActor in
                self?.toggleCustomWindowVisibility()
            }
        }
        
        hotkeyManager.hideWindowAction = { [weak self] in
            self?.hideCustomWindow()
        }
        
        hotkeyManager.showCommandPaletteAction = { [weak self] in
            Task { @MainActor in
                self?.showCommandPaletteGlobally()
            }
        }
        
        hotkeyManager.reloadWebViewAction = { [weak self] in
            self?.customWindow?.reloadAction?()
        }
        
        hotkeyManager.switchToNextServiceAction = { [weak self] in
            self?.customWindow?.nextServiceAction?()
        }
        
        // toggleSidebarAction removed - sidebar functionality was never implemented
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
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

    // Hotkey management delegation
    func disableGlobalHotkey() {
        hotkeyManager.disableGlobalHotkey()
    }
    
    @MainActor
    func enableGlobalHotkey() {
        hotkeyManager.enableGlobalHotkey()
    }

    @MainActor
    func showCustomWindow() {
        print("ShowCustomWindow called")
        
        if customWindow == nil {
            print("Creating new window")
            createCustomWindow()
        }
        
        // Always ensure the window is visible and focused
        if let window = customWindow {
            print("Making window visible and focused")
            
            // Special handling for dock-less apps
            if NSApp.activationPolicy() == .accessory {
                print("App is dock-less, using special activation")
                NSApp.setActivationPolicy(.regular)
                window.setIsVisible(true)
                NSApp.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NSApp.setActivationPolicy(.accessory)
                }
            } else {
                print("App is in dock, using normal activation")
                window.setIsVisible(true)
                NSApp.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
            }
            
            hotkeyManager.enableContextHotkeys()
        }
    }
    
    @MainActor
    private func createCustomWindow() {
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
        navigationManager.customWindow = newWindow
        setupWindowFrameObserver()
    }

    func hideCustomWindow() {
        if let window = customWindow, window.isVisible {
            window.setIsVisible(false)
            hotkeyManager.disableContextHotkeys()
        }
    }

    func focusCustomWindow() {
        if let window = customWindow, window.isVisible {
            print("Focusing custom window")
            
            if NSApp.activationPolicy() == .accessory {
                print("App is dock-less, using special focus")
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
                
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

    @MainActor
    func showCommandPaletteGlobally() {
        // Toggle behavior: if window is visible, hide it; if hidden, show it
        if let window = commandPaletteWindow, window.isVisible {
            window.orderOut(nil)
        } else {
            if commandPaletteWindow == nil {
                createCommandPaletteWindow()
            }
            
            if let window = commandPaletteWindow {
                NSApp.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    window.makeKey()
                }
            }
        }
    }

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
        
        let commandPaletteView = StandaloneCommandPalette { [weak self] url in
            self?.navigateToURL(url)
        }
        
        let hostingView = NSHostingView(rootView: commandPaletteView)
        window.contentView = hostingView
        
        commandPaletteWindow = window
    }
    
    @MainActor
    private func navigateToURL(_ url: URL) {
        print("WindowManager: NavigateToURL called with: \(url)")
        
        // First dismiss the command palette window
        commandPaletteWindow?.orderOut(nil)
        
        // Ensure window exists and is shown
        if customWindow == nil {
            showCustomWindow()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.navigationManager.navigateToURL(url)
            }
        } else {
            showCustomWindow()
            navigationManager.navigateToURL(url)
        }
    }

    private func setupWindowFrameObserver() {
        guard let window = customWindow else { return }
        
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
    
    @MainActor
    @objc private func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window == customWindow else { return }
        
        AppSettings.shared.updateWindowFrame(window.frame)
    }
    
    @MainActor
    @objc private func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window == customWindow else { return }
        
        AppSettings.shared.updateWindowFrame(window.frame)
    }

    @MainActor
    func toggleCustomWindowVisibility() {
        if customWindow == nil {
            showCustomWindow()
        } else if let window = customWindow {
            let isVisible = window.isVisible
            window.setIsVisible(!isVisible)

            if !isVisible {
                NSApp.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
                hotkeyManager.enableContextHotkeys()
            } else {
                hotkeyManager.disableContextHotkeys()
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
} 