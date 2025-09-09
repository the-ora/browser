import Foundation
import SwiftUI

// MARK: - Custom Scheme Protocol

protocol CustomSchemeHandler {
    /// The scheme this handler manages (e.g., "test")
    var scheme: String { get }

    /// Create the SwiftUI view for this custom scheme
    /// - Parameters:
    ///   - url: The full URL (e.g., "ora://test/item?q=hello")
    ///   - conversationId: The extracted conversation ID (if any)
    ///   - query: The extracted query parameter (e.g., "hello")
    /// - Returns: A SwiftUI view to display in place of the web view
    func createView(for url: URL, conversationId: UUID?, query: String?) -> AnyView

    /// The title to display in the tab for this scheme
    func title(for url: URL, conversationId: UUID?, query: String?) -> String

    /// The favicon/icon to display for this scheme (system name or image name)
    func icon(for url: URL) -> String
}

// MARK: - Custom Scheme Registry

@Observable
class CustomSchemeRegistry {
    static let shared = CustomSchemeRegistry()

    private var handlers: [String: CustomSchemeHandler] = [:]

    private init() {
        // Register built-in handlers
        registerDefaultHandlers()
    }

    /// Register a custom scheme handler
    func register(_ handler: CustomSchemeHandler) {
        handlers[handler.scheme] = handler
    }

    /// Check if a URL should be handled by a custom scheme
    func shouldHandle(_ url: URL) -> Bool {
        guard url.scheme == "ora", let host = url.host else { return false }
        return handlers[host] != nil
    }

    /// Get the handler for a URL
    func handler(for url: URL) -> CustomSchemeHandler? {
        guard url.scheme == "ora", let host = url.host else { return nil }
        return handlers[host]
    }

    /// Create a view for a custom scheme URL
    func createView(for url: URL) -> AnyView? {
        guard let handler = handler(for: url) else { return nil }
        let conversationId = extractConversationId(from: url)
        let query = extractQuery(from: url)
        return handler.createView(for: url, conversationId: conversationId, query: query)
    }

    /// Get title for a custom scheme URL
    func title(for url: URL) -> String? {
        guard let handler = handler(for: url) else { return nil }
        let conversationId = extractConversationId(from: url)
        let query = extractQuery(from: url)
        return handler.title(for: url, conversationId: conversationId, query: query)
    }

    /// Get icon for a custom scheme URL
    func icon(for url: URL) -> String? {
        guard let handler = handler(for: url) else { return nil }
        return handler.icon(for: url)
    }

    private func extractQuery(from url: URL) -> String? {
        // Validate URL structure first
        guard url.scheme == "ora",
              let host = url.host,
              !host.isEmpty,
              host
              .rangeOfCharacter(from: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-")).inverted) == nil
        else { return nil }

        // Extract and validate query
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              let qItem = queryItems.first(where: { $0.name == "q" }),
              let value = qItem.value,
              value.count <= 10000 // Reasonable length limit
        else { return nil }

        // Remove control characters for safety
        return value.components(separatedBy: .controlCharacters).joined()
    }

    /// Extract conversation ID from URL path
    /// URL format: ora://scheme/[conversationId]?q=query
    private func extractConversationId(from url: URL) -> UUID? {
        guard url.scheme == "ora",
              let host = url.host,
              !url.path.isEmpty else { return nil }

        let pathComponents = url.path.components(separatedBy: "/").filter { !$0.isEmpty }
        guard let firstComponent = pathComponents.first else { return nil }

        return UUID(uuidString: firstComponent)
    }

    private func registerDefaultHandlers() {
        // Register test handler
        register(TestSchemeHandler())
    }
}

// MARK: - Test Scheme Handler

struct TestSchemeHandler: CustomSchemeHandler {
    let scheme = "test"

    func createView(for url: URL, conversationId: UUID?, query: String?) -> AnyView {
        AnyView(TestSchemeView(url: url, conversationId: conversationId, query: query))
    }

    func title(for url: URL, conversationId: UUID?, query: String?) -> String {
        if let query, !query.isEmpty {
            return "Test: \(query)"
        }
        return "Test Page"
    }

    func icon(for url: URL) -> String {
        return "testtube.2"
    }
}

// MARK: - Test Scheme View

struct TestSchemeView: View {
    let url: URL
    let conversationId: UUID?
    let query: String?

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "testtube.2")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("Test Scheme")
                .font(.largeTitle)
                .bold()

            VStack(alignment: .leading, spacing: 10) {
                Text("URL: \(url.absoluteString)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let conversationId {
                    Text("Conversation ID: \(conversationId.uuidString)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let query {
                    Text("Query: \(query)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)

            Button("Reload Page") {
                // This would trigger a page reload in the actual implementation
                print("Reload button tapped for: \(url)")
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.controlBackgroundColor))
    }
}

// MARK: - Custom Scheme Errors

enum CustomSchemeError: LocalizedError {
    case unknownScheme(String)

    var errorDescription: String? {
        switch self {
        case let .unknownScheme(scheme):
            return "Unknown scheme: \(scheme)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .unknownScheme:
            return "Available schemes: test"
        }
    }
}
