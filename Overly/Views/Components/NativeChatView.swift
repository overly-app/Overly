//
//  NativeChatView.swift
//  Overly
//
//  Created by AI Assistant on 1/27/25.
//

import SwiftUI

struct NativeChatView: View {
    @StateObject private var chatManager = ChatManager.shared
    @State private var messageText = ""
    @State private var showingProviderSettings = false
    @State private var showingSidebar = false
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Sidebar (like ChatGPT)
                if showingSidebar {
                    ChatSidebarView(
                        chatManager: chatManager,
                        showingProviderSettings: $showingProviderSettings,
                        showingSidebar: $showingSidebar
                    )
                    .frame(width: 260)
                    .transition(.move(edge: .leading))
                }
                
                // Main chat area
                mainChatView
                    .frame(maxWidth: .infinity)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $chatManager.showingAPIKeySetup) {
            APIKeySetupView()
        }
        .sheet(isPresented: $showingProviderSettings) {
            ChatProviderSettingsView()
        }
        .onAppear {
            chatManager.updateAvailableProviders()
            if !chatManager.availableProviders.isEmpty {
                Task {
                    await chatManager.fetchModelsForProvider(chatManager.selectedProvider)
                }
            }
        }
        .onChange(of: chatManager.selectedProvider) { _, newProvider in
            Task {
                await chatManager.fetchModelsForProvider(newProvider)
            }
        }
    }
    
    // MARK: - Main Chat View
    
    private var mainChatView: some View {
        VStack(spacing: 0) {
            // Top header
            ChatHeaderView(
                chatManager: chatManager,
                showingSidebar: $showingSidebar,
                showingProviderSettings: $showingProviderSettings
            )
            
            // Chat content
            if chatManager.availableProviders.isEmpty {
                emptyStateView
            } else if let session = chatManager.currentSession {
                chatInterfaceView(session: session)
            } else {
                loadingStateView
            }
        }
    }
    
    // MARK: - Chat Interface
    
    private func chatInterfaceView(session: ChatSession) -> some View {
        VStack(spacing: 0) {
            // Messages area
            messagesScrollView(session: session)
            
            // Input area
            ChatInputView(
                chatManager: chatManager,
                messageText: $messageText,
                isInputFocused: _isInputFocused
            )
        }
    }
    
    private func messagesScrollView(session: ChatSession) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    if session.messages.isEmpty {
                        ChatWelcomeView(
                            chatManager: chatManager,
                            messageText: $messageText,
                            onExampleTap: sendMessage
                        )
                    } else {
                        ForEach(session.messages) { message in
                            ChatMessageView(message: message)
                                .id(message.id)
                        }
                    }
                }
                .padding(.bottom, 20)
            }
            .onChange(of: session.messages.count) { _, _ in
                if let lastMessage = session.messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - Empty States
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "key.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                Text("API Keys Required")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Add your API keys to start chatting with AI models")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Setup API Keys") {
                chatManager.showingAPIKeySetup = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: 300)
    }
    
    private var loadingStateView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Setting up chat...")
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Actions
    
    private func sendMessage() {
        let message = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        
        messageText = ""
        chatManager.sendMessage(message)
    }
}

#Preview {
    NativeChatView()
        .frame(width: 500, height: 600)
} 