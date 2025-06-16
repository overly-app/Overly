//
//  AIChatSidebar.swift
//  Overly
//
//  Created by AI Assistant on 1/27/25.
//

import SwiftUI

class AIChatMessage: ObservableObject, Identifiable {
    let id = UUID()
    @Published var content: String
    let isUser: Bool
    let timestamp: Date = Date()
    
    init(content: String, isUser: Bool) {
        self.content = content
        self.isUser = isUser
    }
}

struct AIChatSidebar: View {
    @Binding var isVisible: Bool
    @State private var messages: [AIChatMessage] = []
    @State private var inputText: String = ""
    @State private var isTyping: Bool = false
    @FocusState private var isInputFocused: Bool
    @StateObject private var textSelectionManager = TextSelectionManager.shared
    @StateObject private var ollamaManager = OllamaManager.shared
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
        .background(Color(red: 0.11, green: 0.11, blue: 0.11)) // Dark background like the image
        .onAppear {
            loadInitialMessages()
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("AI Assistant")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isVisible = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.gray)
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                .help("Close sidebar")
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
                        
                        Text(ollamaManager.selectedModel.isEmpty ? "Select Model" : ollamaManager.selectedModel.replacingOccurrences(of: ":latest", with: ""))
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
                
                if ollamaManager.isLoading {
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
                await ollamaManager.fetchModels()
            }
        }
    }
    
    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                    
                    if isTyping {
                        TypingIndicator()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
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
                        TextField("Ask another question...", text: $inputText)
                            .textFieldStyle(.plain)
                            .foregroundColor(.white)
                            .font(.system(size: 14))
                            .focused($isInputFocused)
                            .onSubmit {
                                sendMessage()
                            }
                        
                        Button(action: sendMessage) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(inputText.isEmpty ? Color.gray.opacity(0.4) : Color(red: 0.0, green: 0.48, blue: 0.4))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .disabled(inputText.isEmpty)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, textSelectionManager.selectedAttachment != nil ? 12 : 14) // Dynamic padding based on attachment
                .background(Color(red: 0.15, green: 0.15, blue: 0.15)) // Slightly lighter than main background
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
        
        // Check if Ollama model is selected
        guard !ollamaManager.selectedModel.isEmpty else {
            let errorMessage = AIChatMessage(content: "Please select an Ollama model first.", isUser: false)
            messages.append(errorMessage)
            return
        }
        
        // Show typing indicator
        isTyping = true
        
        Task {
            do {
                // Prepare messages for Ollama
                var ollamaMessages: [OllamaChatMessage] = []
                
                // Add context if there's selected text
                if let context = selectedText {
                    ollamaMessages.append(OllamaChatMessage(
                        role: "system",
                        content: "The user has selected this text from a webpage: \"\(context)\". Please analyze this text and answer their question in relation to it. Reference specific parts of the selected text when relevant."
                    ))
                }
                
                // Add conversation history (last few messages for context)
                let recentMessages = messages.suffix(6) // Last 6 messages for context
                for msg in recentMessages {
                    if msg.id != userMessage.id { // Don't include the message we just added
                        ollamaMessages.append(OllamaChatMessage(
                            role: msg.isUser ? "user" : "assistant",
                            content: msg.content
                        ))
                    }
                }
                
                // Add the current user message
                ollamaMessages.append(OllamaChatMessage(role: "user", content: messageToSend))
                
                // Send to Ollama and stream response
                let stream = try await ollamaManager.sendChatMessage(messages: ollamaMessages)
                
                await MainActor.run {
                    isTyping = false
                }
                
                // Create AI message and stream content
                let aiMessage = AIChatMessage(content: "", isUser: false)
                await MainActor.run {
                    messages.append(aiMessage)
                }
                
                var fullResponse = ""
                for try await chunk in stream {
                    print("Received chunk: '\(chunk)'") // Debug logging
                    fullResponse += chunk
                    await MainActor.run {
                        // Update the content directly on the ObservableObject
                        aiMessage.content = fullResponse
                    }
                }
                
            } catch {
                await MainActor.run {
                    isTyping = false
                    let errorMessage = AIChatMessage(content: "Error: \(error.localizedDescription)", isUser: false)
                    messages.append(errorMessage)
                }
            }
        }
    }
    
    private func loadInitialMessages() {
        if ollamaManager.selectedModel.isEmpty {
            messages = [
                AIChatMessage(content: "Hello! Please select an Ollama model to start chatting.", isUser: false)
            ]
        } else {
            messages = [
                AIChatMessage(content: "Hello! I'm ready to help you. What would you like to know?", isUser: false)
            ]
        }
    }
}

struct MessageBubble: View {
    @ObservedObject var message: AIChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 6) {
                    // Parse and display the message content
                    if message.content.contains("**Selected text:**") {
                        // This is a message with selected text
                        let components = message.content.components(separatedBy: "\n\n**Question:** ")
                        if components.count == 2 {
                            let selectedTextPart = components[0].replacingOccurrences(of: "**Selected text:** \"", with: "").replacingOccurrences(of: "\"", with: "")
                            let questionPart = components[1]
                            
                            // Selected text context (smaller, lighter)
                            Text("📄 \(selectedTextPart)")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .frame(maxWidth: 280, alignment: .trailing)
                            
                            // User's question (main message)
                            Text(questionPart)
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(red: 0.0, green: 0.48, blue: 0.4))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .frame(maxWidth: 280, alignment: .trailing)
                        } else {
                            // Fallback to regular display
                            Text(message.content)
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(red: 0.0, green: 0.48, blue: 0.4))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .frame(maxWidth: 280, alignment: .trailing)
                        }
                    } else {
                        // Regular message without selected text
                        Text(message.content)
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(red: 0.0, green: 0.48, blue: 0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .frame(maxWidth: 280, alignment: .trailing)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Text(message.content)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
            }
        }
    }
}

struct TypingIndicator: View {
    @State private var animationPhase = 0
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("AI:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.gray)
                            .frame(width: 6, height: 6)
                            .opacity(animationPhase == index ? 1.0 : 0.3)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            
            Spacer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever()) {
                animationPhase = (animationPhase + 1) % 3
            }
        }
    }
}

struct SelectedTextAttachmentView: View {
    let attachment: SelectedTextAttachment
    let onRemove: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                // AI icon
                HStack(spacing: 6) {
                    Text("AI")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 16, height: 16)
                        .background(Color.gray.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(attachment.source)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                        
                        Text("Selected Text")
                            .font(.system(size: 9))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // Close button (appears on hover)
                if isHovering {
                    Button(action: onRemove) {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.gray)
                            .frame(width: 14, height: 14)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Selected text content
            Text(attachment.text)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(.leading, 22) // Align with the text above
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(red: 0.1, green: 0.1, blue: 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct ModelPickerView: View {
    @StateObject private var ollamaManager = OllamaManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Select Ollama Model")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Refresh") {
                    Task {
                        await ollamaManager.fetchModels()
                    }
                }
                .font(.caption)
            }
            
            if ollamaManager.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading models...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 20)
            } else if ollamaManager.availableModels.isEmpty {
                VStack(spacing: 8) {
                    Text("No models found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Make sure Ollama is running and has models installed")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 20)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(ollamaManager.availableModels) { model in
                            ModelRow(
                                model: model,
                                isSelected: model.name == ollamaManager.selectedModel
                            ) {
                                ollamaManager.selectedModel = model.name
                                dismiss()
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
            
            if let error = ollamaManager.error {
                Text("Error: \(error)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 8)
            }
        }
        .padding(16)
        .frame(minWidth: 280)
        .onAppear {
            if ollamaManager.availableModels.isEmpty {
                Task {
                    await ollamaManager.fetchModels()
                }
            }
        }
    }
}

struct ModelRow: View {
    let model: OllamaModel
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        if let details = model.details {
                            if let paramSize = details.parameterSize {
                                Text(paramSize)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let quantization = details.quantizationLevel {
                                Text(quantization)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Text(model.sizeFormatted)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 16))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AIChatSidebar(isVisible: .constant(true))
        .frame(width: 300, height: 500)
} 