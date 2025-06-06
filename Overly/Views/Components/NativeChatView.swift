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
                    sidebarView
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
    }
    
    // MARK: - Sidebar
    
    private var sidebarView: some View {
        VStack(spacing: 0) {
            // Sidebar header
            sidebarHeader
            
            // Chat sessions list
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(chatManager.sessions) { session in
                        chatSessionRow(session)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            
            Spacer()
            
            // Sidebar footer
            sidebarFooter
        }
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(Color(NSColor.separatorColor)),
            alignment: .trailing
        )
    }
    
    private var sidebarHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: { chatManager.createNewSession() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .medium))
                        Text("New chat")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                
                Button(action: { showingSidebar = false }) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
    }
    
    private func chatSessionRow(_ session: ChatSession) -> some View {
        Button(action: { chatManager.selectSession(session) }) {
            HStack(spacing: 8) {
                providerIcon(session.provider)
                    .font(.system(size: 12))
                
                Text(session.title)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if session.isActive {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 6, height: 6)
                }
            }
            .foregroundColor(session.isActive ? .primary : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(session.isActive ? Color.accentColor.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Delete") {
                chatManager.deleteSession(session)
            }
        }
    }
    
    private var sidebarFooter: some View {
        VStack(spacing: 8) {
            Divider()
            
            HStack {
                Button(action: { showingProviderSettings = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 12))
                        Text("Settings")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Provider indicator
                providerIcon(chatManager.selectedProvider)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Main Chat View
    
    private var mainChatView: some View {
        VStack(spacing: 0) {
            // Top header
            chatHeader
            
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
    
    private var chatHeader: some View {
        HStack(spacing: 12) {
            // Sidebar toggle
            if !showingSidebar {
                Button(action: { 
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingSidebar = true
                    }
                }) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // Current session title or provider
            if let session = chatManager.currentSession {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.title)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        providerIcon(session.provider)
                            .font(.system(size: 10))
                        Text(session.model)
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.secondary)
                }
            } else {
                Text("Chat")
                    .font(.system(size: 16, weight: .semibold))
            }
            
            Spacer()
            
            // Model selector
            if !chatManager.availableModels.isEmpty {
                modelSelector
            }
            
            // Action buttons
            HStack(spacing: 8) {
                Button(action: { chatManager.createNewSession() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("New Chat")
                
                Button(action: { showingProviderSettings = true }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(NSColor.separatorColor)),
            alignment: .bottom
        )
    }
    
    private var modelSelector: some View {
        Menu {
            ForEach(chatManager.availableModels, id: \.self) { model in
                Button(model) {
                    if let session = chatManager.currentSession {
                        session.model = model
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(chatManager.currentSession?.model ?? chatManager.selectedProvider.defaultModel)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
        }
        .menuStyle(.borderlessButton)
    }
    

    
    private func providerIcon(_ provider: ChatProviderType) -> some View {
        Group {
            if provider.isSystemIcon {
                Image(systemName: provider.iconName)
                    .font(.system(size: 12, weight: .medium))
            } else {
                Image(provider.iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)
            }
        }
        .foregroundColor(.primary)
    }
    
    // MARK: - Chat Interface
    
    private func chatInterfaceView(session: ChatSession) -> some View {
        VStack(spacing: 0) {
            // Messages area
            messagesScrollView(session: session)
            
            // Input area
            messageInputView
        }
    }
    
    private func messagesScrollView(session: ChatSession) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    if session.messages.isEmpty {
                        welcomeMessage
                            .padding(.top, 60)
                    } else {
                        ForEach(session.messages) { message in
                            ChatGPTMessageView(message: message)
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
    
    private var welcomeMessage: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                providerIcon(chatManager.selectedProvider)
                    .font(.system(size: 48))
                    .foregroundColor(.primary)
                
                VStack(spacing: 8) {
                    Text("How can I help you today?")
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("I'm \(chatManager.selectedProvider.displayName), ready to assist you with any questions or tasks.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                }
            }
            
            // Example prompts (like ChatGPT)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                examplePrompt("Explain quantum computing", "science")
                examplePrompt("Write a creative story", "pencil")
                examplePrompt("Help with coding", "chevron.left.forwardslash.chevron.right")
                examplePrompt("Plan a trip", "airplane")
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func examplePrompt(_ text: String, _ icon: String) -> some View {
        Button(action: {
            messageText = text
            sendMessage()
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                
                Text(text)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Message Input
    
    private var messageInputView: some View {
        VStack(spacing: 0) {
            // Error message
            if let errorMessage = chatManager.errorMessage {
                errorBanner(errorMessage)
            }
            
            // Input container
            VStack(spacing: 12) {
                // Input field
                HStack(alignment: .bottom, spacing: 12) {
                    // Text input
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(NSColor.controlBackgroundColor))
                            .stroke(isInputFocused ? Color.accentColor : Color(NSColor.separatorColor), lineWidth: 1.5)
                        
                        HStack(alignment: .bottom, spacing: 8) {
                            TextField("Message \(chatManager.selectedProvider.displayName)...", text: $messageText, axis: .vertical)
                                .textFieldStyle(.plain)
                                .font(.system(size: 16))
                                .lineLimit(1...8)
                                .focused($isInputFocused)
                                .onSubmit {
                                    if !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        sendMessage()
                                    }
                                }
                                .disabled(chatManager.isLoading)
                            
                            // Send button
                            Button(action: sendMessage) {
                                ZStack {
                                    Circle()
                                        .fill(canSendMessage ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                                        .frame(width: 28, height: 28)
                                    
                                    Image(systemName: chatManager.isLoading ? "stop.fill" : "arrow.up")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(canSendMessage ? .white : .secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(!canSendMessage && !chatManager.isLoading)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .frame(minHeight: 32)
                }
                
                // Footer text
                Text("Overly can make mistakes. Check important info.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(Color(NSColor.windowBackgroundColor))
        }
    }
    
    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.primary)
            
            Spacer()
            
            Button("Dismiss") {
                chatManager.errorMessage = nil
            }
            .font(.caption)
            .foregroundColor(.accentColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
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
    
    // MARK: - Helper Properties
    
    private var canSendMessage: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !chatManager.isLoading
    }
    
    // MARK: - Actions
    
    private func sendMessage() {
        let message = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        
        messageText = ""
        chatManager.sendMessage(message)
    }
}

// MARK: - ChatGPT-Style Message View

struct ChatGPTMessageView: View {
    let message: ChatMessage
    @State private var isHovered = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 0) {
                // Message content
                HStack(alignment: .top, spacing: 16) {
                    // Avatar
                    messageAvatar
                        .frame(width: 32, height: 32)
                    
                    // Content
                    VStack(alignment: .leading, spacing: 8) {
                        // Provider name
                        Text(message.role == .user ? "You" : providerDisplayName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        // Message text
                        if message.isStreaming && message.content.isEmpty {
                            typingIndicator
                        } else {
                            Text(message.content)
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            if message.isStreaming {
                                streamingCursor
                            }
                        }
                        
                        // Timestamp
                        if isHovered {
                            Text(timeString)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(message.role == .user ? Color.clear : Color(NSColor.controlBackgroundColor).opacity(0.3))
                
                // Action buttons
                if isHovered && !message.isStreaming {
                    actionButtons
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)
                }
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            contextMenuItems
        }
    }
    
    private var messageAvatar: some View {
        Group {
            if message.role == .user {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.blue, Color.purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    )
            } else {
                Circle()
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        Circle()
                            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                    )
                    .overlay(
                        providerIcon
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                    )
            }
        }
    }
    
    private var providerIcon: some View {
        Group {
            if let provider = ChatProviderType(rawValue: message.provider) {
                if provider.isSystemIcon {
                    Image(systemName: provider.iconName)
                } else {
                    Image(provider.iconName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                }
            } else {
                Image(systemName: "brain")
            }
        }
    }
    
    private var providerDisplayName: String {
        if let provider = ChatProviderType(rawValue: message.provider) {
            return provider.displayName
        }
        return "Assistant"
    }
    
    private var typingIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 6, height: 6)
                    .scaleEffect(typingScale(for: index))
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(index) * 0.2),
                        value: true
                    )
            }
        }
        .onAppear {
            // Animation trigger
        }
    }
    
    private var streamingCursor: some View {
        Rectangle()
            .fill(Color.primary)
            .frame(width: 2, height: 20)
            .opacity(streamingOpacity)
            .animation(
                .easeInOut(duration: 0.8).repeatForever(),
                value: streamingOpacity
            )
            .onAppear {
                streamingOpacity = 0.3
            }
    }
    
    @State private var streamingOpacity: Double = 1.0
    
    private func typingScale(for index: Int) -> Double {
        return 1.0 // Would be animated in real implementation
    }
    
    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button(action: copyMessage) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Copy")
            
            if message.role == .assistant {
                Button(action: regenerateMessage) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Regenerate")
            }
        }
    }
    
    private var contextMenuItems: some View {
        Group {
            Button("Copy") {
                copyMessage()
            }
            
            if message.role == .assistant {
                Button("Regenerate") {
                    regenerateMessage()
                }
            }
        }
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: message.timestamp)
    }
    
    private func copyMessage() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(message.content, forType: .string)
    }
    
    private func regenerateMessage() {
        // TODO: Implement regeneration
    }
}

// MARK: - Supporting Views

struct ToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed ? Color.primary.opacity(0.1) : Color.clear)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

#Preview {
    NativeChatView()
        .frame(width: 500, height: 600)
} 