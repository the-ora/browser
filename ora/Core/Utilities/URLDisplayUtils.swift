import Foundation

struct URLDisplayParts {
    let host: String
    let title: String?
}

enum URLDisplayUtils {
    static func displayString(url: URL, title: String, showFull: Bool) -> String {
        let parts = displayParts(url: url, title: title, showFull: showFull)
        if let title = parts.title {
            return "\(parts.host) / \(title)"
        }
        return parts.host
    }

    static func displayParts(url: URL, title: String, showFull: Bool) -> URLDisplayParts {
        if showFull {
            return URLDisplayParts(host: url.absoluteString, title: nil)
        }

        var host = url.host ?? url.absoluteString
        if host.hasPrefix("www.") {
            host = String(host.dropFirst(4))
        }

        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        if trimmedTitle.isEmpty {
            return URLDisplayParts(host: host, title: nil)
        }

        return URLDisplayParts(host: host, title: trimmedTitle)
    }
}
