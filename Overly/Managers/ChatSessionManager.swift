import Foundation
import SwiftUI

@MainActor
class ChatSessionManager: ObservableObject {
    static let shared = ChatSessionManager()
    
    @Published var chatSessions: [ChatSession] = []
    @Published var currentSessionId: UUID?
    @Published var isGeneratingTitle: Bool = false
    
    private let ollamaManager = OllamaManager.shared
    private let userDefaults = UserDefaults.standard
    private let chatSessionsKey = "ChatSessions"
    
    private init() {
        loadChatSessions()
        if chatSessions.isEmpty {
            createNewChat()
        }
    }
    
    // MARK: - Session Management
    
    func createNewChat() {
        // Don't create a session yet - just set up for the next message
        // The session will be created when the first message is sent
        currentSessionId = nil
    }
    
    func deleteChat(_ sessionId: UUID) {
        chatSessions.removeAll { $0.id == sessionId }
        
        // If we deleted the current session, switch to another one
        if currentSessionId == sessionId {
            currentSessionId = chatSessions.first?.id
        }
        
        saveChatSessions()
    }
    
    func switchToChat(_ sessionId: UUID) {
        currentSessionId = sessionId
    }
    
    func getCurrentSession() -> ChatSession? {
        guard let currentId = currentSessionId else { return nil }
        return chatSessions.first { $0.id == currentId }
    }
    
    func updateCurrentSession(_ update: (inout ChatSession) -> Void) {
        guard let index = chatSessions.firstIndex(where: { $0.id == currentSessionId }) else { return }
        update(&chatSessions[index])
        saveChatSessions()
    }
    
    // MARK: - Title Generation
    
    func generateTitleForCurrentSession() async {
        guard let session = getCurrentSession(),
              !session.messages.isEmpty,
              (session.title == "New Chat" || session.title == "Untitled") else { return }
        
        await MainActor.run {
            isGeneratingTitle = true
        }
        
        do {
            let title = try await generateTitleFromMessages(session.messages)
            
            await MainActor.run {
                updateCurrentSession { session in
                    session.updateTitle(title)
                }
                isGeneratingTitle = false
            }
        } catch {
            await MainActor.run {
                isGeneratingTitle = false
                print("Failed to generate title: \(error)")
            }
        }
    }
    
    private func generateTitleFromMessages(_ messages: [AIChatMessage]) async throws -> String {
        // Get the first user message to generate a title from
        guard let firstUserMessage = messages.first(where: { $0.isUser }) else {
            return "New Chat"
        }
        
        let prompt = """
        Generate a concise, descriptive title (maximum 80 characters) for a chat conversation based on this first message:
        
        "\(firstUserMessage.content)"
        
        The title should be:
        - Descriptive and relevant to the conversation topic
        - Maximum 80 characters
        - Professional and clear
        - No quotes or special formatting
        
        Title:
        """
        
        let ollamaMessage = OllamaChatMessage(role: "user", content: prompt)
        let stream = try await ollamaManager.sendChatMessage(messages: [ollamaMessage])
        
        var title = ""
        for try await chunk in stream {
            title += chunk
            if title.count >= 80 {
                break
            }
        }
        
        // Clean up the title
        title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove <think> blocks and everything in between if they exist
        if title.contains("<think>") {
            let components = title.components(separatedBy: "<think>")
            if components.count > 1 {
                // Take only the part before the first <think> tag
                title = components[0]
            }
        }
        
        // Also remove any remaining </think> tags
        title = title.replacingOccurrences(of: "</think>", with: "")
        
        title = title.replacingOccurrences(of: "\n", with: " ")
        title = title.replacingOccurrences(of: "\"", with: "")
        title = title.replacingOccurrences(of: "'", with: "")
        
        // Ensure it's within 80 characters
        if title.count > 80 {
            title = String(title.prefix(77)) + "..."
        }
        
        return title.isEmpty ? "New Chat" : title
    }
    
    // MARK: - Message Management
    
    func addMessageToCurrentSession(_ message: AIChatMessage) {
        // If no current session exists, create one
        if currentSessionId == nil {
            let newSession = ChatSession(title: "Untitled", model: "")
            chatSessions.insert(newSession, at: 0)
            currentSessionId = newSession.id
            saveChatSessions()
        }
        
        // Check if this will be the first user message before adding it
        let shouldGenerateTitle = message.isUser && getCurrentSession()?.messages.count == 0
        
        updateCurrentSession { session in
            session.addMessage(message)
        }
        
        // Generate title if this was the first user message
        if shouldGenerateTitle {
            Task {
                await generateTitleForCurrentSession()
            }
        }
    }
    
    func updateCurrentSessionModel(_ model: String) {
        updateCurrentSession { session in
            session.setModel(model)
        }
    }
    
    // MARK: - Persistence
    
    private func saveChatSessions() {
        let codableSessions = chatSessions.map { session in
            CodableChatSession(
                id: session.id,
                title: session.title,
                messages: session.messages.map { CodableChatMessage(from: $0) },
                createdAt: session.createdAt,
                lastModified: session.lastModified,
                model: session.model
            )
        }
        
        if let data = try? JSONEncoder().encode(codableSessions) {
            userDefaults.set(data, forKey: chatSessionsKey)
        }
    }
    
    private func loadChatSessions() {
        guard let data = userDefaults.data(forKey: chatSessionsKey),
              let codableSessions = try? JSONDecoder().decode([CodableChatSession].self, from: data) else {
            return
        }
        
        chatSessions = codableSessions.map { codableSession in
            ChatSession(
                id: codableSession.id,
                title: codableSession.title,
                messages: codableSession.messages.map { $0.toAIChatMessage() },
                createdAt: codableSession.createdAt,
                lastModified: codableSession.lastModified,
                model: codableSession.model
            )
        }
        
        // Set current session to the most recent one
        if let mostRecent = chatSessions.max(by: { $0.lastModified < $1.lastModified }) {
            currentSessionId = mostRecent.id
        }
    }
}

// Codable wrapper for ChatSession since AIChatMessage is a class
struct CodableChatSession: Codable {
    let id: UUID
    let title: String
    let messages: [CodableChatMessage]
    let createdAt: Date
    let lastModified: Date
    let model: String
}
