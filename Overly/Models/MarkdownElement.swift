//
//  MarkdownElement.swift
//  Overly
//
//  Created by AI Assistant on 1/27/25.
//

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
                i += 1
            } else if !isOrdered && (line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ")) {
                let content = String(line.dropFirst(2))
                items.append(MarkdownElement(type: .listItem, content: content))
                i += 1
            } else {
                break
            }
        }
        
        return (MarkdownElement(type: .list(ordered: isOrdered), children: items), i)
    }
    
    private static func parseBlockquote(lines: [String], startIndex: Int) -> (MarkdownElement, Int) {
        var content = ""
        var i = startIndex
        
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("> ") {
                content += String(line.dropFirst(2)) + "\n"
                i += 1
            } else {
                break
            }
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