//
//  AIChatProviderView.swift
//  Overly
//
//  Created by AI Assistant on 1/27/25.
//

import SwiftUI
import AppKit

struct AIChatProviderView: View {
    @State private var inputText: String = ""
    @State private var showPromptSuggestions = false
    @StateObject private var textSelectionManager = TextSelectionManager.shared
    @StateObject private var messageManager = AIChatMessageManager.shared
    @StateObject private var chatSessionManager = ChatSessionManager.shared
    @State private var showModelPicker = false
    @State private var editorHeight: CGFloat = 44
    private let editorFont = NSFont.systemFont(ofSize: 16)
    
    var body: some View {
        HStack(spacing: 0) {
            // Chat sidebar
            ChatSidebarView()
            
            // Main chat area
            VStack(spacing: 0) {
                // Header
                AIChatHeaderView(
                    providerManager: AIProviderManager.shared,
                    showModelPicker: $showModelPicker,
                    onNewChat: {
                        messageManager.startNewChat()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showPromptSuggestions = true
                        }
                    }
                )
                
                // Messages or Prompt Suggestions
                if showPromptSuggestions && messageManager.messages.isEmpty {
                    promptSuggestionsView
                } else {
                    messagesView
                }
                
                // Input area
                if !showPromptSuggestions {
                    AIChatInputView(
                        inputText: $inputText,
                        isGenerating: $messageManager.isGenerating,
                        textSelectionManager: textSelectionManager,
                        onSendMessage: sendMessage,
                        onStopGeneration: messageManager.stopGeneration
                    )
                }
            }
        }
        .background(Color(red: 0.11, green: 0.11, blue: 0.11))
        .onAppear {
            messageManager.loadPersistedMessages()
            setupNotificationObservers()
        }
        .onChange(of: chatSessionManager.currentSessionId) { _ in
            messageManager.loadPersistedMessages()
            // Hide prompt suggestions when switching to an existing chat
            if !messageManager.messages.isEmpty {
                showPromptSuggestions = false
            }
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
    
    private var promptSuggestionsView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Greeting
            Text("How can I help you today?")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            // Centered input box
            VStack(spacing: 16) {
                // Big panel with multiline TextEditor (no inner background/border)
                VStack(spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $inputText)
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .frame(height: editorHeight)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 8)
                            .onChange(of: inputText) { _ in
                                updateEditorHeight()
                            }
                        
                        if inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("How can I help you today?")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 26)
                                .padding(.top, 20)
                        }
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: {}) {
                            Image(systemName: "paperclip")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                                .background(Color(red: 0.2, green: 0.2, blue: 0.2))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { showModelPicker.toggle() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "brain")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                                Text(AIProviderManager.shared.selectedModel.isEmpty ? "Select Model" : AIProviderManager.shared.selectedModel.replacingOccurrences(of: ":latest", with: ""))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color(red: 0.2, green: 0.2, blue: 0.2))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showModelPicker) {
                            ModelPickerView()
                                .frame(width: 360, height: 420)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                showPromptSuggestions = false
                                sendMessage()
                            }
                        }) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(Color.accentColor)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                }
                .frame(width: 600)
                .background(Color(red: 0.15, green: 0.15, blue: 0.15))
                .cornerRadius(12)
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        
        // Hide prompt suggestions when a message is sent
        showPromptSuggestions = false
        editorHeight = 44
    }

    private func updateEditorHeight() {
        let text = inputText + "\n" // ensure at least one line height
        let attributes: [NSAttributedString.Key: Any] = [.font: editorFont]
        let bounding = (text as NSString).boundingRect(
            with: CGSize(width: 560, height: CGFloat.greatestFiniteMagnitude), // panel width minus horizontal padding
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        )
        let minH: CGFloat = 44
        let maxH: CGFloat = 240
        let computed = ceil(bounding.height) + 24 // top/bottom padding inside editor
        editorHeight = max(minH, min(computed, maxH))
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
        
        // Observer for setting prompt from sidebar
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SetPromptAndSend"),
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo,
               let prompt = userInfo["prompt"] as? String {
                inputText = prompt
                sendMessage()
            }
        }
        
        // Observer for showing prompt suggestions from sidebar
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ShowPromptSuggestions"),
            object: nil,
            queue: .main
        ) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                showPromptSuggestions = true
            }
        }
    }
}

#Preview {
    AIChatProviderView()
        .frame(width: 800, height: 600)
} 