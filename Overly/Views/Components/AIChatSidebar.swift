//
//  AIChatSidebar.swift
//  Overly
//
//  Created by AI Assistant on 1/27/25.
//

import SwiftUI

struct AIChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date = Date()
}

struct AIChatSidebar: View {
    @Binding var isVisible: Bool
    @State private var messages: [AIChatMessage] = []
    @State private var inputText: String = ""
    @State private var isTyping: Bool = false
    @FocusState private var isInputFocused: Bool
    @StateObject private var textSelectionManager = TextSelectionManager.shared
    
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(red: 0.11, green: 0.11, blue: 0.11))
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
            .onChange(of: messages.count) { _ in
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
        
        let userMessage = AIChatMessage(content: inputText, isUser: true)
        messages.append(userMessage)
        
        let messageToSend = inputText
        let selectedText = textSelectionManager.selectedAttachment?.text
        inputText = ""
        
        // Clear the attachment after sending
        textSelectionManager.clearSelection()
        
        // Simulate AI typing
        isTyping = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isTyping = false
            let aiResponse = generateMockResponse(for: messageToSend, withContext: selectedText)
            let aiMessage = AIChatMessage(content: aiResponse, isUser: false)
            messages.append(aiMessage)
        }
    }
    
    private func loadInitialMessages() {
        messages = [
            AIChatMessage(content: "Sure thing! Here's a mock AI chat for you.", isUser: false)
        ]
    }
    
    private func generateMockResponse(for input: String, withContext selectedText: String? = nil) -> String {
        if let context = selectedText {
            let contextResponses = [
                "I can see you've selected some text: \"\(context.prefix(50))...\". Based on this context, here's what I think...",
                "Thanks for sharing that text selection. Let me help you understand this better...",
                "I notice you highlighted: \"\(context.prefix(50))...\". This relates to your question about...",
                "Based on the text you selected, I can provide some insights...",
                "That's an interesting selection! Let me explain what this means..."
            ]
            return contextResponses.randomElement() ?? "Thanks for the context! I'm here to help."
        }
        
        let responses = [
            "I'd love to help, but I don't have real-time weather data. Maybe check your favorite weather app?",
            "Why do programmers prefer dark mode? Because light attracts bugs.",
            "Build something you actually want to use. Docs are great, but nothing beats hands-on chaos.",
            "You've got options: AltStore, SideStore, TrollStore (if you're lucky with your device). Each has its quirks, but SideStore is pretty smooth for most modern devices.",
            "Here's a simple function:\n\nfunction reverseString(str) {\n    return str.split('').reverse().join('');\n}",
            "That's a great question! Let me think about that for a moment...",
            "I can help you with that. What specific aspect would you like to know more about?",
            "Interesting! Here's what I think about that topic..."
        ]
        return responses.randomElement() ?? "Thanks for your question! I'm here to help."
    }
}

struct MessageBubble: View {
    let message: AIChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
                
                Text(message.content)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.0, green: 0.48, blue: 0.4)) // Green like in the image
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .frame(maxWidth: 250, alignment: .trailing)
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

#Preview {
    AIChatSidebar(isVisible: .constant(true))
        .frame(width: 300, height: 500)
} 