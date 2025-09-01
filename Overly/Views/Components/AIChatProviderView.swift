//
//  AIChatProviderView.swift
//  Overly
//
//  Created by AI Assistant on 1/27/25.
//

import SwiftUI

struct AIChatProviderView: View {
    @State private var inputText: String = ""
    @StateObject private var textSelectionManager = TextSelectionManager.shared
    @StateObject private var messageManager = AIChatMessageManager.shared
    @State private var showModelPicker = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            AIChatHeaderView(
                providerManager: AIProviderManager.shared,
                showModelPicker: $showModelPicker,
                onNewChat: messageManager.startNewChat
            )
            
            // Messages
            messagesView
            
            // Input area
            AIChatInputView(
                inputText: $inputText,
                isGenerating: $messageManager.isGenerating,
                textSelectionManager: textSelectionManager,
                onSendMessage: sendMessage,
                onStopGeneration: messageManager.stopGeneration
            )
        }
        .background(Color(red: 0.11, green: 0.11, blue: 0.11))
        .onAppear {
            messageManager.loadPersistedMessages()
            setupNotificationObservers()
        }
        .onDisappear {
            messageManager.saveMessagesToPersistence()
        }
        .overlay(
            // Hidden button for keyboard shortcut
            Button("") {
                if messageManager.isGenerating {
                    messageManager.stopGeneration()
                }
            }
            .keyboardShortcut(.delete, modifiers: [.command, .shift])
            .opacity(0)
            .allowsHitTesting(false)
        )
    }
    
    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 16) {
                    ForEach(messageManager.messages) { message in
                        MessageBubble(message: message, onMessageEdited: {
                            // Only trigger generation if it's a user message
                            if message.isUser {
                                messageManager.generateResponseForEditedMessage()
                            }
                        }, onRegenerateResponse: { aiMessage in
                            // Only regenerate if it's an AI message
                            if !aiMessage.isUser {
                                messageManager.regenerateResponse(for: aiMessage)
                            }
                        }, onSaveMessages: {
                            messageManager.saveMessagesToPersistence()
                        })
                            .id(message.id)
                    }
                    
                    if messageManager.isTyping {
                        TypingIndicator()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .scrollContentBackground(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.visible)
            .onChange(of: messageManager.messages.count) {
                if let lastMessage = messageManager.messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private func sendMessage() {
        let selectedText = textSelectionManager.selectedAttachment?.text
        messageManager.sendMessage(inputText, selectedText: selectedText)
        
        // Clear input and selection
        inputText = ""
        textSelectionManager.clearSelection()
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SendOllamaMessage"),
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo,
               let model = userInfo["model"] as? String,
               let query = userInfo["query"] as? String {
                
                // Set the model if provided and not empty
                if !model.isEmpty {
                    Task { @MainActor in
                        let providerManager = AIProviderManager.shared
                        // Try to find an exact match first
                        let availableModels = providerManager.availableModels.filter { $0.provider == .ollama && $0.isEnabled }
                        
                        if let exactMatch = availableModels.first(where: { $0.name == model }) {
                            providerManager.setSelectedModel(exactMatch.name)
                        } else {
                            // Try fuzzy matching for partial names (e.g., "llama3.2" should match "llama3.2:1b")
                            if let fuzzyMatch = availableModels.first(where: { $0.name.hasPrefix(model) }) {
                                providerManager.setSelectedModel(fuzzyMatch.name)
                            } else {
                                // Try even more flexible matching (case insensitive, contains)
                                if let flexibleMatch = availableModels.first(where: { 
                                    $0.name.lowercased().contains(model.lowercased()) 
                                }) {
                                    providerManager.setSelectedModel(flexibleMatch.name)
                                }
                                // If no match found, just use the provided model name as-is
                                // (in case it's a valid model that's not in the current list)
                            }
                        }
                    }
                }
                
                // Set the input text and send the message if query is provided
                if !query.isEmpty {
                    inputText = query
                    sendMessage()
                }
            }
        }
    }
}

#Preview {
    AIChatProviderView()
        .frame(width: 800, height: 600)
} 