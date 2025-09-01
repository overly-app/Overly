import SwiftUI

struct ChatSidebarView: View {
    @ObservedObject var chatSessionManager = ChatSessionManager.shared
    @State private var isCollapsed: Bool = false
    @State private var showDeleteAlert: Bool = false
    @State private var sessionToDelete: UUID?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with collapse button
            sidebarHeader
            
            if !isCollapsed {
                // Chat sessions list
                chatSessionsList
                
                // New chat button
                newChatButton
            }
        }
        .frame(width: isCollapsed ? 50 : 280)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(Color(NSColor.separatorColor)),
            alignment: .trailing
        )
        .alert("Delete Chat", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let sessionId = sessionToDelete {
                    chatSessionManager.deleteChat(sessionId)
                }
            }
        } message: {
            Text("Are you sure you want to delete this chat? This action cannot be undone.")
        }
    }
    
    private var sidebarHeader: some View {
        HStack {
            if !isCollapsed {
                Text("Chats")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCollapsed.toggle()
                }
            }) {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.left")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, isCollapsed ? 15 : 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var chatSessionsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(chatSessionManager.chatSessions) { session in
                    ChatSessionRow(
                        session: session,
                        isSelected: chatSessionManager.currentSessionId == session.id,
                        isGeneratingTitle: chatSessionManager.isGeneratingTitle && chatSessionManager.currentSessionId == session.id,
                        onSelect: {
                            AIChatMessageManager.shared.switchToSession(session.id)
                        },
                        onDelete: {
                            sessionToDelete = session.id
                            showDeleteAlert = true
                        }
                    )
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
    
    private var newChatButton: some View {
        Button(action: {
            AIChatMessageManager.shared.startNewChat()
        }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
                
                Text("New Chat")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}

struct ChatSessionRow: View {
    let session: ChatSession
    let isSelected: Bool
    let isGeneratingTitle: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Chat icon
            Image(systemName: "message.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(isSelected ? .accentColor : .secondary)
            
            // Title and metadata
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(session.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isSelected ? .primary : .primary)
                        .lineLimit(1)
                    
                    if isGeneratingTitle {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 12, height: 12)
                    }
                    
                    Spacer()
                }
                
                HStack {
                    Text("\(session.messageCount) messages")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    if !session.model.isEmpty {
                        Text("•")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Text(session.model.replacingOccurrences(of: ":latest", with: ""))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                }
            }
            
            Spacer()
            
            // Delete button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(PlainButtonStyle())
            .opacity(isSelected ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
        )
        .onTapGesture {
            onSelect()
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

#Preview {
    ChatSidebarView()
        .frame(height: 600)
}
