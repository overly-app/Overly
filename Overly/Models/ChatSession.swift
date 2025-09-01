import Foundation

struct ChatSession: Identifiable {
    let id: UUID
    var title: String
    var messages: [AIChatMessage]
    let createdAt: Date
    var lastModified: Date
    var model: String
    
    init(title: String = "New Chat", model: String = "") {
        self.id = UUID()
        self.title = title
        self.messages = []
        self.createdAt = Date()
        self.lastModified = Date()
        self.model = model
    }
    
    init(id: UUID, title: String, messages: [AIChatMessage], createdAt: Date, lastModified: Date, model: String) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.lastModified = lastModified
        self.model = model
    }
    
    mutating func addMessage(_ message: AIChatMessage) {
        messages.append(message)
        lastModified = Date()
    }
    
    mutating func updateTitle(_ newTitle: String) {
        title = newTitle
        lastModified = Date()
    }
    
    mutating func setModel(_ model: String) {
        self.model = model
        lastModified = Date()
    }
    
    var messageCount: Int {
        messages.count
    }
    
    var hasUserMessages: Bool {
        messages.contains { $0.isUser }
    }
    
    var lastUserMessage: String? {
        messages.last { $0.isUser }?.content
    }
}

// Codable wrapper for AIChatMessage since it's a class
struct CodableChatMessage: Codable {
    let id: UUID
    let content: String
    let isUser: Bool
    let timestamp: Date
    let responses: [String]
    let currentResponseIndex: Int
    let isGenerating: Bool
    
    init(from message: AIChatMessage) {
        self.id = message.id
        self.content = message.content
        self.isUser = message.isUser
        self.timestamp = message.timestamp
        self.responses = message.responses
        self.currentResponseIndex = message.currentResponseIndex
        self.isGenerating = message.isGenerating
    }
    
    func toAIChatMessage() -> AIChatMessage {
        let message = AIChatMessage(content: content, isUser: isUser)
        message.responses = responses
        message.currentResponseIndex = currentResponseIndex
        if isGenerating {
            message.startGenerating()
        } else {
            message.markGenerationComplete()
        }
        return message
    }
}
