//
//  MarkdownRenderer.swift
//  Overly
//
//  Created by AI Assistant on 1/27/25.
//

import SwiftUI
import Foundation

// MARK: - Markdown Renderer View

struct MarkdownRenderer: View {
    let content: String
    let textColor: Color?
    @Environment(\.colorScheme) private var colorScheme
    
    init(content: String, textColor: Color? = nil) {
        self.content = content
        self.textColor = textColor
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let elements = MarkdownParser.parse(content)
            ForEach(Array(elements.enumerated()), id: \.offset) { index, element in
                renderElement(element)
            }
        }
    }
    
    @ViewBuilder
    private func renderElement(_ element: MarkdownElement) -> some View {
        switch element.type {
        case .heading(let level):
            renderHeading(element.content, level: level)
            
        case .paragraph:
            renderParagraph(element.content)
            
        case .codeBlock(let language):
            renderCodeBlock(element.content, language: language)
            
        case .list(let ordered):
            renderList(element.children, ordered: ordered)
            
        case .table:
            renderTable(element.children)
            
        case .blockquote:
            renderBlockquote(element.content)
            
        case .horizontalRule:
            renderHorizontalRule()
            
        default:
            EmptyView()
        }
    }
    
    private func renderHeading(_ text: String, level: Int) -> some View {
        let fontSize: CGFloat = {
            switch level {
            case 1: return 24
            case 2: return 20
            case 3: return 18
            case 4: return 16
            case 5: return 14
            case 6: return 12
            default: return 16
            }
        }()
        
        let fontWeight: Font.Weight = level <= 2 ? .bold : .semibold
        
        return Text(text)
            .font(.system(size: fontSize, weight: fontWeight))
            .foregroundColor(textColor ?? .primary)
            .padding(.vertical, 4)
    }
    
    private func renderParagraph(_ text: String) -> some View {
        renderInlineText(text)
            .padding(.vertical, 2)
    }
    
    private func renderCodeBlock(_ code: String, language: String?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let language = language, !language.isEmpty {
                HStack {
                    Text(language.uppercased())
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    
                    Spacer()
                    
                    Button(action: {
                        copyToClipboard(code)
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                                 Text(code)
                     .font(.system(size: 13, design: .monospaced))
                     .foregroundColor(textColor ?? .primary)
                     .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, language != nil ? 8 : 12)
            }
        }
        .background(codeBlockBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func renderList(_ items: [MarkdownElement], ordered: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 8) {
                    Text(ordered ? "\(index + 1)." : "•")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 20, alignment: .leading)
                    
                    renderInlineText(item.content)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.leading, 8)
    }
    
        private func renderTable(_ rows: [MarkdownElement]) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                renderTableRow(row, isHeader: row.type == .tableHeader)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func renderTableRow(_ row: MarkdownElement, isHeader: Bool) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(row.children.enumerated()), id: \.offset) { cellIndex, cell in
                Text(cell.content)
                    .font(.system(size: 14))
                    .foregroundColor(textColor ?? .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(isHeader ? Color.secondary.opacity(0.1) : Color.clear)
                    .overlay(
                        Rectangle()
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
                    )
            }
        }
    }
    
    private func renderBlockquote(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle()
                .fill(Color.accentColor)
                .frame(width: 4)
            
            renderInlineText(text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, 8)
        .padding(.vertical, 4)
    }
    
    private func renderHorizontalRule() -> some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.3))
            .frame(height: 1)
            .padding(.vertical, 8)
    }
    
    private func renderInlineText(_ text: String) -> some View {
        let elements = InlineTextParser.parseInlineText(text)
        
        return Text(elements)
            .font(.system(size: 14))
            .foregroundColor(textColor ?? .primary)
    }
    
    private var codeBlockBackground: Color {
        colorScheme == .dark ? Color(red: 0.1, green: 0.1, blue: 0.1) : Color(red: 0.96, green: 0.96, blue: 0.96)
    }
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

#Preview {
    ScrollView {
        MarkdownRenderer(content: """
# Heading 1
## Heading 2
### Heading 3

This is a **bold** text and this is *italic* text. You can also have ~~strikethrough~~ text and <u>underlined</u> text.

Here's some `inline code` and a [link](https://example.com).

```swift
func hello() {
    print("Hello, World!")
}
```

## Lists

### Unordered List
- Item 1
- Item 2
- Item 3

### Ordered List
1. First item
2. Second item
3. Third item

## Table

| Name | Age | City |
|------|-----|------|
| John | 25 | NYC |
| Jane | 30 | LA |

> This is a blockquote
> It can span multiple lines

---

**Formatting Examples:**
- **Bold text**
- *Italic text*
- <u>Underlined text</u>
- ~~Strikethrough text~~
- `Inline code`

That's all!
""")
    }
    .padding()
    .frame(width: 400)
}