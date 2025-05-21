import SwiftUI
import WebKit

struct WebView: NSViewRepresentable {
    let url: URL
    @Binding var shouldLoad: Bool // Accept the binding

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        // Perform an initial load when the view is created
        let request = URLRequest(url: url)
        webView.load(request)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Load the request every time the binding changes.
        // updateNSView is called when the binding value changes.
        let request = URLRequest(url: url)
        nsView.load(request)
         // The updateNSView method is called when relevant state or bindings change.
         // We don't need explicit logic to check for changes or a previous value here,
         // as SwiftUI manages when updateNSView is invoked based on the bindings.
         // The load request might happen more often than strictly needed,
         // but it ensures the content is loaded when the window is shown.
    }

    // Removed incorrect body(content:) function, makeCoordinator, Coordinator, etc.
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