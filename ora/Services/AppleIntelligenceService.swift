import Foundation
import FoundationModels
import SwiftData
import SwiftUI

/// Service for integrating with Apple's on-device Foundation Models
/// Only available on macOS 26 and later
@available(macOS 26.0, *)
@MainActor
@Observable
class AppleIntelligenceService {
    var isGenerating: Bool = false
    var lastError: String?

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

        let instructions = ""
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
            let errorMessage = AIMessage.aiMessage(
                content: "Apple Intelligence is not available: \(availabilityDescription)"
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
                            let message = AIMessage.aiMessage(content: partialResponse.content)
                            conversationManager.updateLastMessage(in: conversationId, with: message)
                        }
                    }
                } else {
                    let response = try await currentSession.respond(to: prompt, options: options)
                    await MainActor.run {
                        let message = AIMessage.aiMessage(content: response.content)
                        conversationManager.updateLastMessage(in: conversationId, with: message)
                    }
                }
            } catch is CancellationError {
                // User cancelled generation - don't show error
            } catch {
                await MainActor.run {
                    self.lastError = error.localizedDescription
                    let errorMessage = AIMessage.aiMessage(
                        content: "Sorry, I encountered an error: \(error.localizedDescription)"
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

// MARK: - Legacy types removed - now using SwiftData models from AIConversation.swift

// MARK: - Conversation Manager

@MainActor
@Observable
class AIConversationManager {
    var conversations: [AIConversation] = []
    var activeConversation: AIConversation?

    var modelContext: ModelContext?

    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
        loadConversations()
    }

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        loadConversations()
    }

    func createNewConversation() -> AIConversation {
        let conversation = AIConversation()
        conversations.insert(conversation, at: 0)
        activeConversation = conversation

        if let context = modelContext {
            context.insert(conversation)
            saveContext()
        }

        return conversation
    }

    func addMessage(to conversationId: UUID, message: AIMessage) {
        if let conversation = findConversation(id: conversationId) {
            conversation.addMessage(message)

            if let context = modelContext {
                context.insert(message)
                saveContext()
            }

            // Update in-memory array
            if let index = conversations.firstIndex(where: { $0.id == conversationId }) {
                if activeConversation?.id == conversationId {
                    activeConversation = conversations[index]
                }
            }
        }
    }

    /// Update the last message in a conversation (for streaming updates)
    func updateLastMessage(in conversationId: UUID, with message: AIMessage) {
        if let conversation = findConversation(id: conversationId),
           let lastMessage = conversation.messages.last,
           lastMessage.sender == .ai  // Only update AI messages
        {
            lastMessage.content = message.content
            lastMessage.aiModel = message.aiModel
            // Don't save on every streaming update for performance
        }
    }

    func deleteConversation(_ conversationId: UUID) {
        if let conversation = findConversation(id: conversationId) {
            conversations.removeAll { $0.id == conversationId }

            if activeConversation?.id == conversationId {
                activeConversation = conversations.first
            }

            if let context = modelContext {
                context.delete(conversation)
                saveContext()
            }
        }
    }

    private func findConversation(id: UUID) -> AIConversation? {
        return conversations.first(where: { $0.id == id })
    }

    private func loadConversations() {
        guard let context = modelContext else { return }

        do {
            let descriptor = FetchDescriptor<AIConversation>(
                sortBy: [SortDescriptor(\.lastAccessedAt, order: .reverse)]
            )
            conversations = try context.fetch(descriptor)
            activeConversation = conversations.first
        } catch {
            print("Failed to load AI conversations: \(error)")
        }
    }

    private func saveContext() {
        guard let context = modelContext else { return }

        do {
            try context.save()
        } catch {
            print("Failed to save AI conversations: \(error)")
        }
    }
}
