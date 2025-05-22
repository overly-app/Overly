import SwiftUI
import WebKit
import AppKit // Import AppKit for NSWorkspace

struct WebView: NSViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> WKWebView {
        print("WebView: makeNSView called with URL: \(url)")
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator // Set the coordinator as the navigation delegate
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

    // Coordinator to act as the WKNavigationDelegate
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView

        init(_ parent: WebView) {
            self.parent = parent
        }

        // Decide policy for navigation
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Check if the navigation is a link click and not the main frame (to avoid opening redirects in external browser)
            if navigationAction.navigationType == .linkActivated && navigationAction.targetFrame == nil {
                 // Open the URL in the default browser
                 if let url = navigationAction.request.url {
                     NSWorkspace.shared.open(url)
                     // Hide the application window
                     NSApplication.shared.mainWindow?.orderOut(nil)
                 }
                 // Cancel the navigation within the WebView
                 decisionHandler(.cancel)
            } else {
                 // Allow other types of navigation within the WebView
                 decisionHandler(.allow)
            }
        }
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

// Helper extension to find a subview of a specific type
extension NSView {
    func findSubview<T: NSView>(ofType type: T.Type) -> T? {
        for subview in subviews {
            if let targetView = subview as? T {
                return targetView
            }
            if let targetView = subview.findSubview(ofType: type) {
                return targetView
            }
        }
        return nil
    }
} 
