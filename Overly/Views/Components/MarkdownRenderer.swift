//
//  MarkdownRenderer.swift
//  Overly
//
//  Created by AI Assistant on 1/27/25.
//

import SwiftUI
import Foundation

// MARK: - Markdown Parser

struct MarkdownElement {
    enum ElementType: Equatable {
        case heading(level: Int)
        case paragraph
        case codeBlock(language: String?)
        case inlineCode
        case bold
        case italic
        case strikethrough
        case link(url: String)
        case list(ordered: Bool)
        case listItem
        case table
        case tableRow
        case tableHeader
        case tableCell
        case blockquote
        case horizontalRule
        case lineBreak
    }
    
    let type: ElementType
    let content: String
    let children: [MarkdownElement]
    
    init(type: ElementType, content: String = "", children: [MarkdownElement] = []) {
        self.type = type
        self.content = content
        self.children = children
    }
}

class MarkdownParser {
    static func parse(_ markdown: String) -> [MarkdownElement] {
        let lines = markdown.components(separatedBy: .newlines)
        var elements: [MarkdownElement] = []
        var i = 0
        
        while i < lines.count {
            let line = lines[i]
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines
            if trimmedLine.isEmpty {
                i += 1
                continue
            }
            
            // Code blocks
            if trimmedLine.hasPrefix("```") {
                let (codeBlock, nextIndex) = parseCodeBlock(lines: lines, startIndex: i)
                elements.append(codeBlock)
                i = nextIndex
                continue
            }
            
            // Tables
            if trimmedLine.contains("|") && (i + 1 < lines.count && lines[i + 1].contains("|")) {
                let (table, nextIndex) = parseTable(lines: lines, startIndex: i)
                elements.append(table)
                i = nextIndex
                continue
            }
            
            // Headings
            if trimmedLine.hasPrefix("#") {
                elements.append(parseHeading(line))
                i += 1
                continue
            }
            
            // Lists
            if trimmedLine.hasPrefix("- ") || trimmedLine.hasPrefix("* ") || 
               trimmedLine.hasPrefix("+ ") || isOrderedListItem(trimmedLine) {
                let (list, nextIndex) = parseList(lines: lines, startIndex: i)
                elements.append(list)
                i = nextIndex
                continue
            }
            
            // Blockquotes
            if trimmedLine.hasPrefix("> ") {
                let (blockquote, nextIndex) = parseBlockquote(lines: lines, startIndex: i)
                elements.append(blockquote)
                i = nextIndex
                continue
            }
            
            // Horizontal rules
            if trimmedLine == "---" || trimmedLine == "***" || trimmedLine == "___" {
                elements.append(MarkdownElement(type: .horizontalRule))
                i += 1
                continue
            }
            
            // Regular paragraph
            elements.append(parseParagraph(line))
            i += 1
        }
        
        return elements
    }
    
    private static func parseCodeBlock(lines: [String], startIndex: Int) -> (MarkdownElement, Int) {
        let firstLine = lines[startIndex].trimmingCharacters(in: .whitespaces)
        let language = String(firstLine.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        
        var content = ""
        var i = startIndex + 1
        
        while i < lines.count {
            let line = lines[i]
            if line.trimmingCharacters(in: .whitespaces) == "```" {
                break
            }
            content += line + "\n"
            i += 1
        }
        
        return (MarkdownElement(
            type: .codeBlock(language: language.isEmpty ? nil : language),
            content: content.trimmingCharacters(in: .newlines)
        ), i + 1)
    }
    
    private static func parseTable(lines: [String], startIndex: Int) -> (MarkdownElement, Int) {
        var rows: [MarkdownElement] = []
        var i = startIndex
        var isFirstRow = true
        
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if !line.contains("|") {
                break
            }
            
            // Skip separator row (e.g., |---|---|)
            if line.contains("-") && line.replacingOccurrences(of: "|", with: "").replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ":", with: "").isEmpty {
                i += 1
                continue
            }
            
            let cells = line.components(separatedBy: "|")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            
            let cellElements = cells.map { MarkdownElement(type: .tableCell, content: $0) }
            let rowType: MarkdownElement.ElementType = isFirstRow ? .tableHeader : .tableRow
            rows.append(MarkdownElement(type: rowType, children: cellElements))
            
            isFirstRow = false
            i += 1
        }
        
        return (MarkdownElement(type: .table, children: rows), i)
    }
    
    private static func parseHeading(_ line: String) -> MarkdownElement {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        var level = 0
        var content = trimmed
        
        while content.hasPrefix("#") && level < 6 {
            level += 1
            content = String(content.dropFirst())
        }
        
        content = content.trimmingCharacters(in: .whitespaces)
        return MarkdownElement(type: .heading(level: level), content: content)
    }
    
    private static func parseList(lines: [String], startIndex: Int) -> (MarkdownElement, Int) {
        var items: [MarkdownElement] = []
        var i = startIndex
        let firstLine = lines[startIndex].trimmingCharacters(in: .whitespaces)
        let isOrdered = isOrderedListItem(firstLine)
        
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            
            if line.isEmpty {
                i += 1
                continue
            }
            
            if isOrdered && isOrderedListItem(line) {
                let content = String(line.drop(while: { $0.isNumber || $0 == "." || $0 == " " }))
                items.append(MarkdownElement(type: .listItem, content: content))
            } else if !isOrdered && (line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ")) {
                let content = String(line.dropFirst(2))
                items.append(MarkdownElement(type: .listItem, content: content))
            } else {
                break
            }
            
            i += 1
        }
        
        return (MarkdownElement(type: .list(ordered: isOrdered), children: items), i)
    }
    
    private static func parseBlockquote(lines: [String], startIndex: Int) -> (MarkdownElement, Int) {
        var content = ""
        var i = startIndex
        
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if !line.hasPrefix("> ") {
                break
            }
            
            content += String(line.dropFirst(2)) + "\n"
            i += 1
        }
        
        return (MarkdownElement(type: .blockquote, content: content.trimmingCharacters(in: .newlines)), i)
    }
    
    private static func parseParagraph(_ line: String) -> MarkdownElement {
        return MarkdownElement(type: .paragraph, content: line)
    }
    
    private static func isOrderedListItem(_ line: String) -> Bool {
        let pattern = #"^\d+\.\s"#
        return line.range(of: pattern, options: .regularExpression) != nil
    }
}

// MARK: - Inline Text Parser

struct InlineTextParser {
    static func parseInlineText(_ text: String) -> AttributedString {
        var attributedString = AttributedString()
        var currentIndex = text.startIndex
        
        while currentIndex < text.endIndex {
            // Find the next formatting marker
            let remainingText = String(text[currentIndex...])
            
            if let match = findNextFormatting(in: remainingText) {
                // Add any plain text before the match
                if match.startOffset > 0 {
                    let plainTextEnd = text.index(currentIndex, offsetBy: match.startOffset)
                    let plainText = String(text[currentIndex..<plainTextEnd])
                    attributedString.append(AttributedString(plainText))
                }
                
                // Add the formatted text
                var formattedText = AttributedString(match.content)
                applyFormatting(to: &formattedText, type: match.type)
                attributedString.append(formattedText)
                
                // Move past the entire match (including markers)
                currentIndex = text.index(currentIndex, offsetBy: match.startOffset + match.fullLength)
            } else {
                // No more formatting found, add the rest as plain text
                let remainingText = String(text[currentIndex...])
                attributedString.append(AttributedString(remainingText))
                break
            }
        }
        
        return attributedString
    }
    
    private static func findNextFormatting(in text: String) -> FormattingMatch? {
        var earliestMatch: FormattingMatch?
        var earliestOffset = Int.max
        
        // Check for bold (**text** or __text__)
        if let match = findPattern(#"\*\*([^*]+)\*\*"#, in: text, type: .bold) {
            if match.startOffset < earliestOffset {
                earliestMatch = match
                earliestOffset = match.startOffset
            }
        }
        
        if let match = findPattern(#"__([^_]+)__"#, in: text, type: .bold) {
            if match.startOffset < earliestOffset {
                earliestMatch = match
                earliestOffset = match.startOffset
            }
        }
        
        // Check for italic (*text* or _text_) - but not if it's part of bold
        if let match = findPattern(#"(?<!\*)\*([^*]+)\*(?!\*)"#, in: text, type: .italic) {
            if match.startOffset < earliestOffset {
                earliestMatch = match
                earliestOffset = match.startOffset
            }
        }
        
        if let match = findPattern(#"(?<!_)_([^_]+)_(?!_)"#, in: text, type: .italic) {
            if match.startOffset < earliestOffset {
                earliestMatch = match
                earliestOffset = match.startOffset
            }
        }
        
        // Check for strikethrough (~~text~~)
        if let match = findPattern(#"~~([^~]+)~~"#, in: text, type: .strikethrough) {
            if match.startOffset < earliestOffset {
                earliestMatch = match
                earliestOffset = match.startOffset
            }
        }
        
        // Check for underline (<u>text</u>)
        if let match = findPattern(#"<u>([^<]+)</u>"#, in: text, type: .underline) {
            if match.startOffset < earliestOffset {
                earliestMatch = match
                earliestOffset = match.startOffset
            }
        }
        
        // Check for inline code (`text`)
        if let match = findPattern(#"`([^`]+)`"#, in: text, type: .inlineCode) {
            if match.startOffset < earliestOffset {
                earliestMatch = match
                earliestOffset = match.startOffset
            }
        }
        
        // Check for links ([text](url))
        if let match = findLinkPattern(in: text) {
            if match.startOffset < earliestOffset {
                earliestMatch = match
                earliestOffset = match.startOffset
            }
        }
        
        return earliestMatch
    }
    
    private static func findPattern(_ pattern: String, in text: String, type: InlineElementType) -> FormattingMatch? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        
        if let match = regex.firstMatch(in: text, range: range) {
            let fullRange = match.range
            let contentRange = match.range(at: 1)
            
            if let fullSwiftRange = Range(fullRange, in: text),
               let contentSwiftRange = Range(contentRange, in: text) {
                return FormattingMatch(
                    type: type,
                    content: String(text[contentSwiftRange]),
                    startOffset: text.distance(from: text.startIndex, to: fullSwiftRange.lowerBound),
                    fullLength: text.distance(from: fullSwiftRange.lowerBound, to: fullSwiftRange.upperBound)
                )
            }
        }
        
        return nil
    }
    
    private static func findLinkPattern(in text: String) -> FormattingMatch? {
        let pattern = #"\[([^\]]+)\]\(([^)]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        
        if let match = regex.firstMatch(in: text, range: range) {
            let fullRange = match.range
            let textRange = match.range(at: 1)
            let urlRange = match.range(at: 2)
            
            if let fullSwiftRange = Range(fullRange, in: text),
               let textSwiftRange = Range(textRange, in: text),
               let urlSwiftRange = Range(urlRange, in: text) {
                
                let linkText = String(text[textSwiftRange])
                let url = String(text[urlSwiftRange])
                
                return FormattingMatch(
                    type: .link(url: url),
                    content: linkText,
                    startOffset: text.distance(from: text.startIndex, to: fullSwiftRange.lowerBound),
                    fullLength: text.distance(from: fullSwiftRange.lowerBound, to: fullSwiftRange.upperBound)
                )
            }
        }
        
        return nil
    }
    
    private static func applyFormatting(to attributedString: inout AttributedString, type: InlineElementType) {
        let range = attributedString.startIndex..<attributedString.endIndex
        
        switch type {
        case .bold:
            attributedString[range].font = .system(size: 14, weight: .bold)
            
        case .italic:
            attributedString[range].font = .system(size: 14).italic()
            
        case .strikethrough:
            attributedString[range].strikethroughStyle = .single
            
        case .underline:
            attributedString[range].underlineStyle = .single
            
        case .inlineCode:
            let monoFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            attributedString[range].font = monoFont
            attributedString[range].backgroundColor = Color(red: 0.15, green: 0.15, blue: 0.15) // Dark theme background
            
        case .link(let url):
            attributedString[range].foregroundColor = .accentColor
            attributedString[range].underlineStyle = .single
            if let linkURL = URL(string: url) {
                attributedString[range].link = linkURL
            }
            
        case .text:
            break
        }
    }
}

struct FormattingMatch {
    let type: InlineElementType
    let content: String
    let startOffset: Int
    let fullLength: Int
}

enum InlineElementType {
    case text
    case bold
    case italic
    case strikethrough
    case underline
    case inlineCode
    case link(url: String)
}

struct InlineTextElement {
    enum ElementType {
        case text
        case bold
        case italic
        case strikethrough
        case underline
        case inlineCode
        case link(url: String)
    }
    
    let type: ElementType
    let content: String
    let range: Range<String.Index>
    
    init(type: ElementType, content: String, range: Range<String.Index>? = nil) {
        self.type = type
        self.content = content
        self.range = range ?? content.startIndex..<content.endIndex
    }
}

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