import SwiftUI

struct ChatSidebarView: View {
    @ObservedObject var chatManager: ChatManager
    @Binding var showingProviderSettings: Bool
    @Binding var showingSidebar: Bool
    
    var body: some View {
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
                ChatProviderIconView(provider: session.provider)
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
                ChatProviderIconView(provider: chatManager.selectedProvider)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
} 