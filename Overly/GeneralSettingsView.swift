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
    
    // Access the AppStorage variable to reset onboarding
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("General Settings")
                .font(.largeTitle)
            
            // Bind Toggle directly to the settings property
            Toggle("Show in Dock", isOn: $settings.showInDock)
                .onChange(of: settings.showInDock) { newValue in
                    // Explicitly set the activation policy when the toggle changes
                    if newValue {
                        NSApp.setActivationPolicy(.regular)
                    } else {
                        NSApp.setActivationPolicy(.accessory)
                        // Explicitly activate the application when hiding the dock icon
                        // This might be necessary for the change to take effect immediately.
                        NSApp.activate(ignoringOtherApps: true)
                    }
                }
            
            Divider() // Add a separator
            
            // Button to reset onboarding
            Button("Reset Onboarding") {
                hasCompletedOnboarding = false // Set the flag to false
            }
            .padding(.top)
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading) // Align content to top leading
        // Remove the onReceive as the onChange on the Toggle is more direct
        //.onReceive(settings.objectWillChange) { _ in
        //    if settings.showInDock {
        //        NSApp.setActivationPolicy(.regular)
        //    } else {
        //        NSApp.setActivationPolicy(.accessory)
        //    }
        //}
        .onAppear {
            // Set the initial policy on appear
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
