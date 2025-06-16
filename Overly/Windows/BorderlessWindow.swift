//
//  BorderlessWindow.swift
//  Overly
//
//  Created by hypackel on 5/20/25.
//

import AppKit

// Custom NSWindow subclass for a borderless window
class BorderlessWindow: NSWindow {
    // Closures to hold actions from ContentView
    var reloadAction: (() -> Void)?
    var nextServiceAction: (() -> Void)?
    var toggleSidebarAction: (() -> Void)?

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
        self.isMovableByWindowBackground = false // Disable window dragging by background
        self.hasShadow = false // Ensure no native shadow

        // Set window level to floating so it stays above other windows
        self.level = .floating

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