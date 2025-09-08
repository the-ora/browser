import Foundation
import SwiftData

// MARK: - Message Sender Types

enum MessageSender: String, Codable, CaseIterable {
    case user
    case ai
}

// MARK: - AI Message

@Model
class AIMessage: Identifiable {
    var id: UUID
    var content: String
    var sender: MessageSender
    var timestamp: Date
    var aiModel: String? // Only populated for AI messages

    @Relationship(inverse: \AIConversation.messages) var conversation: AIConversation?

    init(
        id: UUID = UUID(),
        content: String,
        sender: MessageSender,
        timestamp: Date = Date(),
        aiModel: String? = nil
    ) {
        self.id = id
        self.content = content
        self.sender = sender
        self.timestamp = timestamp
        self.aiModel = aiModel
    }

    // Convenience initializers
    static func userMessage(content: String) -> AIMessage {
        AIMessage(content: content, sender: .user)
    }

    static func aiMessage(content: String, model: String? = nil) -> AIMessage {
        AIMessage(content: content, sender: .ai, aiModel: model)
    }
}

// MARK: - AI Conversation

@Model
class AIConversation: Identifiable {
    var id: UUID
    var name: String
    var createdAt: Date
    var lastAccessedAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade) var messages: [AIMessage] = []

    init(
        id: UUID = UUID(),
        name: String = "New Conversation"
    ) {
        let now = Date()
        self.id = id
        self.name = name
        self.createdAt = now
        self.lastAccessedAt = now
        self.updatedAt = now
    }

    func addMessage(_ message: AIMessage) {
        messages.append(message)
        updatedAt = Date()

        // Auto-generate conversation name from first user message
        if name == "New Conversation", let firstUserMessage = messages.first(where: { $0.sender == .user }) {
            name = String(firstUserMessage.content.prefix(50))
            if firstUserMessage.content.count > 50 {
                name += "..."
            }
        }
    }

    func touch() {
        lastAccessedAt = Date()
    }
}
