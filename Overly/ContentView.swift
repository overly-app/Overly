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
    case settings = "Settings"

    var id: String { self.rawValue }

    var url: URL? {
        switch self {
        case .chatgpt: return URL(string: "https://chatgpt.com")!
        case .gemini: return URL(string: "https://gemini.google.com")!
        case .poe: return URL(string: "https://poe.com")!
        case .settings: return nil
        }
    }

    var iconName: String {
        switch self {
        case .chatgpt: return "openai" // Use the actual asset name
        case .gemini: return "gemini" // Use the actual asset name
        case .poe: return "poe" // Use the actual asset name
        case .settings: return "gearshape"
        }
    }
}

// Custom view for the dropdown menu content
struct ServiceDropdownView: View {
    @Binding var selectedService: AIService
    var dismiss: () -> Void
    @ObservedObject var settings: AppSettings // Observe AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Iterate through active providers + settings
            ForEach(settings.activeProviders + [settings.allBuiltInProviders.first(where: { $0.id == AIService.settings.rawValue })!]) {
                provider in
                Button(action: {
                    // Find the corresponding AIService for the selected provider
                    if let selectedAIService = AIService.allCases.first(where: { $0.rawValue == provider.id }) {
                        selectedService = selectedAIService
                    } else if provider.id == AIService.settings.rawValue { // Handle settings case for custom providers
                         selectedService = .settings
                    }
                    // If it's a custom provider, we might need a different way to handle selection if AIService enum is not updated dynamically.
                    // For now, assuming selection will primarily be from AIService cases or settings.
                    dismiss()
                }) {
                    HStack {
                        // Display favicon if available
                        if let favicon = settings.faviconImage(for: provider) {
                            favicon
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20)
                        } else if provider.isSystemImage {
                            // Use systemName for SF Symbols (like settings)
                            Image(systemName: provider.iconName)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20)
                        } else {
                            // Use asset catalog for other built-in icons or a placeholder for custom ones if favicon fails
                            Image(provider.iconName)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20)
                                .onAppear {
                                    // Attempt to fetch favicon if it's a custom provider without a cached icon
                                    if provider.url != nil && settings.faviconCache[provider.id] == nil && settings.customProviders.contains(where: { $0.id == provider.id }) {
                                        Task {
                                            await settings.fetchFavicon(for: provider)
                                        }
                                    }
                                }
                        }
                        Text(provider.name)
                        Spacer()
                    }
                    .contentShape(Rectangle()) // Make the entire row tappable
                }
                .buttonStyle(.plain) // Remove default button styling
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(selectedService.id == provider.id ? Color.accentColor.opacity(0.2) : Color.clear) // Compare IDs
                .cornerRadius(4)
                .onAppear {
                    // Fetch favicon when the provider appears in the list
                    // Only fetch if it's a web-based provider and no favicon is cached yet
                    if provider.url != nil && settings.faviconCache[provider.id] == nil {
                        Task {
                            await settings.fetchFavicon(for: provider)
                        }
                    }
                }
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
    @ObservedObject var settings: AppSettings // Observe AppSettings
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
                // Use Image(systemName:) for the settings icon, otherwise use Image(_:)
                // Use selectedService to determine which icon to show in the title bar button
                if selectedService == .settings {
                    Image(systemName: selectedService.iconName) // Use systemName for SF Symbols
                        .resizable()
                        .frame(width: 20, height: 20)
                } else if let provider = settings.activeProviders.first(where: { $0.id == selectedService.id }), let favicon = settings.faviconImage(for: provider) {
                    // Display favicon in title bar if available for the selected service
                    favicon
                         .resizable()
                         .aspectRatio(contentMode: .fit)
                         .frame(width: 20, height: 20)
                } else {
                    // Fallback to asset catalog for other built-in icons if no favicon
                    Image(selectedService.iconName)
                        .resizable()
                        .frame(width: 20, height: 20)
                }
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
                ServiceDropdownView(selectedService: $selectedService, dismiss: { // Pass selectedService binding
                    // Dismiss dropdown when an item is selected
                    showingDropdown = false
                    closeDropdownWorkItem?.cancel()
                    // The view switching logic is now handled by the .onChange in ContentView
                }, settings: settings) // Pass AppSettings instance
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
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut) // Animation timing
                    window.animator().setFrame(targetFrame, display: true) // Apply animation
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
    // Add an ObservedObject property to observe the WindowManager
    @ObservedObject var windowManager: WindowManager // Observe the window manager
    @ObservedObject var settings = AppSettings.shared // Observe AppSettings

    @State private var selectedService: AIService = .chatgpt // State to hold the selected service

    var body: some View {
        // Use a Group to conditionally display content
        VStack(spacing: 0) { // Use a VStack with no spacing for the main content area
            // Always display the custom title bar
            CustomTitleBar(window: window, selectedService: $selectedService, settings: settings) // Add our custom title bar and pass settings
            
            // Switch the main content based on the current view state
            Group { // Use a Group to conditionally display content below the title bar
                switch windowManager.currentView {
                case .webView:
                    // Display the WebView when in webView state
                    // Safely unwrap the URL for the selected provider
                    if let provider = settings.activeProviders.first(where: { $0.id == selectedService.id }), let url = provider.url {
                        WebView(url: url)
                    } else {
                        // This case might happen if a selected provider is removed or becomes inactive
                         Color.clear // Or some placeholder view
                    }

                case .settingsView:
                    // Display the SettingsView when in settingsView state
                    SettingsView(windowManager: windowManager) // Pass the windowManager
                }
            }
            // The main VStack will inherit the padding and background from ContentView's modifiers if any are applied to ContentView itself.
            // Or, we can apply background/padding here if needed.
//            .background(.thinMaterial) // Example: Apply background here if not on ContentView
//            .padding() // Example: Apply padding here if not on ContentView
        }
        // Observe changes to selectedService (triggered by dropdown) and update WebView
        .onChange(of: selectedService) { newValue in // Use newValue
            // If the selected service is settings, switch to settings view
            if newValue == .settings {
                windowManager.showSettingsView()
            } else {
                // Otherwise, ensure we are in web view state and the web view will update due to binding
                windowManager.showWebView()
            }
        }
        .onAppear {
            // When the view appears, pass the actions up to the WindowManager via the window
            if let window = window as? BorderlessWindow {
                 window.reloadAction = { self.reloadWebView() }
                 window.nextServiceAction = { self.selectNextService() }
             }
        }
    }
    
    // Function to find the next service in the active providers list and switch to it
    // Internal so WindowManager can call it directly
    internal func selectNextService() {
        let activeProviders = settings.activeProviders // Get current active providers
        guard !activeProviders.isEmpty else { return } // Do nothing if no active providers
        
        // Find the currently selected provider in the active list
        if let currentIndex = activeProviders.firstIndex(where: { $0.id == selectedService.id }) {
            let nextIndex = (currentIndex + 1) % activeProviders.count
            // Update selectedService based on the next provider's ID
            if let nextAIService = AIService.allCases.first(where: { $0.rawValue == activeProviders[nextIndex].id }) {
                 selectedService = nextAIService
            } else { // Handle the case where the next active provider is a custom one not in AIService enum
                 // You might want to handle this differently, e.g., keep track of selected provider by ID directly
                 // For now, we'll stick to AIService for selectedService state.
                 // A more robust solution would be to store selected provider ID and use it to find the provider in settings.activeProviders
                 print("Could not find matching AIService for next provider ID: \(activeProviders[nextIndex].id)")
                 // As a fallback, maybe select the first active built-in provider or settings
                 if let firstBuiltIn = settings.allBuiltInProviders.first(where: { settings.activeProviderIds.contains($0.id) && $0.url != nil }) {
                      if let firstAIService = AIService.allCases.first(where: { $0.rawValue == firstBuiltIn.id }) {
                           selectedService = firstAIService
                      }
                 } else if settings.activeProviderIds.contains(AIService.settings.rawValue) {
                      selectedService = .settings
                 }
            }
        } else { // If current selectedService is not in the active list (e.g., was deactivated)
            // Select the first active provider (if any)
            if let firstActiveProvider = activeProviders.first {
                 if let firstAIService = AIService.allCases.first(where: { $0.rawValue == firstActiveProvider.id }) {
                      selectedService = firstAIService
                 } else if firstActiveProvider.id == AIService.settings.rawValue {
                      selectedService = .settings
                 } else { // Handle custom provider as the first active one
                      // Again, a more robust solution needed for custom providers in selectedService state
                      print("First active provider is a custom one, cannot set selectedService directly.")
                      // Fallback similar to above
                       if let firstBuiltIn = settings.allBuiltInProviders.first(where: { settings.activeProviderIds.contains($0.id) && $0.url != nil }) {
                            if let firstAIService = AIService.allCases.first(where: { $0.rawValue == firstBuiltIn.id }) {
                                 selectedService = firstAIService
                            }
                       } else if settings.activeProviderIds.contains(AIService.settings.rawValue) {
                            selectedService = .settings
                       }
                 }
            }
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
    ContentView(window: nil, windowManager: WindowManager())
}
