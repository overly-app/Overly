//
//  AIChatSidebarManager.swift
//  Overly
//
//  Created by AI Assistant on 1/27/25.
//

import SwiftUI

// Shared state manager for AI Chat Sidebar
class AIChatSidebarManager: ObservableObject {
    static let shared = AIChatSidebarManager()
    
    @Published var displayMode: ChatDisplayMode = .sidebar
    @Published var floatingWindow: NSWindow?
    @Published var windowDelegate: FloatingWindowDelegate?
    
    private init() {}
    
    enum ChatDisplayMode: String, CaseIterable {
        case sidebar = "Sidebar"
        case floating = "Floating"
        
        var icon: String {
            switch self {
            case .sidebar: return "sidebar.left"
            case .floating: return "macwindow"
            }
        }
    }
    
    // Method to handle Cmd+E shortcut based on current display mode
    func handleToggleShortcut(sidebarVisibility: Binding<Bool>) {
        switch displayMode {
        case .sidebar:
            // Toggle sidebar visibility
            withAnimation(.easeInOut(duration: 0.15)) {
                sidebarVisibility.wrappedValue.toggle()
            }
        case .floating:
            // Focus the floating window if it exists
            if let window = floatingWindow {
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}

// Floating window delegate
class FloatingWindowDelegate: NSObject, NSWindowDelegate {
    let onClose: () -> Void
    
    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        super.init()
    }
    
    func windowWillClose(_ notification: Notification) {
        onClose()
    }
} 