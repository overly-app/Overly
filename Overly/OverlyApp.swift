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
import WebKit

// Custom NSVisualEffectView subclass to handle masking for rounded corners
class MaskedVisualEffectView: NSVisualEffectView {
    override func layout() {
        super.layout()
        applyCustomShapeMask()
    }

    // Method to apply the custom shape mask
    func applyCustomShapeMask() {
        let layer = CAShapeLayer()
        let bounds = self.bounds
        let cornerRadius: CGFloat = 12.0 // Define the corner radius to match macOS default

        // Create a path with rounded corners for all corners
        let path = NSBezierPath(roundedRect: bounds, xRadius: cornerRadius, yRadius: cornerRadius)
        
        layer.path = path.cgPath // Set the path
        self.layer?.mask = layer // Apply the mask to the view's layer
        
        // Configure the layer for proper border handling
        self.layer?.cornerRadius = cornerRadius
        self.layer?.masksToBounds = true
    }

    // Ensure the mask is updated when the view's bounds change
    override var bounds: NSRect {
        didSet {
            applyCustomShapeMask()
        }
    }
}

// Custom NSWindow subclass for a borderless window
class BorderlessWindow: NSWindow {
    // Closures to hold actions from ContentView
    var reloadAction: (() -> Void)?
    var nextServiceAction: (() -> Void)?

    override init(
        contentRect: NSRect,
        styleMask: NSWindow.StyleMask,
        backing: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        // Add .resizable back to the style mask
        let modifiedStyleMask: NSWindow.StyleMask = [.borderless, .resizable]
        super.init(contentRect: contentRect, styleMask: modifiedStyleMask, backing: backing, defer: flag)

        // Configure the window for a custom shape and no title bar
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.isOpaque = false
        self.backgroundColor = .clear
        self.isMovableByWindowBackground = true
        self.hasShadow = false // Ensure no native shadow
        
        // Set window level to floating so it stays above other windows
        self.level = .floating
        
        // Set window appearance to match system
        self.appearance = NSAppearance(named: .vibrantDark)
        
        // Set a custom content view that will handle the shape and background
        let customContentView = MaskedVisualEffectView(frame: contentRect)
        // Use .HUDWindow for a thin, translucent material
        customContentView.material = .hudWindow
        customContentView.blendingMode = .behindWindow
        customContentView.state = .active
        customContentView.wantsLayer = true
        
        // Ensure the window and content view have the same corner radius
        let cornerRadius: CGFloat = 12.0
        self.contentView = customContentView
        
        // Configure the window for rounded corners without borders
        DispatchQueue.main.async {
            if let contentView = self.contentView {
                contentView.wantsLayer = true
                contentView.layer?.cornerRadius = cornerRadius
                contentView.layer?.masksToBounds = true
                contentView.layer?.borderWidth = 0
                contentView.layer?.backgroundColor = .clear
            }
             // The window's own layer should also be configured
             self.contentView?.window?.contentView?.wantsLayer = true
             self.contentView?.window?.contentView?.layer?.cornerRadius = cornerRadius
             self.contentView?.window?.contentView?.layer?.masksToBounds = true
             self.contentView?.window?.contentView?.layer?.borderWidth = 0
             self.contentView?.window?.contentView?.layer?.backgroundColor = .clear
            
        }
    }

    // Override computed properties to allow the window to become key and main
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        super.setFrame(frameRect, display: flag)
        if let contentView = self.contentView {
            let cornerRadius: CGFloat = 12.0
            contentView.layer?.cornerRadius = cornerRadius
            contentView.layer?.borderWidth = 0
            
            // Also apply to the window's content view during resize
            contentView.window?.contentView?.layer?.cornerRadius = cornerRadius
            contentView.window?.contentView?.layer?.borderWidth = 0
        }
    }
}

// Class to manage the window and hotkey
class WindowManager: NSObject {
    private var customWindow: BorderlessWindow? // Use BorderlessWindow type
    private var hotKey: HotKey?
    private var reloadHotKey: HotKey?
    private var nextServiceHotKey: HotKey?
    
    // Closures to trigger actions on the visible ContentView
    // These closures will be set by the visible ContentView instance
    private var reloadWebViewAction: (() -> Void)?
    private var switchToNextServiceAction: (() -> Void)?
    
    override init() {
        super.init()
        // Create the global hotkey for Cmd + J
        hotKey = HotKey(key: .j, modifiers: [.command])
        hotKey?.keyDownHandler = { [weak self] in
            print("Cmd + J hotkey pressed.")
            // Call the toggle window method when the hotkey is pressed
            self?.toggleCustomWindowVisibility()
        }
        
        // Create the global hotkey for Cmd + R
        reloadHotKey = HotKey(key: .r, modifiers: [.command])
        reloadHotKey?.keyDownHandler = { [weak self] in
            print("Cmd + R hotkey pressed.")
            print("WindowManager: Attempting to call reloadAction closure.")
            // Call the reload action closure stored in the window
            self?.customWindow?.reloadAction?()
            print("WindowManager: reloadAction closure call attempted.")
        }
        
        // Create the global hotkey for Cmd + /
        nextServiceHotKey = HotKey(key: .slash, modifiers: [.command]) // Corrected key name
        nextServiceHotKey?.keyDownHandler = { [weak self] in
            print("Cmd + / hotkey pressed.")
            print("WindowManager: Attempting to call nextServiceAction closure.")
            // Call the switch service action closure stored in the window
            self?.customWindow?.nextServiceAction?()
            print("WindowManager: nextServiceAction closure call attempted.")
        }
    }

    // Method to toggle the custom window's visibility
    func toggleCustomWindowVisibility() {
        print("toggleCustomWindowVisibility called. customWindow is currently: \(customWindow == nil ? "nil" : "not nil")")
        if customWindow == nil {
            print("customWindow is nil, creating new window.")
            // If the window hasn't been created yet, create it
            let newWindow = BorderlessWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
                styleMask: [.borderless, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )

            newWindow.center() // Center the window initially

            // Create an NSHostingView to wrap the SwiftUI ContentView
            // ContentView will set the actions on the window in its onAppear
             let contentView = ContentView(window: newWindow)
             let hostingView = NSHostingView(rootView: AnyView(contentView)) // Wrap in AnyView
             newWindow.contentView = hostingView // Set directly as content view

            // Store the window in the class property
            customWindow = newWindow
            
            // Actions will be set on customWindow by ContentView in its onAppear

        }

        // Now that we are sure customWindow is not nil, toggle its visibility
        if let window = customWindow {
            let isVisible = window.isVisible
            print("customWindow is not nil. Current visibility: \(isVisible).")
            window.setIsVisible(!isVisible)

            // Always attempt to make it key and order front when showing
            if !isVisible { // If the window *was* hidden and is now visible
                print("Window was hidden, making visible and ordering front.")
                // Activate the application to ensure the window can become key
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
    
    // We no longer need the perform helper methods here
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
        MenuBarExtra {
            // Content remains the same
            Divider() // Add a separator line
            Button("Quit") {
                NSApplication.shared.terminate(nil) // Add a Quit button
            }
        } label: {
            // Custom label view for more control
            HStack {
                Image(systemName: "globe") // System image
                Text("Overly") // The text label
            }
            // .background(.ultrathinMaterial) // Apply ultrathin material background
        }
    }
}

// A simple App Delegate to hold and manage the WindowManager
class AppDelegate: NSObject, NSApplicationDelegate {
    var windowManager: WindowManager? // Use optional to allow lazy initialization

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize the WindowManager when the application finishes launching
        windowManager = WindowManager()
        
        // Removed code that was setting actions from a temporary ContentView
        
        // Show the window immediately on launch
        windowManager?.toggleCustomWindowVisibility()
    }

    // Other optional NSApplicationDelegate methods can be added here if needed
}
