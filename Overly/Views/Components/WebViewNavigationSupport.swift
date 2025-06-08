import SwiftUI
import WebKit
import AppKit
import AuthenticationServices

extension WebViewCoordinator {
    
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
        if url.absoluteString.starts(with: parent.url.absoluteString) {
             print("Allowing navigation back to main application URL: \(url.absoluteString)")
             decisionHandler(.allow)
        } else if navigationAction.navigationType == .linkActivated && navigationAction.targetFrame == nil {
             // Check if this is an authentication flow that should stay within the app
             let authenticationDomains = [
                 "accounts.google.com",
                 "oauth2.googleapis.com", 
                 "myaccount.google.com",
                 "accounts.youtube.com",
                 "gemini.google.com"
             ]
             
             let shouldStayInApp = authenticationDomains.contains { domain in
                 url.host?.lowercased().contains(domain.lowercased()) == true
             }
             
             if shouldStayInApp {
                 print("Allowing authentication flow within app for: \(url.absoluteString)")
                 decisionHandler(.allow)
             } else {
                 // Open external links in the default browser
                 NSWorkspace.shared.open(url)
                 decisionHandler(.cancel)
             }
        } else {
             // Allow other types of navigation within the WebView
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
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 800),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: true
        )
        newWindow.center()
        newWindow.level = .modalPanel
        newWindow.title = "Login"
        
        // Set the popup web view directly as the content view
        newWindow.contentView = popupWebView
        
        // Set the delegate for the popup web view
        popupWebView.navigationDelegate = self
        popupWebView.uiDelegate = self

        newWindow.makeKeyAndOrderFront(nil)

        // Assign the new window to the popupWindow property and set its delegate
        self.popupWindow = newWindow
        newWindow.delegate = self

        print("Created new web view for popup")

        return popupWebView
    }
} 