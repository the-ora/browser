import SwiftData
import SwiftUI

@available(macOS 26.0, *)
struct AIChatView: View {
    @State private var conversationManager = AIConversationManager()
    @State private var inputText = ""
    @State private var aiService: AppleIntelligenceService?
    @State private var showConversationHistory = false

    private let conversationId: UUID?
    private let initialQuery: String?

    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext

    init(conversationId: UUID? = nil, initialQuery: String? = nil) {
        self.conversationId = conversationId
        self.initialQuery = initialQuery
    }

    var body: some View {
        HStack(spacing: 0) {
            // Conversation History Sidebar
            if showConversationHistory {
                conversationHistoryView
                    .frame(width: 280)
                    .transition(.move(edge: .leading))
            }

            // Main Chat Content
            VStack(spacing: 0) {
                if let aiService, aiService.isAvailable {
                    chatContent(aiService: aiService)
                } else {
                    unavailableView
                }
            }
            .background(theme.background)
        }
        .onAppear {
            conversationManager.setModelContext(modelContext)
            initializeAIService()
            setupConversation()
            handleInitialQuery()
        }
        .animation(.easeInOut(duration: 0.3), value: showConversationHistory)
    }

    private func initializeAIService() {
        if #available(macOS 26.0, *) {
            aiService = AppleIntelligenceService()
        }
    }

    private func chatContent(aiService: AppleIntelligenceService) -> some View {
        VStack(spacing: 0) {
            // Header
            chatHeader

            Divider()

            // Messages
            messagesView

            // Input
            AIInputField(
                text: $inputText,
                onSend: sendMessage,
                isGenerating: aiService.isGenerating
            )
        }
    }

    private var chatHeader: some View {
        HStack {
            Button(action: {
                showConversationHistory.toggle()
            }) {
                Image(systemName: "sidebar.left")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Image(systemName: "apple.intelligence")
                .font(.title2)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text("Apple Intelligence")
                    .font(.headline)
                    .foregroundStyle(theme.foreground)

                Text("On-device AI • Private & Secure")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("New Chat") {
                startNewConversation()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var messagesView: some View {
        ScrollViewReader { _ in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if let conversation = conversationManager.activeConversation {
                        ForEach(conversation.messages.sorted(by: { $0.timestamp < $1.timestamp })) { message in
                            AIMessageBubble(message: message)
                                .id(message.id)
                        }
                    } else {
                        emptyStateView
                    }
                }
                .padding(.top, 16)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "apple.intelligence")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            VStack(spacing: 8) {
                Text("Welcome to Apple Intelligence")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Ask me anything. I'm running locally on your Mac with complete privacy.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(alignment: .leading, spacing: 8) {
                examplePrompt("Help me write an email")
                examplePrompt("Explain quantum computing")
                examplePrompt("Generate creative ideas")
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func examplePrompt(_ text: String) -> some View {
        Button(text) {
            inputText = text
            sendMessage(text)
        }
        .buttonStyle(.bordered)
        .foregroundStyle(theme.foreground)
    }

    private var unavailableView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            VStack(spacing: 8) {
                Text("Apple Intelligence Not Available")
                    .font(.title2)
                    .fontWeight(.semibold)

                if #available(macOS 26.0, *), let aiService {
                    Text(aiService.availabilityDescription)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                } else {
                    Text("Apple Intelligence requires macOS 26 or later with compatible hardware.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }

            Button("Retry") {
                initializeAIService()
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func setupConversation() {
        if let conversationId {
            // Load existing conversation
            if let existingConversation = conversationManager.conversations.first(where: { $0.id == conversationId }) {
                conversationManager.activeConversation = existingConversation
                existingConversation.touch()
            } else {
                // Conversation ID provided but not found - create new one with that ID
                let conversation = AIConversation(id: conversationId)
                conversationManager.conversations.insert(conversation, at: 0)
                conversationManager.activeConversation = conversation

                modelContext.insert(conversation)
                try? modelContext.save()
            }
        } else {
            // No conversation ID - create new conversation
            if conversationManager.activeConversation == nil {
                conversationManager.createNewConversation()
            }
        }
    }

    private func handleInitialQuery() {
        if let query = initialQuery, !query.isEmpty {
            inputText = query
            // Automatically send the initial query after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                sendMessage(query)
                inputText = ""
            }
        }
    }

    private func startNewConversation() {
        let newConversation = conversationManager.createNewConversation()
        if #available(macOS 26.0, *), let aiService {
            aiService.startNewConversation()
        }

        // TODO: Navigate to new conversation URL: ora://apple-intelligence/\(newConversation.id)
        // This would require access to the tab manager or navigation system
    }

    private func sendMessage(_ text: String) {
        guard let conversationId = conversationManager.activeConversation?.id else { return }

        // Add user message
        let userMessage = AIMessage.userMessage(content: text)
        conversationManager.addMessage(to: conversationId, message: userMessage)

        // Add empty assistant message for streaming
        let assistantMessage = AIMessage.aiMessage(content: "")
        conversationManager.addMessage(to: conversationId, message: assistantMessage)

        // Generate AI response with streaming - much simpler!
        if #available(macOS 26.0, *), let aiService {
            aiService.generateResponse(
                to: text,
                conversationManager: conversationManager,
                conversationId: conversationId,
                useStreaming: true
            )
        }
    }

    private var conversationHistoryView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // History Header
            HStack {
                Text("Conversations")
                    .font(.headline)
                    .foregroundStyle(theme.foreground)

                Spacer()

                Button("New") {
                    startNewConversation()
                    showConversationHistory = false
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(theme.background.opacity(0.5))

            Divider()

            // Conversation List
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(conversationManager.conversations) { conversation in
                        ConversationHistoryRow(
                            conversation: conversation,
                            isActive: conversationManager.activeConversation?.id == conversation.id,
                            onSelect: {
                                selectConversation(conversation)
                            },
                            onDelete: {
                                deleteConversation(conversation)
                            }
                        )
                    }
                }
                .padding(.top, 8)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background.opacity(0.95))
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(Color(.separatorColor)),
            alignment: .trailing
        )
    }

    private func selectConversation(_ conversation: AIConversation) {
        conversationManager.activeConversation = conversation
        conversation.touch()
        showConversationHistory = false

        // Save the touch update
        if let context = conversationManager.modelContext {
            try? context.save()
        }
    }

    private func deleteConversation(_ conversation: AIConversation) {
        conversationManager.deleteConversation(conversation.id)

        // If we deleted the active conversation, select the first available
        if conversationManager.activeConversation?.id == conversation.id {
            conversationManager.activeConversation = conversationManager.conversations.first
        }
    }
}

#Preview {
    if #available(macOS 26.0, *) {
        AIChatView()
    } else {
        Text("")
    }
}
