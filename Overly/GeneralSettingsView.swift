//
//  GeneralSettingsView.swift
//  Overly
//
//  Created by hypackel on 5/23/25.
//

import SwiftUI
import AppKit

struct GeneralSettingsView: View {
    @ObservedObject var settings = AppSettings.shared // Use the shared settings instance
    
    // We no longer need the localShowInDock state
    // @State private var localShowInDock: Bool = false // Local state for the toggle
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("General Settings")
                .font(.largeTitle)
            
            // Bind Toggle directly to the settings property
            Toggle("Show in Dock", isOn: $settings.showInDock) // Use standard binding
                // Removed .onChange here
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading) // Align content to top leading
        // Use .onReceive to react to changes in the ObservedObject
        .onReceive(settings.objectWillChange) { _ in
            // Update the application's activation policy when settings change
            // This publisher fires before the change, so the view will re-render
            // We can apply the policy change based on the new state after the render
            // However, setting the policy directly here is simpler and often works.
            if settings.showInDock {
                NSApp.setActivationPolicy(.regular)
            } else {
                NSApp.setActivationPolicy(.accessory)
            }
        }
        .onAppear {
            // No need to initialize local state from settings on appear anymore
            // We still might want to set the initial policy on appear
             if settings.showInDock {
                 NSApp.setActivationPolicy(.regular)
             } else {
                 NSApp.setActivationPolicy(.accessory)
             }
        }
    }
}

#Preview {
    GeneralSettingsView()
} 
