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
              (session.title == "New Chat" || session.title == "Untitled") else { 
            print("Title generation guard failed: session not found or conditions not met")
            return 
        }
        
        print("Starting title generation for session: \(session.id), title: \(session.title)")
        
        await MainActor.run {
            isGeneratingTitle = true
        }
        
        do {
            let title = try await generateTitleFromMessages(session.messages)
            print("Generated title: '\(title)' for session: \(session.id)")
            
            await MainActor.run {
                updateCurrentSession { session in
                    session.updateTitle(title)
                }
                print("Updated session title to: '\(title)'")
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
        - just return the title, no other text
        - title case, no punctuation
        
        Title:
        """
        
        let ollamaMessage = OllamaChatMessage(role: "user", content: prompt)
        print("Sending title generation request to Ollama with prompt: \(prompt)")
        
        let stream = try await ollamaManager.sendChatMessage(messages: [ollamaMessage])
        
        var title = ""
        for try await chunk in stream {
            title += chunk
            print("Received title chunk: '\(chunk)'")
            // Don't break at 80 chars - let it complete to get the full title
        }
        
        print("Final title before cleanup: '\(title)'")
        
        // Clean up the title
        title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove <think> blocks and everything in between if they exist
        print("Title before <think> removal: '\(title)'")
        
        if title.contains("<think>") {
            if let startRange = title.range(of: "<think>") {
                if let endRange = title.range(of: "</think>") {
                    // Remove everything from <think> to </think> inclusive
                    let beforeThink = String(title[..<startRange.lowerBound])
                    let afterThink = String(title[endRange.upperBound...])
                    title = beforeThink + afterThink
                    print("Removed <think> block: before='\(beforeThink)', after='\(afterThink)'")
                } else {
                    // No closing tag found, remove everything from <think> onwards
                    title = String(title[..<startRange.lowerBound])
                    print("No closing </think> tag found, removed from <think> onwards")
                }
            }
        }
        
        // Also remove any remaining </think> tags
        title = title.replacingOccurrences(of: "</think>", with: "")
        print("Title after <think> removal: '\(title)'")
        
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
        
        print("Adding message: isUser=\(message.isUser), messageCount=\(getCurrentSession()?.messages.count ?? 0), shouldGenerateTitle=\(shouldGenerateTitle)")
        
        updateCurrentSession { session in
            session.addMessage(message)
        }
        
        // Generate title if this was the first user message
        if shouldGenerateTitle {
            print("Triggering title generation for first user message")
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
