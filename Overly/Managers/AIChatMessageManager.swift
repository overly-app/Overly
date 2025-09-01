//
//  AIChatMessageManager.swift
//  Overly
//
//  Created by AI Assistant on 1/27/25.
//

import Foundation

@MainActor
class AIChatMessageManager: ObservableObject {
    static let shared = AIChatMessageManager()
    
    @Published var messages: [AIChatMessage] = []
    @Published var isTyping: Bool = false
    @Published var isGenerating: Bool = false
    
    private var currentTask: Task<Void, Never>?
    private let providerManager = AIProviderManager.shared
    private let chatSessionManager = ChatSessionManager.shared
    
    // Helper function to parse and format streaming content with think blocks
    private func formatStreamingContent(_ content: String) -> String {
        var formattedContent = content
        
        // Look for incomplete think blocks and format them properly
        // This ensures that streaming responses with <think> tags are handled gracefully
        
        // If we have an opening <think> but no closing tag, add a temporary closing tag
        if formattedContent.contains("<think>") && !formattedContent.contains("</think>") {
            // Find the last <think> tag
            if let lastThinkStart = formattedContent.range(of: "<think>", options: .backwards) {
                let afterThinkStart = formattedContent[lastThinkStart.upperBound...]
                // If there's content after <think> but no closing tag, add a temporary one
                if !afterThinkStart.isEmpty {
                    formattedContent += "</think>"
                }
            }
        }
        
        return formattedContent
    }
    
    private init() {}
    
    func switchToSession(_ sessionId: UUID) {
        // Save current messages before switching
        saveMessagesToPersistence()
        
        // Switch to new session
        chatSessionManager.switchToChat(sessionId)
        
        // Load messages from new session
        loadPersistedMessages()
    }
    
    func loadPersistedMessages() {
        // Load messages from current chat session
        if let currentSession = chatSessionManager.getCurrentSession() {
            messages = currentSession.messages
        } else {
            // No current session, start with empty messages
            messages = []
        }
    }
    
    func saveMessagesToPersistence() {
        // Save messages to current chat session
        chatSessionManager.updateCurrentSession { session in
            session.messages = messages
        }
    }
    
    func startNewChat() {
        // Stop any ongoing generation
        stopGeneration()
        
        // Clear current messages
        messages.removeAll()
        
        // Create new chat session (this will set currentSessionId to nil)
        chatSessionManager.createNewChat()
    }
    
    func stopGeneration() {
        currentTask?.cancel()
        currentTask = nil
        isTyping = false
        isGenerating = false
    }
    
    func sendMessage(_ inputText: String, selectedText: String?) {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Prepare the user message content
        var userMessageContent = inputText
        if let context = selectedText {
            userMessageContent = "**Selected text:** \"\(context)\"\n\n**Question:** \(inputText)"
        }
        
        let userMessage = AIChatMessage(content: userMessageContent, isUser: true)
        messages.append(userMessage)
        
        // Add message to current session
        chatSessionManager.addMessageToCurrentSession(userMessage)
        
        let messageToSend = inputText
        
        // Check if model is selected
        guard !providerManager.selectedModel.isEmpty else {
            let errorMessage = AIChatMessage(content: "Please select a model first.", isUser: false)
            messages.append(errorMessage)
            return
        }
        
        // Update the model in current session
        chatSessionManager.updateCurrentSessionModel(providerManager.selectedModel)
        
        // Show typing indicator and set generating state
        isTyping = true
        isGenerating = true
        
        currentTask = Task {
            do {
                // Prepare messages for AI provider
                var aiMessages: [AIProviderMessage] = []
                
                // Add context if there's selected text
                if let context = selectedText {
                    aiMessages.append(AIProviderMessage(
                        role: "system",
                        content: "The user has selected this text from a webpage: \"\(context)\". Please analyze this text and answer their question in relation to it. Reference specific parts of the selected text when relevant."
                    ))
                }
                
                // Add conversation history (last few messages for context)
                let recentMessages = messages.suffix(6) // Last 6 messages for context
                for msg in recentMessages {
                    if msg.id != userMessage.id { // Don't include the message we just added
                        aiMessages.append(AIProviderMessage(
                            role: msg.isUser ? "user" : "assistant",
                            content: msg.content
                        ))
                    }
                }
                
                // Add the current user message
                aiMessages.append(AIProviderMessage(role: "user", content: messageToSend))
                
                // Send to AI provider and stream response
                let stream = try await providerManager.sendMessage(aiMessages)
                
                await MainActor.run {
                    isTyping = false
                    // Keep isGenerating = true during streaming
                }
                
                // Create AI message and stream content
                let aiMessage = AIChatMessage(content: "", isUser: false)
                aiMessage.startGenerating() // Mark as generating
                await MainActor.run {
                    messages.append(aiMessage)
                    // Add AI message to current session
                    chatSessionManager.addMessageToCurrentSession(aiMessage)
                }
                
                var fullResponse = ""
                for try await chunk in stream {
                    // Check if task was cancelled
                    if Task.isCancelled {
                        break
                    }
                    
                    fullResponse += chunk
                    let formattedResponse = formatStreamingContent(fullResponse)
                    await MainActor.run {
                        // Update the content directly on the ObservableObject
                        aiMessage.content = formattedResponse
                        // Also update the responses array
                        if aiMessage.responses.isEmpty {
                            aiMessage.responses = [formattedResponse]
                        } else {
                            aiMessage.responses[0] = formattedResponse
                        }
                    }
                }
                
                // Reset generation state when complete
                await MainActor.run {
                    aiMessage.markGenerationComplete() // Mark as complete
                    isGenerating = false
                    // Save messages after completion
                    saveMessagesToPersistence()
                }
                
            } catch {
                await MainActor.run {
                    isTyping = false
                    isGenerating = false
                    let errorMessage = AIChatMessage(content: "Error: \(error.localizedDescription)", isUser: false)
                    messages.append(errorMessage)
                    // Save messages after error
                    saveMessagesToPersistence()
                }
            }
        }
    }
    
    func generateResponseForEditedMessage() {
        // Check if model is selected
        guard !providerManager.selectedModel.isEmpty else {
            let errorMessage = AIChatMessage(content: "Please select a model first.", isUser: false)
            messages.append(errorMessage)
            return
        }
        
        // Find and remove all AI responses after the last user message
        if let lastUserIndex = messages.lastIndex(where: { $0.isUser }) {
            // Remove all AI messages after the last user message
            messages.removeSubrange((lastUserIndex + 1)...)
        }
        
        // Show typing indicator and set generating state
        isTyping = true
        isGenerating = true
        
        currentTask = Task {
            do {
                // Prepare messages for AI provider using only user messages
                var aiMessages: [AIProviderMessage] = []
                
                // Add only user messages to the conversation
                for msg in messages where msg.isUser {
                    aiMessages.append(AIProviderMessage(
                        role: "user",
                        content: msg.content
                    ))
                }
                
                // Send to AI provider and stream response
                let stream = try await providerManager.sendMessage(aiMessages)
                
                await MainActor.run {
                    isTyping = false
                    // Keep isGenerating = true during streaming
                }
                
                // Create AI message and stream content
                let aiMessage = AIChatMessage(content: "", isUser: false)
                aiMessage.startGenerating() // Mark as generating
                await MainActor.run {
                    messages.append(aiMessage)
                }
                
                var fullResponse = ""
                for try await chunk in stream {
                    // Check if task was cancelled
                    if Task.isCancelled {
                        break
                    }
                    
                    fullResponse += chunk
                    let formattedResponse = formatStreamingContent(fullResponse)
                    await MainActor.run {
                        // Update the content directly on the ObservableObject
                        aiMessage.content = formattedResponse
                        // Also update the responses array
                        if aiMessage.responses.isEmpty {
                            aiMessage.responses = [formattedResponse]
                        } else {
                            aiMessage.responses[0] = formattedResponse
                        }
                    }
                }
                
                // Reset generation state when complete
                await MainActor.run {
                    aiMessage.markGenerationComplete() // Mark as complete
                    isGenerating = false
                    // Save messages after completion
                    saveMessagesToPersistence()
                }
                
            } catch {
                await MainActor.run {
                    isTyping = false
                    isGenerating = false
                    let errorMessage = AIChatMessage(content: "Error: \(error.localizedDescription)", isUser: false)
                    messages.append(errorMessage)
                    // Save messages after error
                    saveMessagesToPersistence()
                }
            }
        }
    }
    
    func regenerateResponse(for message: AIChatMessage) {
        // Check if model is selected
        guard !providerManager.selectedModel.isEmpty else {
            let errorMessage = AIChatMessage(content: "Please select a model first.", isUser: false)
            messages.append(errorMessage)
            return
        }
        
        // Find the AI message in the messages array and get the conversation context
        guard let aiMessageIndex = messages.firstIndex(where: { $0.id == message.id }) else { return }
        
        // Get all messages up to this AI message (excluding this AI message)
        let contextMessages = Array(messages[..<aiMessageIndex])
        
        // Show typing indicator and set generating state
        isTyping = true
        isGenerating = true
        message.startGenerating() // Mark this specific message as generating
        
        currentTask = Task {
            do {
                // Prepare messages for AI provider using the conversation context
                var aiMessages: [AIProviderMessage] = []
                
                // Add conversation history up to the AI message being regenerated
                for msg in contextMessages {
                    aiMessages.append(AIProviderMessage(
                        role: msg.isUser ? "user" : "assistant",
                        content: msg.content
                    ))
                }
                
                // Send to AI provider and stream response
                let stream = try await providerManager.sendMessage(aiMessages)
                
                await MainActor.run {
                    isTyping = false
                    // Keep isGenerating = true during streaming
                }
                
                var fullResponse = ""
                for try await chunk in stream {
                    // Check if task was cancelled
                    if Task.isCancelled {
                        break
                    }
                    
                    fullResponse += chunk
                    let formattedResponse = formatStreamingContent(fullResponse)
                    await MainActor.run {
                        // Update the message content and add to responses
                        message.addResponse(formattedResponse)
                    }
                }
                
                // Reset generation state when complete
                await MainActor.run {
                    message.markGenerationComplete() // Mark this specific message as complete
                    isGenerating = false
                    // Save messages after completion
                    saveMessagesToPersistence()
                }
                
            } catch {
                await MainActor.run {
                    isTyping = false
                    isGenerating = false
                    let errorMessage = AIChatMessage(content: "Error: \(error.localizedDescription)", isUser: false)
                    messages.append(errorMessage)
                    // Save messages after error
                    saveMessagesToPersistence()
                }
            }
        }
    }
}
