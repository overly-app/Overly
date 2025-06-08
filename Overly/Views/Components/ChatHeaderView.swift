import SwiftUI

struct ChatHeaderView: View {
    @ObservedObject var chatManager: ChatManager
    @Binding var showingSidebar: Bool
    @Binding var showingProviderSettings: Bool
    
    var body: some View {
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
                        ChatProviderIconView(provider: session.provider)
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
            } else {
                // Debug: Show if models are loading
                Text("Loading models...")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
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
                Button(action: {
                    if let session = chatManager.currentSession {
                        session.model = model
                        print("✅ Model changed to: \(model)")
                    }
                }) {
                    HStack {
                        Text(model)
                        Spacer()
                        if chatManager.currentSession?.model == model {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(chatManager.currentSession?.model ?? chatManager.selectedProvider.defaultModel)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                    )
            )
        }
        .menuStyle(.borderlessButton)
        .help("Select Model")
    }
} 