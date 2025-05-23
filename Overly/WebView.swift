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
        webView.uiDelegate = context.coordinator // Set the coordinator as the UI delegate
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
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, NSWindowDelegate {
        var parent: WebView
        var popupWindow: NSWindow? // Add a property to hold the popup window

        init(_ parent: WebView) {
            self.parent = parent
        }

        // Decide policy for navigation
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }

            // Check if the URL is a redirect back to the main application's expected URL
            // You might need to adjust this URL comparison based on the actual redirect URL from Google/Claude
            if url.absoluteString.starts(with: parent.url.absoluteString) {
                 print("Allowing navigation back to main application URL in popup: \(url.absoluteString)")
                 decisionHandler(.allow)
            } else if navigationAction.navigationType == .linkActivated && navigationAction.targetFrame == nil {
                 // Existing logic: Open external links in the default browser
                 NSWorkspace.shared.open(url)
                 // Optionally hide the application window if needed, but maybe not for a popup redirect
                 // NSApplication.shared.mainWindow?.orderOut(nil)
                 decisionHandler(.cancel)
            } else {
                 // Allow other types of navigation within the WebView (including the initial Google login page load)
                 decisionHandler(.allow)
            }
        }

        // MARK: - Handling New Windows (Popups)
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            // Create a new WKWebView for the popup with the provided configuration
            let popupWebView = WKWebView(frame: .zero, configuration: configuration)
            
            // Create a new window for the popup
            let newWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 800), // Adjust size as needed
                styleMask: [.titled, .closable, .resizable], // Provide standard window controls
                backing: .buffered,
                defer: true
            )
            newWindow.center() // Center the new window
            newWindow.level = .modalPanel // Set the window level to appear above floating windows
            
            // Create a vertical stack view to hold the web view and the button
            let stackView = NSStackView()
            stackView.orientation = .vertical
            stackView.distribution = .fill
            stackView.spacing = 10 // Add some spacing between items
            
            // Add the popup web view to the stack view
            stackView.addArrangedSubview(popupWebView)
            
            // Create and configure the close app button
            let closeButton = NSButton(title: "Showing One Moment Please, close app and relaunch (this is a known issue with claude login)", target: self, action: #selector(closeApp))
            stackView.addArrangedSubview(closeButton)
            
            // Set the stack view as the content view of the new window
            newWindow.contentView = stackView
            
            // Set constraints for the web view to fill the available space
            popupWebView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                popupWebView.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
                popupWebView.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
                // The top and bottom constraints will be managed by the stack view's distribution
            ])
            
            // Set constraints for the button (optional, stack view handles basic layout)
            closeButton.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                closeButton.centerXAnchor.constraint(equalTo: stackView.centerXAnchor)
            ])

            // Set the delegate for the popup web view
            popupWebView.navigationDelegate = self
            popupWebView.uiDelegate = self // Ensure the new web view also has the UI delegate set

            newWindow.makeKeyAndOrderFront(nil) // Show the new window

            // Assign the new window to the popupWindow property and set its delegate
            self.popupWindow = newWindow
            newWindow.delegate = self

            print("Created new web view for popup and showing in a new window with close button")

            return popupWebView
        }

        // Selector to terminate the application
        @objc func closeApp() {
            print("Close app button clicked. Terminating application.")
            NSApplication.shared.terminate(nil)
        }

        // MARK: - WKNavigationDelegate Methods
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("WebView did finish navigation to: \(webView.url?.absoluteString ?? "unknown")")
            // We can add logic here later to dismiss the popup if the URL indicates successful login
        }

        // MARK: - NSWindowDelegate Methods
        
        func windowWillClose(_ notification: Notification) {
            // Clean up the popup window and web view when the window is closed
            if let closedWindow = notification.object as? NSWindow, closedWindow == self.popupWindow {
                print("Popup window will close. Performing cleanup.")
                
                // Explicitly invalidate the web view's configuration
                if let popupWebView = closedWindow.contentView as? WKWebView {
                     // Stop any loading content
                    popupWebView.stopLoading()
                    // Explicitly nil out delegates to break potential cycles
                    popupWebView.navigationDelegate = nil
                    popupWebView.uiDelegate = nil
                }

                self.popupWindow?.contentView = nil // Release the web view from the window
                self.popupWindow = nil // Release the window reference
                // Any other necessary cleanup can go here
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
