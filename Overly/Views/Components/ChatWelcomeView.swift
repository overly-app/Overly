import SwiftUI

struct ChatWelcomeView: View {
    @ObservedObject var chatManager: ChatManager
    @Binding var messageText: String
    let onExampleTap: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                ChatProviderIconView(provider: chatManager.selectedProvider)
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
        .padding(.top, 60)
    }
    
    private func examplePrompt(_ text: String, _ icon: String) -> some View {
        Button(action: {
            messageText = text
            onExampleTap()
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
} 