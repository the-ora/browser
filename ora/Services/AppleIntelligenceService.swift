import Foundation
import FoundationModels
import SwiftUI

/// Service for integrating with Apple's on-device Foundation Models
/// Only available on macOS 26 and later
@available(macOS 26.0, *)
@MainActor
class AppleIntelligenceService: ObservableObject {
    @Published var isGenerating: Bool = false
    @Published var lastError: String?

    private var model = SystemLanguageModel.default
    private var session: LanguageModelSession?
    private var streamingTask: Task<Void, Never>?

    var isAvailable: Bool {
        model.isAvailable
    }

    init() {
        // Session created when first needed
    }

    /// Get availability description for debugging
    var availabilityDescription: String {
        switch model.availability {
        case .available:
            return "Available"
        case let .unavailable(reason):
            switch reason {
            case .deviceNotEligible:
                return "Device not eligible for Apple Intelligence"
            case .appleIntelligenceNotEnabled:
                return "Apple Intelligence not enabled in Settings"
            case .modelNotReady:
                return "Apple Intelligence model is downloading or not ready"
            @unknown default:
                return "Apple Intelligence unavailable for unknown reason"
            }
        @unknown default:
            return "Unknown availability status"
        }
    }

    /// Create or get existing session
    private func getSession() -> LanguageModelSession {
        if let session {
            return session
        }

        let instructions = """
        You are Apple Intelligence, a helpful AI assistant running locally on the user's Mac.
        You should be helpful, harmless, and honest. Keep responses concise but informative.
        Respond with "I can't help with that" if asked to do something dangerous or inappropriate.
        """
        let newSession = LanguageModelSession(instructions: instructions)
        session = newSession
        return newSession
    }

    /// Start a new conversation by creating a fresh session
    func startNewConversation() {
        stopGeneration()
        session = nil
    }

    /// Stop any ongoing generation
    func stopGeneration() {
        streamingTask?.cancel()
        streamingTask = nil
        isGenerating = false
    }

    /// Generate response with streaming support - directly updates the conversation manager
    func generateResponse(
        to prompt: String,
        conversationManager: AIConversationManager,
        conversationId: UUID,
        useStreaming: Bool = true,
        temperature: Double = 1.0
    ) {
        guard isAvailable else {
            let errorMessage = AIMessage(
                content: "Apple Intelligence is not available: \(availabilityDescription)",
                isFromUser: false
            )
            conversationManager.updateLastMessage(in: conversationId, with: errorMessage)
            return
        }

        isGenerating = true
        lastError = nil

        streamingTask = Task {
            do {
                let currentSession = getSession()
                let options = GenerationOptions(temperature: temperature)

                if useStreaming {
                    let stream = currentSession.streamResponse(to: prompt, options: options)

                    for try await partialResponse in stream {
                        await MainActor.run {
                            let message = AIMessage(content: partialResponse.content, isFromUser: false)
                            conversationManager.updateLastMessage(in: conversationId, with: message)
                        }
                    }
                } else {
                    let response = try await currentSession.respond(to: prompt, options: options)
                    await MainActor.run {
                        let message = AIMessage(content: response.content, isFromUser: false)
                        conversationManager.updateLastMessage(in: conversationId, with: message)
                    }
                }
            } catch is CancellationError {
                // User cancelled generation - don't show error
            } catch {
                await MainActor.run {
                    self.lastError = error.localizedDescription
                    let errorMessage = AIMessage(
                        content: "Sorry, I encountered an error: \(error.localizedDescription)",
                        isFromUser: false
                    )
                    conversationManager.updateLastMessage(in: conversationId, with: errorMessage)
                }
            }

            await MainActor.run {
                self.isGenerating = false
                self.streamingTask = nil
            }
        }
    }
}

// MARK: - Error Types

enum AIError: LocalizedError {
    case unavailable(String)
    case modelNotInitialized
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case let .unavailable(reason):
            return "Apple Intelligence is not available: \(reason)"
        case .modelNotInitialized:
            return "Language model is not initialized"
        case let .generationFailed(message):
            return "Generation failed: \(message)"
        }
    }
}

// MARK: - Message Types

struct AIMessage: Codable, Identifiable {
    let id = UUID()
    let content: String
    let isFromUser: Bool
    let timestamp = Date()

    init(content: String, isFromUser: Bool) {
        self.content = content
        self.isFromUser = isFromUser
    }
}

// MARK: - Conversation Types

struct AIConversation: Codable, Identifiable {
    let id = UUID()
    var messages: [AIMessage] = []
    let createdAt = Date()
    var updatedAt = Date()

    mutating func addMessage(_ message: AIMessage) {
        messages.append(message)
        updatedAt = Date()
    }
}

// MARK: - Conversation Manager

@MainActor
class AIConversationManager: ObservableObject {
    @Published var conversations: [AIConversation] = []
    @Published var activeConversation: AIConversation?

    private let userDefaults = UserDefaults.standard
    private let conversationsKey = "ai_conversations"

    init() {
        loadConversations()
    }

    func createNewConversation() -> AIConversation {
        let conversation = AIConversation()
        conversations.insert(conversation, at: 0)
        activeConversation = conversation
        saveConversations()
        return conversation
    }

    func addMessage(to conversationId: UUID, message: AIMessage) {
        if let index = conversations.firstIndex(where: { $0.id == conversationId }) {
            conversations[index].addMessage(message)
            if activeConversation?.id == conversationId {
                activeConversation = conversations[index]
            }
            saveConversations()
        }
    }

    /// Update the last message in a conversation (for streaming updates)
    func updateLastMessage(in conversationId: UUID, with message: AIMessage) {
        if let index = conversations.firstIndex(where: { $0.id == conversationId }) {
            let messageIndex = conversations[index].messages.count - 1
            if messageIndex >= 0 {
                conversations[index].messages[messageIndex] = message
                if activeConversation?.id == conversationId {
                    activeConversation = conversations[index]
                }
                // Don't save on every streaming update - save at completion
            }
        }
    }

    /// Save conversations to disk
    func saveConversations() {
        guard let data = try? JSONEncoder().encode(conversations) else { return }
        userDefaults.set(data, forKey: conversationsKey)
    }

    func deleteConversation(_ conversationId: UUID) {
        conversations.removeAll { $0.id == conversationId }
        if activeConversation?.id == conversationId {
            activeConversation = conversations.first
        }
        saveConversations()
    }

    private func loadConversations() {
        guard let data = userDefaults.data(forKey: conversationsKey),
              let conversations = try? JSONDecoder().decode([AIConversation].self, from: data)
        else {
            return
        }
        self.conversations = conversations
        self.activeConversation = conversations.first
    }
}
