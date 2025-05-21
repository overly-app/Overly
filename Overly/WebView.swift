import SwiftUI
import WebKit

struct WebView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        
        let webView = WKWebView()
        // Perform an initial load when the view is created
        let request = URLRequest(url: url)
        webView.load(request)
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Required by NSViewRepresentable, but no updates needed here
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