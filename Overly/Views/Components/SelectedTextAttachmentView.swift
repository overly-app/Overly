//
//  SelectedTextAttachmentView.swift
//  Overly
//
//  Created by AI Assistant on 1/27/25.
//

import SwiftUI

struct SelectedTextAttachmentView: View {
    let attachment: SelectedTextAttachment
    let onRemove: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                // AI icon
                HStack(spacing: 6) {
                    Text("AI")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 16, height: 16)
                        .background(Color.gray.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(attachment.source)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                        
                        Text("Selected Text")
                            .font(.system(size: 9))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // Close button (appears on hover)
                if isHovering {
                    Button(action: onRemove) {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.gray)
                            .frame(width: 14, height: 14)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Selected text content
            Text(attachment.text)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(.leading, 22) // Align with the text above
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(red: 0.1, green: 0.1, blue: 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onHover { hovering in
            isHovering = hovering
        }
    }
} 