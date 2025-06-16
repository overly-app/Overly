//
//  AIChatProviderView.swift
//  Overly
//
//  Created by AI Assistant on 1/27/25.
//

import SwiftUI

struct AIChatProviderView: View {
    @State private var messages: [AIChatMessage] = []
    @State private var inputText: String = ""
    @State private var isTyping: Bool = false
    @State private var isGenerating: Bool = false
    @State private var currentTask: Task<Void, Never>?
    @FocusState private var isInputFocused: Bool
    @StateObject private var textSelectionManager = TextSelectionManager.shared
    @StateObject private var providerManager = AIProviderManager.shared
    @State private var showModelPicker = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Messages
            messagesView
            
            // Input area
            inputView
        }
        .background(Color(red: 0.11, green: 0.11, blue: 0.11))
        .onAppear {
            loadPersistedMessages()
        }
        .onDisappear {
            saveMessagesToPersistence()
        }
        .overlay(
            // Hidden button for keyboard shortcut
            Button("") {
                if isGenerating {
                    stopGeneration()
                }
            }
            .keyboardShortcut(.delete, modifiers: [.command, .shift])
            .opacity(0)
            .allowsHitTesting(false)
        )
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("AI Chat")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                // New chat button
                Button(action: {
                    startNewChat()
                }) {
                    Image(systemName: "plus.message")
                        .foregroundColor(.gray)
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                .help("Start new chat")
            }
            
            // Model picker
            HStack {
                Button(action: {
                    showModelPicker.toggle()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "brain")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        
                        Text(providerManager.selectedModel.isEmpty ? "Select Model" : providerManager.selectedModel.replacingOccurrences(of: ":latest", with: ""))
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.15, green: 0.15, blue: 0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showModelPicker) {
                    ModelPickerView()
                }
                
                Spacer()
                
                if providerManager.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(red: 0.11, green: 0.11, blue: 0.11))
        .onAppear {
            Task {
                await providerManager.refreshAllModels()
            }
        }
    }
    
    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 16) {
                    ForEach(messages) { message in
                        MessageBubble(message: message, onMessageEdited: {
                            // Only trigger generation if it's a user message
                            if message.isUser {
                                generateResponseForEditedMessage()
                            }
                        }, onRegenerateResponse: { aiMessage in
                            // Only regenerate if it's an AI message
                            if !aiMessage.isUser {
                                regenerateResponse(for: aiMessage)
                            }
                        }, onSaveMessages: {
                            saveMessagesToPersistence()
                        })
                            .id(message.id)
                    }
                    
                    if isTyping {
                        TypingIndicator()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .scrollContentBackground(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.visible)
            .onChange(of: messages.count) {
                if let lastMessage = messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var inputView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                VStack(spacing: 8) {
                    // Selected text attachment inside input box
                    if let attachment = textSelectionManager.selectedAttachment {
                        SelectedTextAttachmentView(attachment: attachment) {
                            textSelectionManager.clearSelection()
                        }
                    }
                    
                    HStack(spacing: 8) {
                        TextField("Ask a question...", text: $inputText)
                            .textFieldStyle(.plain)
                            .foregroundColor(.white)
                            .font(.system(size: 14))
                            .focused($isInputFocused)
                            .onSubmit {
                                sendMessage()
                            }
                        
                        Button(action: isGenerating ? stopGeneration : sendMessage) {
                            Image(systemName: isGenerating ? "stop.fill" : "arrow.up")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(isGenerating ? Color.red : (inputText.isEmpty ? Color.gray.opacity(0.4) : Color(red: 0.0, green: 0.48, blue: 0.4)))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .disabled(!isGenerating && inputText.isEmpty)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, textSelectionManager.selectedAttachment != nil ? 12 : 14)
                .background(Color(red: 0.15, green: 0.15, blue: 0.15))
                .clipShape(RoundedRectangle(cornerRadius: 24))
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
        .background(Color(red: 0.11, green: 0.11, blue: 0.11))
    }
    
    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Prepare the user message content
        var userMessageContent = inputText
        let selectedText = textSelectionManager.selectedAttachment?.text
        
        // If there's selected text, include it in the user message display
        if let context = selectedText {
            userMessageContent = "**Selected text:** \"\(context)\"\n\n**Question:** \(inputText)"
        }
        
        let userMessage = AIChatMessage(content: userMessageContent, isUser: true)
        messages.append(userMessage)
        
        let messageToSend = inputText
        inputText = ""
        
        // Clear the attachment after sending
        textSelectionManager.clearSelection()
        
        // Check if model is selected
        guard !providerManager.selectedModel.isEmpty else {
            let errorMessage = AIChatMessage(content: "Please select a model first.", isUser: false)
            messages.append(errorMessage)
            return
        }
        
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
                }
                
                var fullResponse = ""
                for try await chunk in stream {
                    // Check if task was cancelled
                    if Task.isCancelled {
                        break
                    }
                    
                    fullResponse += chunk
                    await MainActor.run {
                        // Update the content directly on the ObservableObject
                        aiMessage.content = fullResponse
                        // Also update the responses array
                        if aiMessage.responses.isEmpty {
                            aiMessage.responses = [fullResponse]
                        } else {
                            aiMessage.responses[0] = fullResponse
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
    
    private func stopGeneration() {
        currentTask?.cancel()
        currentTask = nil
        isTyping = false
        isGenerating = false
    }
    
    private func loadPersistedMessages() {
        // Load messages from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "AIChatMessages"),
           let decodedMessages = try? JSONDecoder().decode([PersistedMessage].self, from: data) {
            messages = decodedMessages.map { persistedMessage in
                let message = AIChatMessage(content: persistedMessage.content, isUser: persistedMessage.isUser)
                if !persistedMessage.isUser && !persistedMessage.responses.isEmpty {
                    message.responses = persistedMessage.responses
                    message.currentResponseIndex = persistedMessage.currentResponseIndex
                }
                return message
            }
        } else {
            // Default empty state - no initial messages
            messages = []
        }
    }
    
    private func saveMessagesToPersistence() {
        // Convert messages to persistable format
        let persistedMessages = messages.map { message in
            PersistedMessage(
                content: message.content,
                isUser: message.isUser,
                responses: message.responses,
                currentResponseIndex: message.currentResponseIndex
            )
        }
        
        // Save to UserDefaults
        if let data = try? JSONEncoder().encode(persistedMessages) {
            UserDefaults.standard.set(data, forKey: "AIChatMessages")
        }
    }
    
    private func startNewChat() {
        // Stop any ongoing generation
        stopGeneration()
        
        // Clear all messages
        messages.removeAll()
        
        // Clear input text
        inputText = ""
        
        // Clear selected text attachment
        textSelectionManager.clearSelection()
        
        // Save the empty state
        saveMessagesToPersistence()
    }
    
    private func generateResponseForEditedMessage() {
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
                    await MainActor.run {
                        // Update the content directly on the ObservableObject
                        aiMessage.content = fullResponse
                        // Also update the responses array
                        if aiMessage.responses.isEmpty {
                            aiMessage.responses = [fullResponse]
                        } else {
                            aiMessage.responses[0] = fullResponse
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
    
    private func regenerateResponse(for message: AIChatMessage) {
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
                    await MainActor.run {
                        // Update the message content and add to responses
                        message.addResponse(fullResponse)
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

#Preview {
    AIChatProviderView()
        .frame(width: 800, height: 600)
} 