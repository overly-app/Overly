//
//  NativeChatView.swift
//  Overly
//
//  Created by AI Assistant on 1/27/25.
//

import SwiftUI

struct NativeChatView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "message.badge")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                Text("Native Chat")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Use the AI sidebar for chat functionality")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Text("Press ⌘⇧A to toggle the AI sidebar")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

#Preview {
    NativeChatView()
} 