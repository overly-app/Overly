//
//  MessageBubbleView.swift
//  Overly
//
//  Created by AI Assistant on 1/27/25.
//

import SwiftUI
import AppKit

struct MessageBubbleView: View {
    let message: ChatMessage
    @State private var isHovered = false
    @State private var showingCopyConfirmation = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .user {
                Spacer(minLength: 60)
                messageContent
                    .contextMenu {
                        contextMenuItems
                    }
                userAvatar
            } else {
                assistantAvatar
                messageContent
                    .contextMenu {
                        contextMenuItems
                    }
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 4)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
    
    // MARK: - Message Content
    
    private var messageContent: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
            // Message bubble
            messageBubble
            
            // Timestamp and status
            messageMetadata
        }
    }
    
    private var messageBubble: some View {
        VStack(alignment: .leading, spacing: 0) {
            if message.isStreaming {
                // Streaming content with typing indicator
                HStack(alignment: .bottom, spacing: 8) {
                    MarkdownText(content: message.content)
                        .textSelection(.enabled)
                    
                    if message.content.isEmpty {
                        typingIndicator
                    } else {
                        streamingIndicator
                    }
                }
            } else {
                // Static content
                MarkdownText(content: message.content)
                    .textSelection(.enabled)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(bubbleBackground)
        .overlay(bubbleOverlay)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
    }
    
    private var bubbleBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(message.role == .user ? AnyShapeStyle(userBubbleGradient) : AnyShapeStyle(assistantBubbleBackground))
    }
    
    private var bubbleOverlay: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(bubbleStrokeColor, lineWidth: 1)
            .opacity(0.3)
    }
    
    private var userBubbleGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.accentColor,
                Color.accentColor.opacity(0.8)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var assistantBubbleBackground: Color {
        Color(NSColor.controlBackgroundColor).opacity(0.8)
    }
    
    private var bubbleStrokeColor: Color {
        message.role == .user ? Color.white.opacity(0.3) : Color.primary.opacity(0.1)
    }
    
    // MARK: - Avatars
    
    private var userAvatar: some View {
        Circle()
            .fill(LinearGradient(
                colors: [Color.blue, Color.purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .frame(width: 32, height: 32)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            )
    }
    
    private var assistantAvatar: some View {
        Circle()
            .fill(Color(NSColor.controlBackgroundColor))
            .frame(width: 32, height: 32)
            .overlay(
                Circle()
                    .stroke(Color.primary.opacity(0.2), lineWidth: 1)
            )
            .overlay(
                providerIcon
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
            )
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
    
    // MARK: - Metadata
    
    private var messageMetadata: some View {
        HStack(spacing: 4) {
            if message.role == .user {
                Spacer()
            }
            
            Text(timeString)
                .font(.caption2)
                .foregroundColor(.secondary)
                .opacity(isHovered ? 1.0 : 0.6)
            
            if message.role == .assistant && message.isStreaming {
                Image(systemName: "ellipsis")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .symbolEffect(.pulse, options: .repeating)
            }
            
            if message.role == .user {
                // Delivery status could go here
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
    
    // MARK: - Streaming Indicators
    
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
            // Trigger animation
        }
    }
    
    private var streamingIndicator: some View {
        Rectangle()
            .fill(Color.accentColor)
            .frame(width: 2, height: 16)
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
        // This would be animated in a real implementation
        return 1.0
    }
    
    // MARK: - Context Menu
    
    private var contextMenuItems: some View {
        Group {
            Button("Copy Message") {
                copyToClipboard()
            }
            
            if message.role == .assistant {
                Button("Regenerate") {
                    // TODO: Implement regeneration
                }
            }
            
            Divider()
            
            Button("Copy as Markdown") {
                copyAsMarkdown()
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: message.timestamp)
    }
    
    // MARK: - Actions
    
    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(message.content, forType: .string)
        
        showingCopyConfirmation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showingCopyConfirmation = false
        }
    }
    
    private func copyAsMarkdown() {
        let role = message.role == .user ? "**You**" : "**Assistant**"
        let markdown = "\(role): \(message.content)"
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(markdown, forType: .string)
    }
}

// MARK: - Markdown Text View

struct MarkdownText: View {
    let content: String
    
    var body: some View {
        // For now, we'll use a simple Text view
        // In a production app, you'd want to use a proper markdown renderer
        Text(content)
            .font(.system(size: 14, design: .default))
            .foregroundColor(textColor)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }
    
    private var textColor: Color {
        // Determine text color based on content or context
        Color.primary
    }
}

#Preview {
    VStack(spacing: 16) {
        MessageBubbleView(
            message: ChatMessage(
                content: "Hello! How can I help you today?",
                role: .assistant,
                provider: "OpenAI"
            )
        )
        
        MessageBubbleView(
            message: ChatMessage(
                content: "I need help with SwiftUI animations. Can you show me how to create smooth transitions?",
                role: .user,
                provider: "OpenAI"
            )
        )
        
        MessageBubbleView(
            message: ChatMessage(
                content: "I'd be happy to help you with SwiftUI animations! Here are some key concepts...",
                role: .assistant,
                provider: "OpenAI",
                isStreaming: true
            )
        )
    }
    .padding()
    .frame(width: 400)
} 