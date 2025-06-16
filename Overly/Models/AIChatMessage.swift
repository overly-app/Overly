//
//  AIChatMessage.swift
//  Overly
//
//  Created by AI Assistant on 1/27/25.
//

import SwiftUI

// Struct for persisting messages to UserDefaults
struct PersistedMessage: Codable {
    let content: String
    let isUser: Bool
    let responses: [String]
    let currentResponseIndex: Int
    
    init(content: String, isUser: Bool, responses: [String] = [], currentResponseIndex: Int = 0) {
        self.content = content
        self.isUser = isUser
        self.responses = responses
        self.currentResponseIndex = currentResponseIndex
    }
}

class AIChatMessage: ObservableObject, Identifiable {
    let id = UUID()
    @Published var content: String
    let isUser: Bool
    let timestamp: Date = Date()
    @Published var responses: [String] = [] // For AI messages with multiple responses
    @Published var currentResponseIndex: Int = 0
    @Published var isGenerating: Bool = false // Track if this message is currently being generated
    
    init(content: String, isUser: Bool) {
        self.content = content
        self.isUser = isUser
        if !isUser {
            self.responses = [content]
            self.isGenerating = content.isEmpty // If content is empty, it's still generating
        }
    }
    
    func addResponse(_ response: String) {
        if !isUser {
            responses.append(response)
            currentResponseIndex = responses.count - 1
            content = response
        }
    }
    
    func clearResponses() {
        if !isUser {
            responses.removeAll()
            content = ""
            currentResponseIndex = 0
            isGenerating = true
        }
    }
    
    func setCurrentResponse(at index: Int) {
        if !isUser && index >= 0 && index < responses.count {
            currentResponseIndex = index
            content = responses[index]
        }
    }
    
    func markGenerationComplete() {
        if !isUser {
            isGenerating = false
        }
    }
    
    func startGenerating() {
        if !isUser {
            isGenerating = true
        }
    }
} 