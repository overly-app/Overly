import SwiftUI
import WebKit
import AuthenticationServices

class WebViewConfiguration {
    static func createConfiguration() -> WKWebViewConfiguration {
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
        let webAuthnScript = createWebAuthnScript()
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
        
        return configuration
    }
    
    static func configureWebView(_ webView: WKWebView) {
        // Configure for better passkey support
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = false
        
        // Use a more specific Safari user agent that supports WebAuthn
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"
        
        // Configure for credential access
        if #available(macOS 12.0, *) {
            webView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        }
    }
    
    private static func createWebAuthnScript() -> String {
        return """
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
    }
} 