//
//  ResizableDivider.swift
//  Overly
//
//  Created by AI Assistant on 1/27/25.
//

import SwiftUI

struct ResizableDivider: View {
    @Binding var width: CGFloat
    let minWidth: CGFloat
    let maxWidth: CGFloat
    
    @State private var isDragging = false
    @State private var startLocation: CGPoint = .zero
    @State private var startWidth: CGFloat = 0
    @State private var isHovering = false
    
    var body: some View {
        Rectangle()
            .fill(Color.gray.opacity(isDragging ? 0.6 : (isHovering ? 0.4 : 0.3)))
            .frame(width: 2)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(coordinateSpace: .global)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            startLocation = value.startLocation
                            startWidth = width
                        }
                        
                        let deltaX = value.location.x - startLocation.x
                        let newWidth = startWidth - deltaX // Subtract because we're resizing from the right
                        width = max(minWidth, min(maxWidth, newWidth))
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    NSCursor.resizeLeftRight.set()
                } else if !isDragging {
                    NSCursor.arrow.set()
                }
            }
            .background(
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 8) // Larger hit area for easier grabbing
            )
            .allowsHitTesting(true)
    }
}

#Preview {
    ResizableDivider(width: .constant(300), minWidth: 200, maxWidth: 800)
        .frame(height: 400)
} 