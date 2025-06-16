import SwiftUI
import WebKit
import AppKit

// Coordinator to act as the WKNavigationDelegate
class WebViewCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate, NSWindowDelegate {
    var parent: WebView
    var popupWindow: NSWindow? // Add a property to hold the popup window
    private var selectionTimer: Timer?

    init(_ parent: WebView) {
        self.parent = parent
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
        
        // Inject text selection detection script
        let selectionScript = """
        function checkSelection() {
            const selection = window.getSelection();
            const selectedText = selection.toString().trim();
            
            if (selectedText.length > 0) {
                window.webkit.messageHandlers.textSelection.postMessage({
                    text: selectedText,
                    source: window.location.hostname || 'Unknown'
                });
            } else {
                // Clear selection when text is deselected
                window.webkit.messageHandlers.textSelection.postMessage({
                    text: '',
                    source: ''
                });
            }
        }
        
        document.addEventListener('mouseup', checkSelection);
        document.addEventListener('keyup', checkSelection);
        document.addEventListener('selectionchange', checkSelection);
        
        console.log('Text selection detection initialized');
        """
        
        webView.evaluateJavaScript(selectionScript) { result, error in
            if let error = error {
                print("Text selection script error: \(error)")
            }
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