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
    var body: some View {
        HStack {
            Text("Overly")
                .foregroundColor(.white)
                .font(.headline)
            Spacer() // Pushes the text to the left
        }
        .padding(.horizontal) // Add horizontal padding
        .frame(height: 30) // Set a fixed height for the title bar
        .background(Color.black) // Set the background color to black
    }
}

struct ContentView: View {
    @Binding var shouldLoad: Bool // Accept the binding from OverlyApp

    var body: some View {
        VStack(spacing: 0) { // Use a VStack with no spacing
            CustomTitleBar() // Add our custom title bar at the top
            // Pass the binding down to WebView
            WebView(url: URL(string: "https://chatgpt.com")!, shouldLoad: $shouldLoad)
        }
    }
}

#Preview {
    // Provide a dummy binding for preview
    ContentView(shouldLoad: .constant(false))
}
