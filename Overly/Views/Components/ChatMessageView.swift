import SwiftUI

struct ChatMessageView: View {
    let message: ChatMessage
    @State private var isHovered = false
    @State private var streamingOpacity: Double = 1.0
    
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