//
//  NavigationManager.swift
//  Overly
//
//  Created by hypackel on 5/20/25.
//

import AppKit
import SwiftUI
import WebKit

class NavigationManager: ObservableObject {
    weak var customWindow: BorderlessWindow?
    
    @MainActor
    func navigateToURL(_ url: URL) {
        print("NavigateToURL called with: \(url)")
        
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
            // Window should be created by WindowManager
            return
        } else if !customWindow!.isVisible {
            print("CustomWindow exists but is hidden, showing it")
            // Show the window if it exists but is hidden
            let window = customWindow!
            NSApp.activate(ignoringOtherApps: true)
            window.setIsVisible(true)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        } else {
            print("CustomWindow is already visible, focusing it")
            // Window is already visible, just make sure it's focused
            let window = customWindow!
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
        
        // Enhanced activation for non-dockless mode
        if !isDockless {
            print("Non-dockless mode: ensuring strong activation")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let window = self.customWindow {
                    NSApp.activate(ignoringOtherApps: true)
                    window.makeKeyAndOrderFront(nil)
                    window.orderFrontRegardless()
                    
                    // Ensure window is actually key
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        if !window.isKeyWindow {
                            print("Window is not key, forcing it to become key")
                            window.makeKey()
                        }
                    }
                }
            }
        }
        
        // Revert to accessory policy if we were dock-less
        if isDockless {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                print("Reverting to accessory policy")
                NSApp.setActivationPolicy(.accessory)
            }
        }
        
        // Navigate in the WebView after ensuring window is ready
        let navigationDelay = isDockless ? 0.3 : 0.2
        DispatchQueue.main.asyncAfter(deadline: .now() + navigationDelay) {
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
} 
