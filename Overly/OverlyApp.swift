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

// Custom NSVisualEffectView subclass to handle masking for rounded top corners
class MaskedVisualEffectView: NSVisualEffectView {
    override func layout() {
        super.layout()
        applyCustomShapeMask()
    }

    // Method to apply the custom shape mask
    func applyCustomShapeMask() {
        let layer = CAShapeLayer()
        let bounds = self.bounds
        let cornerRadius: CGFloat = 10.0 // Define the corner radius

        // Create a path with rounded top corners and straight bottom edges
        let path = NSBezierPath(roundedRect: bounds, xRadius: cornerRadius, yRadius: cornerRadius)

        // Create a rectangle that covers the bottom corners to make them square
        let squareBottom = NSRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: cornerRadius)
        path.append(NSBezierPath(rect: squareBottom))

        layer.path = path.cgPath // Set the path
        self.layer?.mask = layer // Apply the mask to the view's layer
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
    override init(
        contentRect: NSRect,
        styleMask: NSWindow.StyleMask,
        backing: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(contentRect: contentRect, styleMask: styleMask, backing: backing, defer: flag)

        // Configure the window for a custom shape and no title bar
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.isOpaque = false
        self.backgroundColor = .clear
        self.isMovableByWindowBackground = true

        // Set a custom content view that will handle the shape and background
        let customContentView = MaskedVisualEffectView(frame: contentRect)
        customContentView.material = .contentBackground // Using .contentBackground material
        customContentView.blendingMode = .behindWindow
        customContentView.state = .active
        customContentView.wantsLayer = true // Enable layers for masking

        self.contentView = customContentView

        // The mask is applied and updated in MaskedVisualEffectView's layout() and bounds.didSet

        // Update the window's shadow based on the new shape
        // This might need to be triggered after the content view's layout
        DispatchQueue.main.async { // Ensure layout has potentially happened
             self.invalidateShadow()
        }
    }

    // Required initializer
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Removed incorrect resize and setFrame overrides
}

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

            newWindow.center() // Center the window initially

            // Create an NSHostingView to wrap the SwiftUI ContentView
            // Add the hosting view to the window's content view (which is the masked effect view)
            if let effectView = newWindow.contentView as? MaskedVisualEffectView {
                 let hostingView = NSHostingView(rootView: ContentView(window: newWindow))
                 hostingView.translatesAutoresizingMaskIntoConstraints = false // Use constraints
                 effectView.addSubview(hostingView)

                 NSLayoutConstraint.activate([
                     hostingView.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
                     hostingView.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
                     hostingView.topAnchor.constraint(equalTo: effectView.topAnchor),
                     hostingView.bottomAnchor.constraint(equalTo: effectView.bottomAnchor)
                 ])
            } else {
                // Fallback if contentView is not the expected masked effect view
                print("Error: Window's contentView is not a MaskedVisualEffectView.")
                 let hostingView = NSHostingView(rootView: ContentView(window: newWindow))
                 newWindow.contentView = hostingView // Set directly if effect view is not available
            }

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
    }

    // Other optional NSApplicationDelegate methods can be added here if needed
}
