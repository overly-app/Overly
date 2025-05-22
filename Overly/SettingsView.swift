//
//  SettingsView.swift
//  Overly
//
//  Created by hypackel on 5/22/25.
//

import SwiftUI
import AppKit

// Settings categories
enum SettingsCategory: String, CaseIterable, Identifiable {
    case general = "General"
    case providers = "Providers"

    var id: String { self.rawValue }
}

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared // Use the shared settings instance
    
    // Keep a reference to the WindowManager (optional, might not be needed directly here anymore)
    weak var windowManager: WindowManager? // Use weak to avoid retain cycles
    
    @State private var selectedCategory: SettingsCategory? = .general // State for selected sidebar item

    var body: some View {
        NavigationView { // Use NavigationView for sidebar layout
            // Sidebar
            List(SettingsCategory.allCases, selection: $selectedCategory) { category in
                NavigationLink(destination: destinationView(for: category)) {
                    Label(category.rawValue, systemImage: iconName(for: category))
                }
            }
            .listStyle(SidebarListStyle()) // Apply macOS sidebar style
            .frame(minWidth: 150) // Set minimum width for the sidebar
            .navigationTitle("Settings") // Set title for the sidebar
            
            // Detail view (content area)
            // Display a default view if no category is selected
             if let selectedCategory = selectedCategory {
                 destinationView(for: selectedCategory) // Display the selected category's view
             } else {
                 // Default view when no category is selected
                 Text("Select a category")
                     .foregroundColor(.secondary)
             }
        }
        .frame(minWidth: 500, minHeight: 300) // Set minimum size for the settings window
    }
    
    // Helper to determine the destination view for a category
    @ViewBuilder
    private func destinationView(for category: SettingsCategory) -> some View {
        switch category {
        case .general:
            GeneralSettingsView(settings: settings) // Pass the settings object
        case .providers:
            ProviderSettingsView(settings: settings) // Pass the settings object
        }
    }
    
    // Helper to determine the sidebar icon for a category
    private func iconName(for category: SettingsCategory) -> String {
        switch category {
        case .general: return "gearshape"
        case .providers: return "puzzlepiece"
        }
    }
}

// Remove the duplicate definitions for ProviderRowView and AddProviderView
// These should now be in ProviderSettingsView.swift

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(windowManager: nil)
    }
} 