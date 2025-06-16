//
//  InlineTextParser.swift
//  Overly
//
//  Created by AI Assistant on 1/27/25.
//

import SwiftUI
import Foundation

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