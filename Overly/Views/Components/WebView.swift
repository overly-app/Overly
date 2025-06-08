import SwiftUI
import WebKit
import AppKit // Import AppKit for NSWorkspace
import AuthenticationServices // Import for passkey support
import UniformTypeIdentifiers // Import for file type handling

struct WebView: NSViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool // Add binding for loading state

    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(self)
    }

    func makeNSView(context: Context) -> WKWebView {
        print("WebView: makeNSView called with URL: \(url)")
        
        // Use the centralized configuration
        let configuration = WebViewConfiguration.createConfiguration()
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        
        // Configure the web view using the centralized configuration
        WebViewConfiguration.configureWebView(webView)
        
        // Perform an initial load when the view is created
        let request = URLRequest(url: url)
        webView.load(request)
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        print("WebView: updateNSView called with URL: \(url)")
        // Load the new URL when the url property changes
        let request = URLRequest(url: url)
        nsView.load(request)
    }
}

// Helper view to access the WKWebView instance from makeNSView
struct WebViewAccessor: NSViewRepresentable {
    let webView: (WKWebView?) -> Void

    func makeNSView(context: Context) -> NSView {
        // Return a dummy view, we just need access to the context
        let view = NSView()
        // Find the WKWebView instance in the hierarchy
        if let webView = view.findSubview(ofType: WKWebView.self) {
            self.webView(webView)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Find the WKWebView instance in the hierarchy during updates
        if let webView = nsView.findSubview(ofType: WKWebView.self) {
             self.webView(webView)
         }
    }
} 
