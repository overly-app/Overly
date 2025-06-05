//
//  ContentView.swift
//  Overly
//
//  Created by hypackel on 5/20/25.
//

import SwiftUI
import WebKit

struct ContentView: View {
    let window: NSWindow?
    @ObservedObject var windowManager: WindowManager
    @ObservedObject var settings = AppSettings.shared
    @State private var selectedProvider: ChatProvider?
    @State private var isLoading: Bool = false
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @State private var showCommandPalette: Bool = false

    var body: some View {
        if hasCompletedOnboarding {
            ZStack {
                // Main content
                VStack(spacing: 0) {
                    CustomTitleBar(
                        window: window,
                        selectedProvider: $selectedProvider,
                        settings: settings,
                        windowManager: windowManager
                    )
                    
                    // WebView with overlaid progress bar
                    ZStack(alignment: .top) {
                        if let provider = selectedProvider, let url = provider.url {
                            WebView(url: url, isLoading: $isLoading)
                        } else {
                            Color.clear
                        }
                        
                        // Progress bar overlaid at the top
                        ProgressBarView(isLoading: $isLoading)
                    }
                }
                .onAppear {
                    setupWindow()
                    initializeSelectedProvider()
                    fetchFaviconsForActiveProviders()
                }
                
                // Command palette overlay
                CommandPalette(isVisible: $showCommandPalette, onNavigate: navigateWebView)
            }
            // TEMPORARILY DISABLED: "/" key command palette in window context
            // Uncomment the block below to re-enable "/" command palette when window is focused
            /*
            .onKeyPress(.init("/")) {
                // Use the shared method to show command palette
                showCommandPaletteView()
                return .handled
            }
            */
        } else {
            OnboardingView()
        }
    }
    
    private func setupWindow() {
        if let window = window as? BorderlessWindow {
            window.reloadAction = { self.reloadWebView() }
            window.nextServiceAction = { self.selectNextService() }
        }
    }
    
    private func initializeSelectedProvider() {
        if selectedProvider == nil {
            selectedProvider = settings.startupProvider
        }
    }
    
    private func fetchFaviconsForActiveProviders() {
        for provider in settings.allBuiltInProviders where settings.activeProviderIds.contains(provider.id) && provider.url != nil && settings.faviconCache[provider.id] == nil {
            Task {
                await settings.fetchFavicon(for: provider)
            }
        }
    }
    
    internal func selectNextService() {
        let activeProviders = settings.activeProviders
        guard !activeProviders.isEmpty else { return }
        
        if let currentProvider = selectedProvider, let currentIndex = activeProviders.firstIndex(where: { $0.id == currentProvider.id }) {
            let nextIndex = (currentIndex + 1) % activeProviders.count
            selectedProvider = activeProviders[nextIndex]
        } else {
            selectedProvider = activeProviders.first
        }
    }
    
    internal func reloadWebView() {
        if let webView = window?.contentView?.findSubview(ofType: WKWebView.self) {
            webView.reload()
        }
    }
    
    // Navigation handler for command palette
    private func navigateWebView(to url: URL) {
        if let webView = window?.contentView?.findSubview(ofType: WKWebView.self) {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
    
    // Shared method to show command palette
    private func showCommandPaletteView() {
        windowManager.focusCustomWindow()
        showCommandPalette = true
    }
}

#Preview {
    ContentView(window: nil, windowManager: WindowManager())
} 