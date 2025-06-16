//
//  TextSelectionManager.swift
//  Overly
//
//  Created by AI Assistant on 1/27/25.
//

import SwiftUI
import Combine

struct SelectedTextAttachment: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let source: String
    let timestamp: Date = Date()
    
    static func == (lhs: SelectedTextAttachment, rhs: SelectedTextAttachment) -> Bool {
        return lhs.id == rhs.id
    }
}

class TextSelectionManager: ObservableObject {
    static let shared = TextSelectionManager()
    
    @Published var selectedAttachment: SelectedTextAttachment?
    
    private init() {}
    
    func setSelectedText(_ text: String, source: String = "ebAuthn.io") {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedText.isEmpty {
            // Clear selection when text is empty
            selectedAttachment = nil
        } else {
            // Only update if the text is different
            if selectedAttachment?.text != trimmedText {
                selectedAttachment = SelectedTextAttachment(text: trimmedText, source: source)
            }
        }
    }
    
    func clearSelection() {
        selectedAttachment = nil
    }
} 