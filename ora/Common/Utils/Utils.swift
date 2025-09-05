import Foundation

func extractDomainOrIP(from text: String) -> String? {
    guard let url = URL(string: text.hasPrefix("http") ? text : "https://\(text)") else {
        return nil
    }

    guard let host = url.host else {
        return nil
    }

    return host
}

func isValidURL(_ text: String) -> Bool {
    guard let host = extractDomainOrIP(from: text) else { return false }

    let ipPattern = #"^(\d{1,3}\.){3}\d{1,3}$"#
    if host.range(of: ipPattern, options: .regularExpression) != nil {
        return true
    }

    let domainPattern =
        #"^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)+$"#

    return host.range(of: domainPattern, options: .regularExpression) != nil
}

func constructURL(from text: String) -> URL? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
        return URL(string: trimmed)
    }
    if isValidURL(trimmed) {
        return URL(string: "https://\(trimmed)")
    }
    return nil
}
