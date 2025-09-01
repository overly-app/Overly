//
//  MessageBubble.swift
//  Overly
//
//  Created by AI Assistant on 1/27/25.
//

import SwiftUI

struct MessageBubble: View {
    @ObservedObject var message: AIChatMessage
    @State private var isHovered = false
    @State private var isEditing = false
    @State private var editedContent = ""
    @State private var showCopyFeedback = false
    let onMessageEdited: (() -> Void)?
    let onRegenerateResponse: ((AIChatMessage) -> Void)?
    let onSaveMessages: (() -> Void)?
    
    init(message: AIChatMessage, onMessageEdited: (() -> Void)? = nil, onRegenerateResponse: ((AIChatMessage) -> Void)? = nil, onSaveMessages: (() -> Void)? = nil) {
        self.message = message
        self.onMessageEdited = onMessageEdited
        self.onRegenerateResponse = onRegenerateResponse
        self.onSaveMessages = onSaveMessages
    }
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 6) {
                    // Message content (editable for user messages)
                    if isEditing {
                        editableMessageView
                    } else {
                        messageContentView
                    }
                    
                    // Action buttons on hover
                    if isHovered && !isEditing {
                        actionButtonsView
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    // Header with AI label only
                    HStack {
                        Text("AI:")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        // Pagination controls for multiple responses
                        if message.responses.count > 1 {
                            HStack(spacing: 4) {
                                Button(action: {
                                    let newIndex = max(0, message.currentResponseIndex - 1)
                                    message.setCurrentResponse(at: newIndex)
                                }) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 10))
                                        .foregroundColor(message.currentResponseIndex > 0 ? .gray : .gray.opacity(0.3))
                                }
                                .buttonStyle(.plain)
                                .disabled(message.currentResponseIndex <= 0)
                                
                                Text("\(message.currentResponseIndex + 1)/\(message.responses.count)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                                
                                Button(action: {
                                    let newIndex = min(message.responses.count - 1, message.currentResponseIndex + 1)
                                    message.setCurrentResponse(at: newIndex)
                                }) {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10))
                                        .foregroundColor(message.currentResponseIndex < message.responses.count - 1 ? .gray : .gray.opacity(0.3))
                                }
                                .buttonStyle(.plain)
                                .disabled(message.currentResponseIndex >= message.responses.count - 1)
                            }
                        }
                    }
                    
                    // Message content with think block support
                    ThinkBlockRenderer(content: message.content, textColor: .white)
                        .textSelection(.enabled)
                    
                    // Action buttons at the bottom - only show when response is complete
                    if !message.isGenerating {
                        HStack {
                            // Regenerate button (only for AI messages)
                            Button(action: {
                                regenerateResponse(for: message)
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                                    .frame(width: 20, height: 20)
                            }
                            .buttonStyle(.plain)
                            .help("Regenerate response")
                            
                            // Copy button next to regenerate
                            Button(action: copyMessage) {
                                Image(systemName: showCopyFeedback ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 12))
                                    .foregroundColor(showCopyFeedback ? .green : .gray)
                                    .frame(width: 20, height: 20)
                            }
                            .buttonStyle(.plain)
                            .help("Copy response")
                            
                            Spacer()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
            }
        }
        .onHover { hovering in
            // Only update hover state for user messages to reduce unnecessary updates
            if message.isUser {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = hovering
                }
            }
        }
        .onAppear {
            editedContent = message.content
        }
    }
    
    // MARK: - Message Content Views
    
    @ViewBuilder
    private var messageContentView: some View {
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
                VStack(alignment: .trailing) {
                    ThinkBlockRenderer(content: questionPart, textColor: .white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(red: 0.0, green: 0.48, blue: 0.4))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .frame(maxWidth: 280, alignment: .trailing)
            } else {
                // Fallback to regular display
                VStack(alignment: .trailing) {
                    ThinkBlockRenderer(content: message.content, textColor: .white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(red: 0.0, green: 0.48, blue: 0.4))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .frame(maxWidth: 280, alignment: .trailing)
            }
        } else {
            // Regular message without selected text
            VStack(alignment: .trailing) {
                ThinkBlockRenderer(content: message.content, textColor: .white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(red: 0.0, green: 0.48, blue: 0.4))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .frame(maxWidth: 280, alignment: .trailing)
        }
    }
    
    private var editableMessageView: some View {
        VStack(alignment: .trailing, spacing: 8) {
            // Text editor for editing
            TextEditor(text: $editedContent)
                .font(.system(size: 14))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(red: 0.0, green: 0.48, blue: 0.4).opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .frame(maxWidth: 280, minHeight: 60, alignment: .trailing)
                .scrollContentBackground(.hidden)
                .onKeyPress(.escape) {
                    // Cancel editing on Esc
                    editedContent = message.content
                    isEditing = false
                    return .handled
                }
                .overlay(
                    // Hidden button for Cmd+Enter shortcut
                    Button("") {
                        message.content = editedContent
                        isEditing = false
                        onMessageEdited?()
                        onSaveMessages?()
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                    .opacity(0)
                    .allowsHitTesting(false)
                )
            
            // Edit action buttons
            HStack(spacing: 8) {
                Button("Cancel") {
                    editedContent = message.content
                    isEditing = false
                }
                .foregroundColor(.secondary)
                .font(.system(size: 12))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Button("Save") {
                    message.content = editedContent
                    isEditing = false
                    onMessageEdited?()
                    onSaveMessages?()
                }
                .foregroundColor(.white)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(red: 0.0, green: 0.48, blue: 0.4))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
    
    private var actionButtonsView: some View {
        HStack(spacing: 8) {
            // Copy button for user messages
            Button(action: copyMessage) {
                Image(systemName: showCopyFeedback ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 12))
                    .foregroundColor(showCopyFeedback ? .green : .gray)
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Copy message")
            
            // Edit button (only for user messages)
            if message.isUser {
                Button(action: { isEditing = true }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Edit message")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .trailing).combined(with: .opacity)
        ))
    }
    
    // MARK: - Actions
    
    private func copyMessage() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        // For user messages with selected text, copy just the question part
        if message.isUser && message.content.contains("**Selected text:**") {
            let components = message.content.components(separatedBy: "\n\n**Question:** ")
            if components.count == 2 {
                pasteboard.setString(components[1], forType: .string)
            } else {
                pasteboard.setString(message.content, forType: .string)
            }
        } else {
            pasteboard.setString(message.content, forType: .string)
        }
        
        // Show feedback
        showCopyFeedback = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showCopyFeedback = false
        }
    }
    
    private func regenerateResponse(for message: AIChatMessage) {
        onRegenerateResponse?(message)
    }
} 