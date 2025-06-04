//
//  ContentView.swift
//  Overly
//
//  Created by hypackel on 5/20/25.
//

import SwiftUI
import WebKit
import SettingsKit

enum AIService: String, CaseIterable, Identifiable {
    case chatgpt = "ChatGPT"
    case gemini = "Gemini"
    case poe = "Poe"
    case perplexity = "Perplexity"
    case copilot = "Copilot"
    case claude = "Claude"
    case t3chat = "T3 Chat"
    case settings = "Settings"

    var id: String { self.rawValue }

    var url: URL? {
        switch self {
        case .chatgpt: return URL(string: "https://chatgpt.com")!
        case .gemini: return URL(string: "https://gemini.google.com")!
        case .poe: return URL(string: "https://poe.com")!
        case .perplexity: return URL(string: "https://perplexity.ai")!
        case .copilot: return URL(string: "https://copilot.microsoft.com")!
        case .claude: return URL(string: "https://claude.ai")!
        case .t3chat: return URL(string: "https://t3.chat")!
        case .settings: return nil
        }
    }

    var iconName: String {
        switch self {
        case .chatgpt: return "openai" // Use the actual asset name
        case .gemini: return "gemini" // Use the actual asset name
        case .poe: return "poe" // Use the actual asset name
        case .perplexity: return "link" // Using system icon for now
        case .copilot: return "link" // Using system icon for now
        case .claude: return "link" // Using system icon for now
        case .t3chat: return "link" // Using system icon for now
        case .settings: return "gearshape"
        }
    }
}

// Progress bar component for WebView loading
struct ProgressBarView: View {
    @Binding var isLoading: Bool
    @State private var progress: Double = 0.0
    @State private var animationTimer: Timer?
    @State private var isVisible: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ZStack(alignment: .leading) {
                    // Transparent background
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 3)
                    
                    // White progress indicator
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: progress * geometry.size.width, height: 3)
                        .opacity(isVisible ? 1.0 : 0.0)
                        .animation(.easeInOut(duration: 0.2), value: isVisible)
                }
            }
        }
        .frame(height: 3)
        .onChange(of: isLoading) { oldValue, newValue in
            if newValue {
                startAnimation()
            } else {
                // Complete the progress bar to 100% first
                completeAnimation()
            }
        }
    }
    
    private func startAnimation() {
        progress = 0.0
        isVisible = true
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if progress < 0.95 {
                // Calculate increment based on progress (speeds up as it gets closer)
                let baseIncrement: Double = 0.015
                let accelerationFactor = 1.0 + (progress * 2.0) // Speed increases as progress increases
                let increment = baseIncrement * accelerationFactor
                
                withAnimation(.linear(duration: 0.1)) {
                    progress += increment
                }
            }
        }
    }
    
    private func completeAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        
        // Keep visible and smoothly complete the remaining progress to 100%
        withAnimation(.linear(duration: 0.8)) {
            progress = 1.0
        }
        
        // Hold at 100% for a moment to show completion, then hide
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.1)) {
                isVisible = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                progress = 0.0
            }
        }
    }
    
    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
}

// Custom view for the dropdown menu content
struct ServiceDropdownView: View {
    @Binding var selectedProvider: ChatProvider? // Change to ChatProvider?
    var dismiss: () -> Void
    @ObservedObject var settings: AppSettings // Observe AppSettings
    var windowManager: WindowManager? // Add WindowManager parameter

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Iterate through active web providers
            ForEach(settings.activeProviders.filter { $0.url != nil }) {
                provider in
                Button(action: {
                    selectedProvider = provider // Set the selected provider directly
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
                            // Use systemName for SF Symbols (should not happen for web providers)
                             Image(systemName: provider.iconName)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20)
                        } else {
                            // Use asset catalog or placeholder
                            Image(provider.iconName) // Assuming iconName is a valid asset or placeholder
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
                .background(selectedProvider?.id == provider.id ? Color.accentColor.opacity(0.2) : Color.clear) // Compare IDs
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
            
            // Add Settings option using SettingsLink directly
            SettingsLink {
                HStack {
                    Image(systemName: "gearshape")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                    Text("Settings")
                    Spacer()
                }
                .contentShape(Rectangle()) // Make the entire row tappable
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.clear)
                .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .onTapGesture {
                // Hide the floating window when settings is opened
                windowManager?.hideCustomWindow()
                dismiss() // Close the dropdown when settings is tapped
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
    @Binding var selectedProvider: ChatProvider? // Change to ChatProvider?
    @ObservedObject var settings: AppSettings // Observe AppSettings
    var windowManager: WindowManager? // Add WindowManager parameter
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
                // Display icon for the selected provider
                if let provider = selectedProvider {
                    if let favicon = settings.faviconImage(for: provider) {
                        favicon
                             .resizable()
                             .aspectRatio(contentMode: .fit)
                             .frame(width: 20, height: 20)
                    } else if provider.isSystemImage {
                         Image(systemName: provider.iconName)
                              .resizable()
                              .frame(width: 20, height: 20)
                    } else {
                         Image(provider.iconName)
                              .resizable()
                              .frame(width: 20, height: 20)
                    }
                } else { // Fallback if no provider is selected
                    Image(systemName: "questionmark.circle")
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
                ServiceDropdownView(selectedProvider: $selectedProvider, dismiss: { // Pass selectedProvider binding
                    // Dismiss dropdown when an item is selected
                    showingDropdown = false
                    closeDropdownWorkItem?.cancel()
                    // The view switching logic is now handled by the .onChange in ContentView
                }, settings: settings, windowManager: windowManager) // Pass AppSettings instance and WindowManager
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

    @State private var selectedProvider: ChatProvider? // Change to ChatProvider?
    @State private var isLoading: Bool = false // Add loading state
    
    // Add the AppStorage variable back inside the struct
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false

    var body: some View {
        // Check if onboarding is completed
        if hasCompletedOnboarding {
            // Original content when onboarding is done
            VStack(spacing: 0) { // Use a VStack with no spacing for the main content area
                // Always display the custom title bar
                CustomTitleBar(window: window, selectedProvider: $selectedProvider, settings: settings, windowManager: windowManager) // Pass selectedProvider binding and settings
                
                // Add progress bar between header and WebView
                ProgressBarView(isLoading: $isLoading)
                
                // Display the WebView - settings are now handled by SettingsKit
                if let provider = selectedProvider, let url = provider.url {
                    WebView(url: url, isLoading: $isLoading)
                } else {
                    // Handle case where no provider is selected or selected provider has no URL
                     Color.clear // Or some placeholder view
                }
            }
            .onAppear {
                // When the view appears, pass the actions up to the WindowManager via the window
                if let window = window as? BorderlessWindow {
                     window.reloadAction = { self.reloadWebView() }
                     window.nextServiceAction = { self.selectNextService() }
                 }
                 // Initialize selectedProvider to the first active provider
                 if selectedProvider == nil { // Only initialize if not already set
                     if let firstActiveWebProvider = settings.activeProviders.first(where: { $0.url != nil }) {
                          selectedProvider = firstActiveWebProvider
                     }
                }
                
                // Fetch favicons for active built-in providers on app launch
                for provider in settings.allBuiltInProviders where settings.activeProviderIds.contains(provider.id) && provider.url != nil && settings.faviconCache[provider.id] == nil {
                     Task {
                          await settings.fetchFavicon(for: provider)
                      }
                }
            }
        } else {
            // Display OnboardingView if onboarding is not complete
            OnboardingView()
        }
    }
    
    // Function to find the next service in the active providers list and switch to it
    // Internal so WindowManager can call it directly
    internal func selectNextService() {
        let activeProviders = settings.activeProviders // Get current active providers
        guard !activeProviders.isEmpty else { return } // Do nothing if no active providers
        
        // Find the currently selected provider in the active list
        if let currentProvider = selectedProvider, let currentIndex = activeProviders.firstIndex(where: { $0.id == currentProvider.id }) {
            let nextIndex = (currentIndex + 1) % activeProviders.count
            selectedProvider = activeProviders[nextIndex]
        } else { // If no provider is currently selected or selected provider is not in the active list
            // Select the first active provider (if any)
            selectedProvider = activeProviders.first
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
    ContentView(window: nil, windowManager: WindowManager()) // Pass dummy windowManager
}
