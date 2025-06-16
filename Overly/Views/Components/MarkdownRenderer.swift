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
    static func parseInlineText(_ text: String) -> [InlineTextElement] {
        var elements: [InlineTextElement] = []
        var currentText = text
        
        // Parse inline code first (to avoid conflicts with other formatting)
        currentText = parseInlineCode(currentText, elements: &elements)
        
        // Parse links
        currentText = parseLinks(currentText, elements: &elements)
        
        // Parse bold, italic, strikethrough
        currentText = parseFormatting(currentText, elements: &elements)
        
        // Add remaining text as plain text
        if !currentText.isEmpty {
            elements.append(InlineTextElement(type: .text, content: currentText))
        }
        
        return elements.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }
    
    private static func parseInlineCode(_ text: String, elements: inout [InlineTextElement]) -> String {
        let pattern = #"`([^`]+)`"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        
        for match in matches.reversed() {
            let range = Range(match.range, in: text)!
            let codeRange = Range(match.range(at: 1), in: text)!
            let code = String(text[codeRange])
            
            elements.append(InlineTextElement(
                type: .inlineCode,
                content: code,
                range: range
            ))
        }
        
        return regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
    }
    
    private static func parseLinks(_ text: String, elements: inout [InlineTextElement]) -> String {
        let pattern = #"\[([^\]]+)\]\(([^)]+)\)"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        
        for match in matches.reversed() {
            let range = Range(match.range, in: text)!
            let textRange = Range(match.range(at: 1), in: text)!
            let urlRange = Range(match.range(at: 2), in: text)!
            
            let linkText = String(text[textRange])
            let url = String(text[urlRange])
            
            elements.append(InlineTextElement(
                type: .link(url: url),
                content: linkText,
                range: range
            ))
        }
        
        return regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
    }
    
    private static func parseFormatting(_ text: String, elements: inout [InlineTextElement]) -> String {
        var result = text
        
        // Bold (**text** or __text__)
        let boldPattern = #"\*\*([^*]+)\*\*|__([^_]+)__"#
        let boldRegex = try! NSRegularExpression(pattern: boldPattern)
        let boldMatches = boldRegex.matches(in: result, range: NSRange(result.startIndex..., in: result))
        
        for match in boldMatches.reversed() {
            let range = Range(match.range, in: result)!
            let contentRange = match.range(at: 1).location != NSNotFound ? 
                Range(match.range(at: 1), in: result)! : Range(match.range(at: 2), in: result)!
            let content = String(result[contentRange])
            
            elements.append(InlineTextElement(
                type: .bold,
                content: content,
                range: range
            ))
        }
        
        result = boldRegex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
        
        // Italic (*text* or _text_)
        let italicPattern = #"\*([^*]+)\*|_([^_]+)_"#
        let italicRegex = try! NSRegularExpression(pattern: italicPattern)
        let italicMatches = italicRegex.matches(in: result, range: NSRange(result.startIndex..., in: result))
        
        for match in italicMatches.reversed() {
            let range = Range(match.range, in: result)!
            let contentRange = match.range(at: 1).location != NSNotFound ? 
                Range(match.range(at: 1), in: result)! : Range(match.range(at: 2), in: result)!
            let content = String(result[contentRange])
            
            elements.append(InlineTextElement(
                type: .italic,
                content: content,
                range: range
            ))
        }
        
        result = italicRegex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
        
        // Strikethrough (~~text~~)
        let strikePattern = #"~~([^~]+)~~"#
        let strikeRegex = try! NSRegularExpression(pattern: strikePattern)
        let strikeMatches = strikeRegex.matches(in: result, range: NSRange(result.startIndex..., in: result))
        
        for match in strikeMatches.reversed() {
            let range = Range(match.range, in: result)!
            let contentRange = Range(match.range(at: 1), in: result)!
            let content = String(result[contentRange])
            
            elements.append(InlineTextElement(
                type: .strikethrough,
                content: content,
                range: range
            ))
        }
        
        result = strikeRegex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
        
        return result
    }
}

struct InlineTextElement {
    enum ElementType {
        case text
        case bold
        case italic
        case strikethrough
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
        
        return Text(buildAttributedString(from: elements, originalText: text))
            .font(.system(size: 14))
            .foregroundColor(textColor ?? .primary)
    }
    
    private func buildAttributedString(from elements: [InlineTextElement], originalText: String) -> AttributedString {
        var attributedString = AttributedString(originalText)
        
        for element in elements {
            let range = element.range
            let nsRange = NSRange(range, in: originalText)
            
            if let attributedRange = Range(nsRange, in: attributedString) {
                switch element.type {
                case .bold:
                    attributedString[attributedRange].font = .system(size: 14, weight: .bold)
                    
                case .italic:
                    attributedString[attributedRange].font = .system(size: 14).italic()
                    
                case .strikethrough:
                    attributedString[attributedRange].strikethroughStyle = .single
                    
                case .inlineCode:
                    let monoFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
                    attributedString[attributedRange].font = monoFont
                    attributedString[attributedRange].backgroundColor = codeInlineBackground
                    
                case .link(let url):
                    attributedString[attributedRange].foregroundColor = .accentColor
                    attributedString[attributedRange].underlineStyle = .single
                    if let linkURL = URL(string: url) {
                        attributedString[attributedRange].link = linkURL
                    }
                    
                case .text:
                    break
                }
            }
        }
        
        return attributedString
    }
    
    private var codeBlockBackground: Color {
        colorScheme == .dark ? Color(red: 0.1, green: 0.1, blue: 0.1) : Color(red: 0.96, green: 0.96, blue: 0.96)
    }
    
    private var codeInlineBackground: Color {
        colorScheme == .dark ? Color(red: 0.15, green: 0.15, blue: 0.15) : Color(red: 0.92, green: 0.92, blue: 0.92)
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

This is a **bold** text and this is *italic* text. You can also have ~~strikethrough~~ text.

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

That's all!
""")
    }
    .padding()
    .frame(width: 400)
}