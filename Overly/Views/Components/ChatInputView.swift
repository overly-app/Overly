import SwiftUI

struct ChatInputView: View {
    @ObservedObject var chatManager: ChatManager
    @Binding var messageText: String
    @FocusState var isInputFocused: Bool
    
    var body: some View {
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
    
    private var canSendMessage: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !chatManager.isLoading
    }
    
    private func sendMessage() {
        let message = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        
        messageText = ""
        chatManager.sendMessage(message)
    }
} 