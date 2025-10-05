import Foundation

// MARK: - AI Provider Protocol

protocol AIProvider {
    var name: String { get }
    var models: [AIModel] { get }
    var requiresAPIKey: Bool { get }
    var isConfigured: Bool { get }

    func sendMessage(_ message: String, pageContent: String?, model: AIModel) async throws -> String
}

// MARK: - AI Provider Error

enum AIProviderError: LocalizedError {
    case notConfigured
    case invalidAPIKey
    case networkError(Error)
    case invalidResponse
    case rateLimited
    case modelNotSupported
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "AI provider is not configured. Please add your API key in settings."
        case .invalidAPIKey:
            return "Invalid API key. Please check your API key in settings."
        case let .networkError(error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from AI provider."
        case .rateLimited:
            return "Rate limit exceeded. Please try again later."
        case .modelNotSupported:
            return "Selected model is not supported by this provider."
        case let .unknown(message):
            return "Unknown error: \(message)"
        }
    }
}

// MARK: - AI Provider Manager

@MainActor
class AIProviderManager: ObservableObject {
    static let shared = AIProviderManager()

    @Published private(set) var providers: [AIProvider] = []
    @Published var selectedProvider: AIProvider?

    private init() {
        setupProviders()
    }

    private func setupProviders() {
        providers = [
            OpenAIProvider()
            // Future providers: ClaudeProvider(), GeminiProvider(), etc.
        ]

        // Select the first configured provider, or first provider if none configured
        selectedProvider = providers.first { $0.isConfigured } ?? providers.first
    }

    func refreshProviders() {
        setupProviders()
    }

    func sendMessage(_ message: String, pageContent: String?, model: AIModel) async throws -> String {
        guard let provider = selectedProvider else {
            throw AIProviderError.notConfigured
        }

        return try await provider.sendMessage(message, pageContent: pageContent, model: model)
    }
}
