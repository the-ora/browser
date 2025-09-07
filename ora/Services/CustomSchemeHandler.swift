import Foundation
import SwiftUI

// MARK: - Custom Scheme Protocol

protocol CustomSchemeHandler {
    /// The scheme this handler manages (e.g., "apple-intelligence")
    var scheme: String { get }

    /// Create the SwiftUI view for this custom scheme
    /// - Parameters:
    ///   - url: The full URL (e.g., "ora://apple-intelligence?q=hello")
    ///   - query: The extracted query parameter (e.g., "hello")
    /// - Returns: A SwiftUI view to display in place of the web view
    func createView(for url: URL, query: String?) -> AnyView

    /// The title to display in the tab for this scheme
    func title(for url: URL, query: String?) -> String

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
        let query = extractQuery(from: url)
        return handler.createView(for: url, query: query)
    }

    /// Get title for a custom scheme URL
    func title(for url: URL) -> String? {
        guard let handler = handler(for: url) else { return nil }
        let query = extractQuery(from: url)
        return handler.title(for: url, query: query)
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

    private func registerDefaultHandlers() {
        // Register Apple Intelligence handler if available
        if #available(macOS 26.0, *) {
            register(AppleIntelligenceSchemeHandler())
        }
    }
}

// MARK: - Apple Intelligence Scheme Handler

@available(macOS 26.0, *)
struct AppleIntelligenceSchemeHandler: CustomSchemeHandler {
    let scheme = "apple-intelligence"

    func createView(for url: URL, query: String?) -> AnyView {
        AnyView(AIChatView(initialQuery: query))
    }

    func title(for url: URL, query: String?) -> String {
        if let query, !query.isEmpty {
            return "Apple Intelligence: \(query)"
        }
        return "Apple Intelligence"
    }

    func icon(for url: URL) -> String {
        // Use sparkles icon as fallback since apple.intelligence might not be available
        return "sparkles"
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
            return "Available schemes: apple-intelligence"
        }
    }
}
