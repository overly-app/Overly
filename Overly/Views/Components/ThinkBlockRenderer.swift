//
//  ThinkBlockRenderer.swift
//  Overly
//
//  Created by AI Assistant on 1/27/25.
//

import SwiftUI

struct ThinkBlockRenderer: View {
    let content: String
    let textColor: Color?
    @State private var isExpanded = false
    
    init(content: String, textColor: Color? = nil) {
        self.content = content
        self.textColor = textColor
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Parse content and render think blocks
            let parsedContent = parseThinkBlocks(content)
            ForEach(Array(parsedContent.enumerated()), id: \.offset) { index, element in
                switch element {
                case .thinkBlock(let thinkContent):
                    ThinkBlockView(
                        content: thinkContent,
                        textColor: textColor,
                        isExpanded: $isExpanded
                    )
                case .regularText(let text):
                    MarkdownRenderer(content: text, textColor: textColor)
                }
            }
        }
    }
    
    private func parseThinkBlocks(_ text: String) -> [ContentElement] {
        var elements: [ContentElement] = []
        var currentIndex = text.startIndex
        var currentText = ""
        
        while currentIndex < text.endIndex {
            let remainingText = String(text[currentIndex...])
            
            // Look for opening <think> tag
            if let thinkStart = remainingText.range(of: "<think>") {
                // Add any text before the think block
                if !currentText.isEmpty {
                    elements.append(.regularText(currentText))
                    currentText = ""
                }
                
                // Find the closing </think> tag
                let afterThinkStart = remainingText[thinkStart.upperBound...]
                if let thinkEnd = afterThinkStart.range(of: "</think>") {
                    let thinkContent = String(afterThinkStart[..<thinkEnd.lowerBound])
                    elements.append(.thinkBlock(thinkContent))
                    
                    // Move past the entire think block including the closing tag
                    // Calculate the actual end position by finding where the closing tag ends in the original text
                    let closingTagStart = text.index(thinkStart.lowerBound, offsetBy: 7 + thinkContent.count) // <think> + content
                    let closingTagEnd = text.index(closingTagStart, offsetBy: 8) // </think>
                    currentIndex = closingTagEnd
                } else {
                    // No closing tag found, treat as regular text
                    currentText += remainingText
                    break
                }
            } else {
                // No think block found, add to current text
                currentText += remainingText
                break
            }
        }
        
        // Add any remaining text
        if !currentText.isEmpty {
            elements.append(.regularText(currentText))
        }
        
        return elements
    }
}

// MARK: - Think Block View

struct ThinkBlockView: View {
    let content: String
    let textColor: Color?
    @Binding var isExpanded: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Collapsible header
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "brain")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.orange)
                    
                    Text("Reasoning")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(textColor ?? .primary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 0 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            
            // Collapsible content
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    // Render the think content without animation
                    MarkdownRenderer(
                        content: content,
                        textColor: textColor
                    )
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity.combined(with: .move(edge: .top))
                ))
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Content Element Types

enum ContentElement {
    case thinkBlock(String)
    case regularText(String)
}

#Preview {
    ScrollView {
        ThinkBlockRenderer(content: """
This is regular text before the think block.

<think>
This is a think block that should be collapsible.
It can contain multiple lines and **markdown formatting**.

## Subheading
- List item 1
- List item 2

```swift
func example() {
    print("Code example")
}
```
</think>

This is regular text after the think block.
""")
    }
    .padding()
    .frame(width: 400)
}
