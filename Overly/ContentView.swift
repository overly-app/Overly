//
//  ContentView.swift
//  Overly
//
//  Created by hypackel on 5/20/25.
//

import SwiftUI
import WebKit

// Custom view for the title bar
struct CustomTitleBar: View {
    let window: NSWindow? // Add a property to hold the window reference

    var body: some View {
        HStack {
            Text("Overly")
                .foregroundColor(.white)
                .font(.headline)
            Spacer() // Pushes the text to the left
        }
        .padding(.horizontal) // Add horizontal padding
        .frame(height: 30) // Set a fixed height for the title bar
        .background(.thinMaterial) // Set the background material
        .gesture(TapGesture(count: 2).onEnded({
            // Handle double-click to maximize/restore the window with animation
            if let window = window {
                let screenFrame = NSScreen.main?.visibleFrame ?? NSScreen.main?.frame ?? .zero
                let windowFrame = window.frame

                // Check if the window is already maximized (or close to it)
                let isMaximized = windowFrame.size.width >= screenFrame.size.width * 0.95 && windowFrame.size.height >= screenFrame.size.height * 0.95

                let targetFrame: NSRect

                if isMaximized {
                    // Define the frame to restore the window to
                    let initialWidth: CGFloat = 600
                    let initialHeight: CGFloat = 500
                    let newOriginX = screenFrame.midX - initialWidth / 2
                    let newOriginY = screenFrame.midY - initialHeight / 2
                    targetFrame = NSRect(x: newOriginX, y: newOriginY, width: initialWidth, height: initialHeight)
                } else {
                    // Define the frame to maximize the window to
                    targetFrame = screenFrame
                }

                // Animate the frame change
                NSAnimationContext.runAnimationGroup({
                    context in
                    context.duration = 0.3 // Animation duration in seconds
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    window.animator().setFrame(targetFrame, display: true)
                }, completionHandler: nil)
            }
        }))
    }
}

struct ContentView: View {
    let window: NSWindow? // Add a property to hold the window reference

    var body: some View {
        VStack(spacing: 0) { // Use a VStack with no spacing
            CustomTitleBar(window: window) // Add our custom title bar at the top
            // Pass the binding down to WebView
            WebView(url: URL(string: "https://chatgpt.com")!)
        }
    }
}

#Preview {
    // Provide a dummy binding for preview
    ContentView(window: nil)
}
