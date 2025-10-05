import AIProxy
import Foundation

// MARK: - OpenAI Provider

class OpenAIProvider: AIProvider {
    let name = "OpenAI"
    let requiresAPIKey = true

    let models: [AIModel] = [
        .gpt4,
        .gpt4Turbo
    ]

    var isConfigured: Bool {
        KeychainService.shared.hasOpenAIKey()
    }

    private var apiKey: String {
        KeychainService.shared.getOpenAIKey() ?? ""
    }

    func sendMessage(_ message: String, pageContent: String?, model: AIModel) async throws -> String {
        guard isConfigured else {
            throw AIProviderError.notConfigured
        }

        // Create the OpenAI service using BYOK (bring your own key)
        let openAIService = AIProxy.openAIDirectService(
            unprotectedAPIKey: apiKey
        )

        // Build messages array
        var messages: [OpenAIChatCompletionRequestBody.Message] = []

        // Add system message with page content if available
        if let pageContent, !pageContent.isEmpty {
            let systemMessage = """
            You are a helpful AI assistant. The user is asking about a web page. Here is the page content for context:

            \(pageContent)

            Please answer the user's question based on this page content when relevant. Be concise but informative.
            """
            messages.append(.system(content: .text(systemMessage)))
        }

        // Add user message
        messages.append(.user(content: .text(message)))

        // Map our model enum to OpenAI model strings
        let openAIModel: String
        switch model {
        case .gpt4:
            openAIModel = "gpt-4"
        case .gpt4Turbo:
            openAIModel = "gpt-4-turbo"
        case .claude3, .gemini:
            throw AIProviderError.modelNotSupported
        }

        let requestBody = OpenAIChatCompletionRequestBody(
            model: openAIModel,
            messages: messages
        )

        do {
            // Use streaming for real-time responses
            let stream = try await openAIService.streamingChatCompletionRequest(
                body: requestBody,
                secondsToWait: 60
            )

            var fullResponse = ""
            for try await chunk in stream {
                if let content = chunk.choices.first?.delta.content {
                    fullResponse += content
                }
            }

            return fullResponse.trimmingCharacters(in: .whitespacesAndNewlines)

        } catch let AIProxyError.unsuccessfulRequest(statusCode, responseBody) {
            // Handle specific OpenAI errors
            switch statusCode {
            case 401:
                throw AIProviderError.invalidAPIKey
            case 429:
                throw AIProviderError.rateLimited
            default:
                throw AIProviderError.unknown("OpenAI API error (\(statusCode)): \(responseBody)")
            }
        } catch {
            throw AIProviderError.networkError(error)
        }
    }
}
