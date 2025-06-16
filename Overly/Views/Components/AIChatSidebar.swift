//
//  AIChatSidebar.swift
//  Overly
//
//  Created by AI Assistant on 1/27/25.
//

import SwiftUI

// Shared state manager for AI Chat Sidebar
class AIChatSidebarManager: ObservableObject {
    static let shared = AIChatSidebarManager()
    
    @Published var displayMode: ChatDisplayMode = .sidebar
    @Published var floatingWindow: NSWindow?
    @Published var windowDelegate: FloatingWindowDelegate?
    
    private init() {}
    
    enum ChatDisplayMode: String, CaseIterable {
        case sidebar = "Sidebar"
        case floating = "Floating"
        
        var icon: String {
            switch self {
            case .sidebar: return "sidebar.left"
            case .floating: return "macwindow"
            }
        }
    }
    
    // Method to handle Cmd+E shortcut based on current display mode
    func handleToggleShortcut(sidebarVisibility: Binding<Bool>) {
        switch displayMode {
        case .sidebar:
            // Toggle sidebar visibility
            withAnimation(.easeInOut(duration: 0.15)) {
                sidebarVisibility.wrappedValue.toggle()
            }
        case .floating:
            // Focus the floating window if it exists
            if let window = floatingWindow {
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}

// Struct for persisting messages to UserDefaults
struct PersistedMessage: Codable {
    let content: String
    let isUser: Bool
    let responses: [String]
    let currentResponseIndex: Int
    
    init(content: String, isUser: Bool, responses: [String] = [], currentResponseIndex: Int = 0) {
        self.content = content
        self.isUser = isUser
        self.responses = responses
        self.currentResponseIndex = currentResponseIndex
    }
}

class AIChatMessage: ObservableObject, Identifiable {
    let id = UUID()
    @Published var content: String
    let isUser: Bool
    let timestamp: Date = Date()
    @Published var responses: [String] = [] // For AI messages with multiple responses
    @Published var currentResponseIndex: Int = 0
    @Published var isGenerating: Bool = false // Track if this message is currently being generated
    
    init(content: String, isUser: Bool) {
        self.content = content
        self.isUser = isUser
        if !isUser {
            self.responses = [content]
            self.isGenerating = content.isEmpty // If content is empty, it's still generating
        }
    }
    
    func addResponse(_ response: String) {
        if !isUser {
            responses.append(response)
            currentResponseIndex = responses.count - 1
            content = response
        }
    }
    
    func clearResponses() {
        if !isUser {
            responses.removeAll()
            content = ""
            currentResponseIndex = 0
            isGenerating = true
        }
    }
    
    func setCurrentResponse(at index: Int) {
        if !isUser && index >= 0 && index < responses.count {
            currentResponseIndex = index
            content = responses[index]
        }
    }
    
    func markGenerationComplete() {
        if !isUser {
            isGenerating = false
        }
    }
    
    func startGenerating() {
        if !isUser {
            isGenerating = true
        }
    }
}

struct AIChatSidebar: View {
    @Binding var isVisible: Bool
    @State private var messages: [AIChatMessage] = []
    @State private var inputText: String = ""
    @State private var isTyping: Bool = false
    @State private var isGenerating: Bool = false
    @State private var currentTask: Task<Void, Never>?
    @FocusState private var isInputFocused: Bool
    @StateObject private var textSelectionManager = TextSelectionManager.shared
    @StateObject private var providerManager = AIProviderManager.shared
    @State private var showModelPicker = false
    @StateObject private var sidebarManager = AIChatSidebarManager.shared
    
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
                Text("AI Assistant")
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
                
                // Display mode dropdown
                Menu {
                    ForEach(AIChatSidebarManager.ChatDisplayMode.allCases, id: \.self) { mode in
                        Button(action: {
                            switchDisplayMode(to: mode)
                        }) {
                            HStack {
                                Image(systemName: mode.icon)
                                Text(mode.rawValue)
                                if sidebarManager.displayMode == mode {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: sidebarManager.displayMode.icon)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        
                        Text(sidebarManager.displayMode.rawValue)
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
                .help("Change display mode")
                
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
                        TextField("Ask another question...", text: $inputText)
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
                        .onChange(of: isGenerating) { newValue in
                            print("DEBUG: Button detected isGenerating changed to: \(newValue)")
                        }
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
        .overlay(
            // Hidden button for keyboard shortcut
            Button("") {
                print("DEBUG: Keyboard shortcut triggered, isGenerating: \(isGenerating)")
                if isGenerating {
                    stopGeneration()
                }
            }
            .keyboardShortcut(KeyEquivalent.delete, modifiers: [.command, .shift])
            .opacity(0)
            .allowsHitTesting(false)
        )
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
        print("DEBUG: Set isGenerating = true")
        
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
                    
                    print("Received chunk: '\(chunk)'") // Debug logging
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
                    print("DEBUG: Set isGenerating = false (completed)")
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
        print("DEBUG: stopGeneration called")
        currentTask?.cancel()
        currentTask = nil
        isTyping = false
        isGenerating = false
        print("DEBUG: Set isGenerating = false (stopped)")
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
        print("DEBUG: Set isGenerating = true (edited message)")
        
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
                    
                    print("Received chunk: '\(chunk)'") // Debug logging
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
                    print("DEBUG: Set isGenerating = false (edited message completed)")
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
        print("DEBUG: Set isGenerating = true (regenerating)")
        
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
                    
                    print("Received chunk: '\(chunk)'") // Debug logging
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
                    print("DEBUG: Set isGenerating = false (regeneration completed)")
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
    
    private func switchDisplayMode(to mode: AIChatSidebarManager.ChatDisplayMode) {
        // Prevent rapid switching
        guard sidebarManager.displayMode != mode else { return }
        
        sidebarManager.displayMode = mode
        
        switch mode {
        case .sidebar:
            // Close floating window if it exists
            if let window = sidebarManager.floatingWindow {
                window.delegate = nil // Clear delegate first
                window.close()
            }
            sidebarManager.floatingWindow = nil
            sidebarManager.windowDelegate = nil // Clear delegate reference
            // Show sidebar
            isVisible = true
            
        case .floating:
            // Hide sidebar
            isVisible = false
            // Create floating window
            createFloatingWindow()
        }
    }
    
    private func createFloatingWindow() {
        // Close existing window if any
        sidebarManager.floatingWindow?.close()
        
        // Create new floating window with custom properties
        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 400, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "AI Assistant"
        window.isReleasedWhenClosed = false
        window.center()
        
        // Set window level to float above other windows including borderless ones
        window.level = .floating
        
        // Make it stay on top and visible
        window.hidesOnDeactivate = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Set appearance
        window.titlebarAppearsTransparent = false
        window.backgroundColor = NSColor(red: 0.11, green: 0.11, blue: 0.11, alpha: 1.0)
        
        // Create the floating chat view
        let floatingChatView = FloatingChatView(
            messages: $messages,
            inputText: $inputText,
            isTyping: $isTyping,
            isGenerating: $isGenerating,
            currentTask: $currentTask,
            textSelectionManager: textSelectionManager,
            providerManager: providerManager,
            showModelPicker: $showModelPicker,
            onSwitchToSidebar: {
                // Use DispatchQueue.main.async to safely update state
                DispatchQueue.main.async {
                    self.switchDisplayMode(to: .sidebar)
                }
            },
            onStartNewChat: {
                startNewChat()
            },
            onSaveMessages: {
                saveMessagesToPersistence()
            },
            onGenerateResponseForEditedMessage: {
                generateResponseForEditedMessage()
            },
            onRegenerateResponse: { message in
                regenerateResponse(for: message)
            },
            onSendMessage: {
                sendMessage()
            },
            onStopGeneration: {
                stopGeneration()
            }
        )
        
        window.contentView = NSHostingView(rootView: floatingChatView)
        window.makeKeyAndOrderFront(nil)
        
        // Ensure it's visible and focused
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        
        // Store reference in the shared manager
        sidebarManager.floatingWindow = window
        
        // Handle window closing with safer callback
        let delegate = FloatingWindowDelegate {
            // Use DispatchQueue.main.async to safely update state
            DispatchQueue.main.async {
                self.sidebarManager.displayMode = .sidebar
                self.sidebarManager.floatingWindow = nil
                self.sidebarManager.windowDelegate = nil
                self.isVisible = true
            }
        }
        window.delegate = delegate
        sidebarManager.windowDelegate = delegate // Store strong reference
    }
}

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
                    
                    // Message content
                    MarkdownRenderer(content: message.content, textColor: .white)
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
                    MarkdownRenderer(content: questionPart, textColor: .white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(red: 0.0, green: 0.48, blue: 0.4))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .frame(maxWidth: 280, alignment: .trailing)
            } else {
                // Fallback to regular display
                VStack(alignment: .trailing) {
                    MarkdownRenderer(content: message.content, textColor: .white)
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
                MarkdownRenderer(content: message.content, textColor: .white)
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
    @StateObject private var providerManager = AIProviderManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProvider: AIProvider?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Select AI Model")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Refresh") {
                    Task {
                        await providerManager.refreshAllModels()
                    }
                }
                .font(.caption)
            }
            
            // Provider selector
            if providerManager.availableProviders.count > 1 {
                HStack {
                    Text("Provider:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("Provider", selection: Binding(
                        get: { selectedProvider ?? providerManager.selectedProvider },
                        set: { newProvider in
                            selectedProvider = newProvider
                            providerManager.setSelectedProvider(newProvider)
                        }
                    )) {
                        ForEach(providerManager.availableProviders) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(.caption)
                }
            }
            
            if providerManager.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading models...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 20)
            } else if providerManager.currentProviderModels.isEmpty {
                VStack(spacing: 8) {
                    Text("No models found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if providerManager.selectedProvider == .ollama {
                        Text("Make sure Ollama is running and has models installed")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("Check your API key and try refreshing")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.vertical, 20)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(providerManager.currentProviderModels) { model in
                            AIModelRow(
                                model: model,
                                isSelected: model.name == providerManager.selectedModel
                            ) {
                                providerManager.setSelectedModel(model.name)
                                dismiss()
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
            
            if let error = providerManager.error {
                Text("Error: \(error)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 8)
            }
        }
        .padding(16)
        .frame(minWidth: 320)
        .onAppear {
            selectedProvider = providerManager.selectedProvider
            if providerManager.availableModels.isEmpty {
                Task {
                    await providerManager.refreshAllModels()
                }
            }
        }
    }
}

struct AIModelRow: View {
    let model: AIModel
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
                        Text(model.provider.displayName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        if !model.isEnabled {
                            Text("Disabled")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
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
            .opacity(model.isEnabled ? 1.0 : 0.6)
        }
        .buttonStyle(.plain)
        .disabled(!model.isEnabled)
    }
}

// Floating window delegate to handle window events
class FloatingWindowDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void
    
    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        super.init()
    }
    
    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}

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

#Preview {
    AIChatSidebar(isVisible: .constant(true))
        .frame(width: 300, height: 500)
} 