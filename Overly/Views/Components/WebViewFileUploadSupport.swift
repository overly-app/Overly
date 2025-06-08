import SwiftUI
import WebKit
import AppKit
import UniformTypeIdentifiers

extension WebViewCoordinator {
    
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
} 