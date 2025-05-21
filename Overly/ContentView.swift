//
//  ContentView.swift
//  Overly
//
//  Created by hypackel on 5/20/25.
//

import SwiftUI
import WebKit

// Custom view for the title bar
struct CustomTitleBar: View {
    let window: NSWindow? // Add a property to hold the window reference

    var body: some View {
        HStack {
            Text("Overly")
                .foregroundColor(.white)
                .font(.headline)
            Spacer() // Pushes the text to the left
        }
        .padding(.horizontal) // Add horizontal padding
        .frame(height: 30) // Set a fixed height for the title bar
        .background(.thinMaterial) // Set the background material
        .gesture(TapGesture(count: 2).onEnded({
            // Handle double-click to zoom
            window?.zoom(nil)
        }))
    }
}

struct ContentView: View {
    let window: NSWindow? // Add a property to hold the window reference

    var body: some View {
        VStack(spacing: 0) { // Use a VStack with no spacing
            CustomTitleBar(window: window) // Add our custom title bar at the top
            // Pass the binding down to WebView
            WebView(url: URL(string: "https://chatgpt.com")!)
        }
    }
}

#Preview {
    // Provide a dummy binding for preview
    ContentView(window: nil)
}
