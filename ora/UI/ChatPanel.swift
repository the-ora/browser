import SwiftData
import SwiftUI

// MARK: - Chat Message Model

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let content: String
    let isUser: Bool
    let timestamp: Date

    init(content: String, isUser: Bool) {
        self.id = UUID()
        self.content = content
        self.isUser = isUser
        self.timestamp = Date()
    }

    init(id: UUID, content: String, isUser: Bool, timestamp: Date) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
    }
}

// MARK: - Available AI Models

enum AIModel: String, CaseIterable, Identifiable {
    case gpt4 = "GPT-4"
    case gpt4Turbo = "GPT-4 Turbo"
    case claude3 = "Claude 3"
    case gemini = "Gemini Pro"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gpt4: return "GPT-4"
        case .gpt4Turbo: return "GPT-4 Turbo"
        case .claude3: return "Claude 3"
        case .gemini: return "Gemini Pro"
        }
    }
}

// MARK: - Chat Panel View

struct ChatPanel: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject var tabManager: TabManager
    @StateObject private var providerManager = AIProviderManager.shared

    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var selectedModel: AIModel = .gpt4
    @State private var isLoading: Bool = false
    @State private var pageContent: String = ""
    @State private var errorMessage: String?
    @State private var hasExtractedContent: Bool = false
    @State private var streamingMessageId: UUID?
    @State private var streamingContent: String = ""

    @FocusState private var isInputFocused: Bool

    private let chatPanelCornerRadius: CGFloat = {
        if #available(macOS 26, *) {
            return 8
        } else {
            return 6
        }
    }()

    var body: some View {
        let clipShape = ConditionallyConcentricRectangle(cornerRadius: chatPanelCornerRadius)

        VStack(alignment: .leading, spacing: 0) {
            // Header with model selector and controls
            headerSection

            Divider()
                .background(theme.border.opacity(0.3))

            // Messages area
            messagesSection

            // Input section
            inputSection
        }
        .clipShape(clipShape)
        .padding(6)
        .onAppear {
            // Don't extract content on appear - wait for first message
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Chat")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.foreground)

                Spacer()

                Button(action: startNewChat) {
                    Image(systemName: "plus")
                        .foregroundColor(theme.foreground.opacity(0.6))
                        .font(.system(size: 14))
                }
                .buttonStyle(PlainButtonStyle())
                .help("Start new chat")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }

    // MARK: - Messages Section

    private var messagesSection: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if messages.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(messages) { message in
                            messageRow(message)
                                .id(message.id)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                                    removal: .opacity.combined(with: .move(edge: .top))
                                ))
                        }
                    }

                    if isLoading {
                        loadingIndicator
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    // Add some bottom padding for better scrolling
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, messages.isEmpty ? 0 : 16)
            }
            .onChange(of: messages.count) {
                if let lastMessage = messages.last {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundColor(theme.foreground.opacity(0.2))

            VStack(spacing: 8) {
                Text("Start a conversation")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.foreground.opacity(0.8))

                Text("Ask questions about this page or discuss its content with AI")
                    .font(.system(size: 14))
                    .foregroundColor(theme.foreground.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }

            // Sample prompts
            VStack(alignment: .leading, spacing: 8) {
                samplePromptButton("Summarize this page")
                samplePromptButton("Explain the key points")
                samplePromptButton("Ask a question about this content")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private func samplePromptButton(_ prompt: String) -> some View {
        Button(action: {
            inputText = prompt
            sendMessage()
        }) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundColor(theme.accent.opacity(0.7))
                Text(prompt)
                    .font(.system(size: 13))
                    .foregroundColor(theme.foreground.opacity(0.7))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(theme.mutedBackground.opacity(0.5))
                    .stroke(theme.border.opacity(0.3), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { _ in
            // Add subtle hover effect
        }
    }

    private func messageRow(_ message: ChatMessage) -> some View {
        HStack(alignment: .top, spacing: 0) {
            if message.isUser {
                Spacer(minLength: 40)
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 6) {
                HStack(spacing: 6) {
                    if !message.isUser {
                        providerLogo(for: selectedModel)
                            .frame(width: 14, height: 14)
                    }

                    Text(message.isUser ? "You" : selectedModel.displayName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.foreground.opacity(0.7))

                    if message.isUser {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(theme.accent.opacity(0.8))
                    }
                }

                Text(message.content)
                    .font(.system(size: 14))
                    .foregroundColor(theme.foreground)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(message.isUser ? theme.accent.opacity(0.08) : theme.mutedBackground)
                            .stroke(
                                message.isUser ? theme.accent.opacity(0.2) : theme.border.opacity(0.3),
                                lineWidth: 0.5
                            )
                    )
                    .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
            }

            if !message.isUser {
                Spacer(minLength: 40)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: message.id)
    }

    private var loadingIndicator: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    providerLogo(for: selectedModel)
                        .frame(width: 14, height: 14)

                    Text(selectedModel.displayName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.foreground.opacity(0.7))
                }

                HStack(spacing: 6) {
                    ForEach(0 ..< 3) { index in
                        Circle()
                            .fill(theme.accent.opacity(0.6))
                            .frame(width: 4, height: 4)
                            .scaleEffect(isLoading ? 1.2 : 0.8)
                            .animation(
                                Animation.easeInOut(duration: 0.8)
                                    .repeatForever()
                                    .delay(Double(index) * 0.2),
                                value: isLoading
                            )
                    }

                    Text("thinking...")
                        .font(.system(size: 12))
                        .foregroundColor(theme.foreground.opacity(0.5))
                        .italic()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(theme.mutedBackground)
                        .stroke(theme.border.opacity(0.3), lineWidth: 0.5)
                )
            }

            Spacer(minLength: 40)
        }
    }

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(spacing: 0) {
            Divider()
                .background(theme.border.opacity(0.3))

            // Model selector
            HStack {
                providerLogo(for: selectedModel)
                    .frame(width: 16, height: 16)

                Menu {
                    ForEach(AIModel.allCases) { model in
                        Button(action: { selectedModel = model }) {
                            HStack {
                                providerLogo(for: model)
                                    .frame(width: 14, height: 14)
                                Text(model.displayName)
                            }
                        }
                    }
                } label: {
                    Text(selectedModel.displayName)
                        .font(.system(size: 13))
                        .foregroundColor(theme.foreground)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(theme.mutedBackground.opacity(0.5))
                        )
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            HStack(alignment: .center, spacing: 10) {
                TextField("Ask about this page...", text: $inputText, axis: .vertical)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 14))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(theme.mutedBackground.opacity(0.7))
                            .stroke(
                                isInputFocused ? theme.accent.opacity(0.5) : theme.border.opacity(0.3),
                                lineWidth: isInputFocused ? 1.0 : 0.5
                            )
                    )
                    .focused($isInputFocused)
                    .onSubmit {
                        sendMessage()
                    }
                    .animation(.easeInOut(duration: 0.2), value: isInputFocused)

                Button(action: sendMessage) {
                    Image(systemName: canSendMessage ? "arrow.up.circle.fill" : "arrow.up.circle")
                        .font(.system(size: 20))
                        .foregroundColor(canSendMessage ? theme.accent : theme.foreground.opacity(0.3))
                        .animation(.easeInOut(duration: 0.2), value: canSendMessage)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!canSendMessage)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var canSendMessage: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    // MARK: - Actions

    private func sendMessage() {
        let trimmedText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty, !isLoading else { return }

        let userMessage = ChatMessage(content: trimmedText, isUser: true)

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            messages.append(userMessage)
        }

        inputText = ""

        // Keep input focused for continuous typing
        Task {
            try await Task.sleep(nanoseconds: 100_000_000) // Small delay to ensure smooth animation
            isInputFocused = true
        }

        // Extract page content only for the first message in a conversation
        let shouldIncludePageContent = messages.count == 1 && !hasExtractedContent

        if shouldIncludePageContent {
            extractPageContentAndSend(message: trimmedText)
        } else {
            // For follow-up messages, don't include page content (AI already has context)
            sendToAI(message: trimmedText, includePageContent: false)
        }
    }

    private func extractPageContentAndSend(message: String) {
        // First extract page content, then send message
        extractPageContent { success in
            Task { @MainActor in
                if success {
                    hasExtractedContent = true
                    // Debug: Print page content for first message only
                    print("🔍 DEBUG: Page content extracted for first message:")
                    print("📄 Content length: \(pageContent.count) characters")
                    if !pageContent.isEmpty {
                        print("📄 Content preview: \(String(pageContent.prefix(500)))")
                        if pageContent.count > 500 {
                            print("... (truncated, full content is \(pageContent.count) characters)")
                        }
                    }
                    print("💬 User message: \(message)")
                    print("---")
                }

                sendToAI(message: message, includePageContent: success)
            }
        }
    }

    private func sendToAI(message: String, includePageContent: Bool) {
        // Create a placeholder message for streaming (no loading indicator needed)
        let streamingMessage = ChatMessage(content: "", isUser: false)
        streamingMessageId = streamingMessage.id
        streamingContent = ""

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            messages.append(streamingMessage)
        }

        Task {
            do {
                let contentToSend = (includePageContent && !pageContent.isEmpty) ? pageContent : nil

                try await providerManager.sendMessageStreaming(
                    message,
                    pageContent: contentToSend,
                    model: selectedModel
                ) { chunk in
                    // Update streaming content on main actor
                    streamingContent += chunk

                    // Find and update the streaming message
                    if let streamingId = streamingMessageId,
                       let index = messages.firstIndex(where: { $0.id == streamingId })
                    {
                        messages[index] = ChatMessage(
                            id: streamingId,
                            content: streamingContent,
                            isUser: false,
                            timestamp: messages[index].timestamp
                        )
                    }
                }

                // Streaming complete - clean up
                streamingMessageId = nil
                streamingContent = ""

            } catch {
                // Remove the streaming message and show error
                if let streamingId = streamingMessageId,
                   let index = messages.firstIndex(where: { $0.id == streamingId })
                {
                    messages.remove(at: index)
                }

                errorMessage = error.localizedDescription

                // Show error as a system message
                let errorResponse = ChatMessage(
                    content: "Error: \(error.localizedDescription)",
                    isUser: false
                )
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    messages.append(errorResponse)
                }

                streamingMessageId = nil
                streamingContent = ""
            }
        }
    }

    private func startNewChat() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            messages.removeAll()
            hasExtractedContent = false  // Reset for new conversation
            pageContent = ""  // Clear old content
            streamingMessageId = nil  // Clear streaming state
            streamingContent = ""
        }
    }

    private func extractPageContent(completion: @escaping (Bool) -> Void = { _ in }) {
        guard let activeTab = tabManager.activeTab else {
            pageContent = ""
            completion(false)
            return
        }

        let script = """
        (function() {
            // Remove script and style elements
            var scripts = document.querySelectorAll('script, style, noscript');
            scripts.forEach(function(el) { el.remove(); });

            // Get the main content
            var content = '';
            var title = document.title || '';
            var metaDescription = '';
            var descriptionMeta = document.querySelector('meta[name="description"]');
            if (descriptionMeta) {
                metaDescription = descriptionMeta.getAttribute('content') || '';
            }

            // Try to find main content areas
            var mainContent = document.querySelector('main, article, [role="main"], .main-content, #main-content, .content');
            if (mainContent) {
                content = mainContent.innerText || mainContent.textContent || '';
            } else {
                // Fallback to body text
                content = document.body.innerText || document.body.textContent || '';
            }

            // Clean up the content
            content = content.replace(/\\s+/g, ' ').trim();

            return {
                title: title,
                description: metaDescription,
                content: content.substring(0, 8000), // Limit content length
                url: window.location.href
            };
        })();
        """

        activeTab.webView.evaluateJavaScript(script) { result, error in
            DispatchQueue.main.async {
                if let error {
                    print("Error extracting page content: \(error)")
                    pageContent = ""
                    completion(false)
                    return
                }

                if let result = result as? [String: Any] {
                    let title = result["title"] as? String ?? ""
                    let description = result["description"] as? String ?? ""
                    let content = result["content"] as? String ?? ""
                    let url = result["url"] as? String ?? ""

                    var extractedContent = ""
                    if !title.isEmpty {
                        extractedContent += "Title: \(title)\n\n"
                    }
                    if !description.isEmpty {
                        extractedContent += "Description: \(description)\n\n"
                    }
                    if !url.isEmpty {
                        extractedContent += "URL: \(url)\n\n"
                    }
                    if !content.isEmpty {
                        extractedContent += "Content:\n\(content)"
                    }

                    pageContent = extractedContent
                    completion(!extractedContent.isEmpty)
                } else {
                    pageContent = ""
                    completion(false)
                }
            }
        }
    }

    // MARK: - Provider Logo Helper

    @ViewBuilder
    private func providerLogo(for model: AIModel) -> some View {
        switch model {
        case .gpt4, .gpt4Turbo:
            Image("openai-capsule-logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
        case .claude3:
            Image(systemName: "brain.head.profile")
                .foregroundColor(.purple)
        case .gemini:
            Image(systemName: "diamond")
                .foregroundColor(.blue)
        }
    }
}

#Preview {
    ChatPanel()
        .environmentObject(TabManager(
            modelContainer: try! ModelConfiguration.createOraContainer(isPrivate: false),
            modelContext: ModelContext(try! ModelConfiguration.createOraContainer(isPrivate: false)),
            mediaController: MediaController()
        ))
        .withTheme()
}
