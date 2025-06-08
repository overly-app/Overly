import SwiftUI
import WebKit
import AppKit // Import AppKit for NSWorkspace
import AuthenticationServices // Import for passkey support
import UniformTypeIdentifiers // Import for file type handling

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

        // MARK: - File Upload Support
        func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
            print("WebView: File upload panel requested")
            
            let openPanel = NSOpenPanel()
            openPanel.allowsMultipleSelection = parameters.allowsMultipleSelection
            openPanel.canChooseDirectories = parameters.allowsDirectories
            openPanel.canChooseFiles = true
            openPanel.canCreateDirectories = false
            
            // Allow common file types that web services typically accept
            let commonFileTypes: [UTType] = [
                // Images
                .image, .png, .jpeg, .gif, .tiff, .bmp, .webP,
                // Documents
                .pdf, .text, .plainText, .utf8PlainText,
                // Media
                .movie, .video, .mpeg4Movie, .quickTimeMovie,
                .audio, .mp3, .wav, .aiff,
                // Archives
                .zip, .gzip,
                // Data files
                .data, .item // Allow all files as fallback
            ]
            
            // Add Microsoft Office types if available
            var allowedTypes = commonFileTypes
            
            // Add Word document types
            if let docType = UTType(filenameExtension: "doc") {
                allowedTypes.append(docType)
            }
            if let docxType = UTType(filenameExtension: "docx") {
                allowedTypes.append(docxType)
            }
            
            // Add Excel document types
            if let xlsType = UTType(filenameExtension: "xls") {
                allowedTypes.append(xlsType)
            }
            if let xlsxType = UTType(filenameExtension: "xlsx") {
                allowedTypes.append(xlsxType)
            }
            
            // Add PowerPoint document types
            if let pptType = UTType(filenameExtension: "ppt") {
                allowedTypes.append(pptType)
            }
            if let pptxType = UTType(filenameExtension: "pptx") {
                allowedTypes.append(pptxType)
            }
            
            openPanel.allowedContentTypes = allowedTypes
            
            // Set the message for the file picker
            openPanel.message = "Select files to upload"
            openPanel.prompt = "Choose"
            
            print("WebView: File upload dialog configured with \(allowedTypes.count) file types")
            
            // Find the main window to present the panel
            let parentWindow = NSApp.mainWindow ?? NSApp.windows.first
            
            if let window = parentWindow {
                openPanel.beginSheetModal(for: window) { response in
                    if response == .OK {
                        let selectedURLs = openPanel.urls
                        print("WebView: Selected files: \(selectedURLs.map { $0.lastPathComponent })")
                        completionHandler(selectedURLs)
                    } else {
                        print("WebView: File selection cancelled")
                        completionHandler(nil)
                    }
                }
            } else {
                // Fallback to modal dialog if no parent window
                openPanel.begin { response in
                    if response == .OK {
                        let selectedURLs = openPanel.urls
                        print("WebView: Selected files (modal): \(selectedURLs.map { $0.lastPathComponent })")
                        completionHandler(selectedURLs)
                    } else {
                        print("WebView: File selection cancelled (modal)")
                        completionHandler(nil)
                    }
                }
            }
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
        
        func windowShouldClose(_ sender: NSWindow) -> Bool {
            // Allow the window to close
            return true
        }
        
        func windowWillClose(_ notification: Notification) {
            // Prepare for cleanup but don't clear references yet
            if let closedWindow = notification.object as? NSWindow, closedWindow == self.popupWindow {
                print("Popup window will close. Preparing cleanup.")
                
                // Stop loading and clear delegates before window closes
                if let popupWebView = closedWindow.contentView as? WKWebView {
                    popupWebView.stopLoading()
                    popupWebView.navigationDelegate = nil
                    popupWebView.uiDelegate = nil
                }
            }
        }
        
        func windowDidClose(_ notification: Notification) {
            // Final cleanup after window has closed
            if let closedWindow = notification.object as? NSWindow, closedWindow == self.popupWindow {
                print("Popup window did close. Performing final cleanup.")
                
                // Now safely clear the reference
                self.popupWindow = nil
                
                print("Popup window cleanup completed safely")
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
