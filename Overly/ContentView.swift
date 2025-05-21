//
//  ContentView.swift
//  Overly
//
//  Created by hypackel on 5/20/25.
//

import SwiftUI
import WebKit

enum AIService: String, CaseIterable, Identifiable {
    case chatgpt = "ChatGPT"
    case gemini = "Gemini"
    case poe = "Poe"

    var id: String { self.rawValue }

    var url: URL {
        switch self {
        case .chatgpt: return URL(string: "https://chatgpt.com")!
        case .gemini: return URL(string: "https://gemini.google.com")!
        case .poe: return URL(string: "https://poe.com")!
        }
    }

    var iconName: String {
        switch self {
        case .chatgpt: return "openai" // Use the actual asset name
        case .gemini: return "gemini" // Use the actual asset name
        case .poe: return "poe" // Use the actual asset name
        }
    }
}

// Custom view for the dropdown menu content
struct ServiceDropdownView: View {
    @Binding var selectedService: AIService
    var dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(AIService.allCases) {
                service in
                Button(action: {
                    selectedService = service
                    dismiss()
                }) {
                    HStack {
                        Image(service.iconName) // Use the custom asset name
                            .resizable()
                            .frame(width: 20, height: 20)
                        Text(service.rawValue)
                        Spacer()
                    }
                    .contentShape(Rectangle()) // Make the entire row tappable
                }
                .buttonStyle(.plain) // Remove default button styling
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(selectedService == service ? Color.accentColor.opacity(0.2) : Color.clear)
                .cornerRadius(4)
            }
        }
        .padding(8) // Inner padding
        .background(Color.gray.opacity(0.2)) // Background for the dropdown
        .cornerRadius(8) // Rounded corners for the dropdown
        .shadow(radius: 5) // Add a subtle shadow
    }
}

// Custom view for the title bar
struct CustomTitleBar: View {
    let window: NSWindow? // Add a property to hold the window reference
    @Binding var selectedService: AIService // Binding to the selected service
    @State private var showingDropdown = false // State to control dropdown visibility
    @State private var isHoveringButton = false // Track if the button is hovered
    @State private var isHoveringDropdown = false // Track if the dropdown is hovered
    @State private var closeDropdownWorkItem: DispatchWorkItem? = nil // For delayed closing

    private let hoverDelay: Double = 0.1 // Small delay before closing

    var body: some View {
        HStack {
            Text("Overly")
                .foregroundColor(.white)
                .font(.headline)
            Spacer() // Pushes the text to the left
            
            // Custom button to toggle the dropdown
            Button(action: {
                // Toggle immediately on click
                showingDropdown.toggle()
                // Cancel any pending delayed close
                closeDropdownWorkItem?.cancel()

            }) {
                Image(selectedService.iconName) // Use the custom asset name
                    .resizable()
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain) // Remove default button styling
            .onHover { isHovering in
                isHoveringButton = isHovering
                if isHovering {
                    // If hovering button, show dropdown and cancel close delay
                    showingDropdown = true
                    closeDropdownWorkItem?.cancel()
                } else if !isHoveringDropdown {
                    // If leaving button and not hovering dropdown, start close delay
                    startCloseDropdownDelay()
                }
            }
            .popover(isPresented: $showingDropdown, arrowEdge: .top) {
                ServiceDropdownView(selectedService: $selectedService) {
                    showingDropdown = false // Dismiss dropdown when an item is selected
                    closeDropdownWorkItem?.cancel() // Cancel any pending close
                }
                // Track hover state over the dropdown content
                .onHover {
                    isHovering in
                    isHoveringDropdown = isHovering
                    if isHovering {
                        // If hovering dropdown, cancel close delay
                        closeDropdownWorkItem?.cancel()
                    } else if !isHoveringButton {
                        // If leaving dropdown and not hovering button, start close delay
                        startCloseDropdownDelay()
                    }
                }
            }
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
    
    private func startCloseDropdownDelay() {
        closeDropdownWorkItem?.cancel()
        let task = DispatchWorkItem {
            showingDropdown = false
        }
        closeDropdownWorkItem = task
        DispatchQueue.main.asyncAfter(deadline: .now() + hoverDelay, execute: task)
    }
}

struct ContentView: View {
    let window: NSWindow? // Add a property to hold the window reference
    @State private var selectedService: AIService = .chatgpt // State to hold the selected service

    var body: some View {
        VStack(spacing: 0) { // Use a VStack with no spacing
            // Pass the binding down to CustomTitleBar
            CustomTitleBar(window: window, selectedService: $selectedService) // Add our custom title bar at the top
            // Pass the selected service URL down to WebView
            WebView(url: selectedService.url)
        }
        // Observe changes to selectedService (triggered by dropdown) and update WebView
        .onChange(of: selectedService) {
            _ in
            // WebView will automatically update due to the binding
        }
        .onAppear {
            // When the view appears, pass the actions up to the WindowManager via the window
            if let window = window as? BorderlessWindow {
                 window.reloadAction = { self.reloadWebView() }
                 window.nextServiceAction = { self.selectNextService() }
             }
        }
    }
    
    // Function to find the next service in the enum and switch to it
    // Internal so WindowManager can call it directly
    internal func selectNextService() {
        let allCases = AIService.allCases
        if let currentIndex = allCases.firstIndex(of: selectedService) {
            let nextIndex = (currentIndex + 1) % allCases.count
            selectedService = allCases[nextIndex]
        }
    }
    
    // Function to trigger WebView reload
    // Internal so WindowManager can call it directly
    internal func reloadWebView() {
        // Find the WKWebView instance within the view hierarchy and call reload
         if let webView = window?.contentView?.findSubview(ofType: WKWebView.self) {
             webView.reload()
         }
    }
}

#Preview {
    // Provide a dummy binding and actions for preview
    ContentView(window: nil)
}
