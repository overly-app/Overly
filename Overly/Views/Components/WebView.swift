import SwiftUI
import WebKit
import AppKit // Import AppKit for NSWorkspace
import AuthenticationServices // Import for passkey support

struct WebView: NSViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool // Add binding for loading state

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> WKWebView {
        print("WebView: makeNSView called with URL: \(url)")
        
        // Configure preferences for passkey support
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences = preferences
        
        // Enable WebAuthn (passkey) support with proper configuration
        if #available(macOS 13.0, *) {
            configuration.preferences.isElementFullscreenEnabled = true
            // Allow local authentication methods (Touch ID, Face ID, etc.)
            configuration.preferences.isFraudulentWebsiteWarningEnabled = true
        }
        
        // Enhanced configuration for iCloud Keychain integration
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        // Configure user content controller for better WebAuthn support
        let userContentController = WKUserContentController()
        
        // Add JavaScript to enhance WebAuthn compatibility
        let webAuthnScript = """
        // Enhanced WebAuthn support for passkeys
        (function() {
            console.log('WebAuthn enhancement script loaded');
            
            // Ensure navigator.credentials is available
            if (!navigator.credentials) {
                console.warn('navigator.credentials not available');
                return;
            }
            
            // Enhanced error handling for WebAuthn
            const originalCreate = navigator.credentials.create;
            const originalGet = navigator.credentials.get;
            
            navigator.credentials.create = function(options) {
                console.log('WebAuthn create called with options:', options);
                return originalCreate.call(this, options).catch(error => {
                    console.error('WebAuthn create error:', error);
                    throw error;
                });
            };
            
            navigator.credentials.get = function(options) {
                console.log('WebAuthn get called with options:', options);
                return originalGet.call(this, options).catch(error => {
                    console.error('WebAuthn get error:', error);
                    throw error;
                });
            };
            
            // Signal that WebAuthn is ready
            window.dispatchEvent(new Event('webauthn-ready'));
            console.log('WebAuthn enhancement complete');
        })();
        """
        
        let script = WKUserScript(source: webAuthnScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        userContentController.addUserScript(script)
        
        configuration.userContentController = userContentController
        
        // Enable credential management and autofill
        if #available(macOS 14.0, *) {
            configuration.preferences.isTextInteractionEnabled = true
        }
        
        // Enhanced WebAuthn configuration for passkeys
        configuration.processPool = WKProcessPool()
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator // Set the coordinator as the navigation delegate
        webView.uiDelegate = context.coordinator // Set the coordinator as the UI delegate
        
        // Configure for better passkey support
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = false
        
        // Use a more specific Safari user agent that supports WebAuthn
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"
        
        // Configure for credential access
        if #available(macOS 12.0, *) {
            webView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        }
        
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

        // MARK: - Enhanced Passkey Support
        @available(macOS 13.0, *)
        func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
            // Allow media capture for authentication if needed
            decisionHandler(.grant)
        }
        
        // Enhanced credential handling for passkeys
        func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            print("WebView: Navigation response for URL: \(response.response.url?.absoluteString ?? "unknown")")
            
            // Allow all responses to enable proper credential flow
            decisionHandler(.allow)
        }
        
        // Handle authentication challenges for passkeys
        func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            print("WebView: Received authentication challenge for: \(challenge.protectionSpace.host)")
            
            // For passkey authentication, use default handling
            if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
                completionHandler(.performDefaultHandling, nil)
            } else {
                // Let WebKit handle the authentication
                completionHandler(.performDefaultHandling, nil)
            }
        }

        // Decide policy for navigation
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }

            print("WebView: Navigation action for URL: \(url.absoluteString)")

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
            // Configure the popup web view configuration for passkey support
            let preferences = WKWebpagePreferences()
            preferences.allowsContentJavaScript = true
            configuration.defaultWebpagePreferences = preferences
            
            // Enable WebAuthn (passkey) support for popup as well
            if #available(macOS 13.0, *) {
                configuration.preferences.isElementFullscreenEnabled = true
                configuration.preferences.isFraudulentWebsiteWarningEnabled = true
            }
            
            // Enhanced popup configuration for credentials
            configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
            
            // Use the same process pool and data store for credential sharing
            configuration.processPool = webView.configuration.processPool
            configuration.websiteDataStore = webView.configuration.websiteDataStore
            
            // Add the same WebAuthn script to popup
            if let script = webView.configuration.userContentController.userScripts.first {
                configuration.userContentController.addUserScript(script)
            }
            
            // Create a new WKWebView for the popup with the provided configuration
            let popupWebView = WKWebView(frame: .zero, configuration: configuration)
            
            // Configure popup for better passkey support
            popupWebView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"
            
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
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            print("WebView did start provisional navigation to: \(webView.url?.absoluteString ?? "unknown")")
            DispatchQueue.main.async {
                self.parent.isLoading = true
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("WebView did finish navigation to: \(webView.url?.absoluteString ?? "unknown")")
            
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
            
            // Inject additional WebAuthn debugging if needed
            let debugScript = """
            console.log('Page loaded, WebAuthn available:', !!navigator.credentials);
            if (navigator.credentials && navigator.credentials.create) {
                console.log('WebAuthn create method available');
            }
            if (navigator.credentials && navigator.credentials.get) {
                console.log('WebAuthn get method available');
            }
            """
            
            webView.evaluateJavaScript(debugScript) { result, error in
                if let error = error {
                    print("WebAuthn debug script error: \(error)")
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("WebView navigation failed with error: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("WebView provisional navigation failed with error: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
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
