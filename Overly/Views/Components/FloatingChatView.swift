//
//  FloatingChatView.swift
//  Overly
//
//  Created by AI Assistant on 1/27/25.
//

import SwiftUI

// Floating chat view without headers
struct FloatingChatView: View {
    @Binding var messages: [AIChatMessage]
    @Binding var inputText: String
    @Binding var isTyping: Bool
    @Binding var isGenerating: Bool
    @Binding var currentTask: Task<Void, Never>?
    @ObservedObject var textSelectionManager: TextSelectionManager
    @ObservedObject var providerManager: AIProviderManager
    @Binding var showModelPicker: Bool
    @FocusState private var isInputFocused: Bool
    
    let onSwitchToSidebar: () -> Void
    let onStartNewChat: () -> Void
    let onSaveMessages: () -> Void
    let onGenerateResponseForEditedMessage: () -> Void
    let onRegenerateResponse: (AIChatMessage) -> Void
    let onSendMessage: () -> Void
    let onStopGeneration: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Minimal header with just controls
            HStack {
                // Model picker
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
                
                // New chat button
                Button(action: onStartNewChat) {
                    Image(systemName: "plus.message")
                        .foregroundColor(.gray)
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 28, height: 28)
                        .background(Color(red: 0.15, green: 0.15, blue: 0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Start new chat")
                
                // Switch to sidebar button
                Button(action: {
                    // Add safety check to prevent multiple rapid calls
                    onSwitchToSidebar()
                }) {
                    Image(systemName: "sidebar.left")
                        .foregroundColor(.gray)
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 28, height: 28)
                        .background(Color(red: 0.15, green: 0.15, blue: 0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Switch to sidebar")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(red: 0.11, green: 0.11, blue: 0.11))
            
            // Divider
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)
            
            // Messages view (reuse the same logic)
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 16) {
                        ForEach(messages) { message in
                            MessageBubble(message: message, onMessageEdited: {
                                // Only trigger generation if it's a user message
                                if message.isUser {
                                    onGenerateResponseForEditedMessage()
                                }
                            }, onRegenerateResponse: { aiMessage in
                                // Only regenerate if it's an AI message
                                if !aiMessage.isUser {
                                    onRegenerateResponse(aiMessage)
                                }
                            }, onSaveMessages: {
                                onSaveMessages()
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
            
            // Divider
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)
            
            // Input area (reuse the same logic)
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
                                    onSendMessage()
                                }
                            
                            Button(action: isGenerating ? onStopGeneration : onSendMessage) {
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
        .background(Color(red: 0.11, green: 0.11, blue: 0.11))
        .onAppear {
            Task {
                await providerManager.refreshAllModels()
            }
        }
    }
} 