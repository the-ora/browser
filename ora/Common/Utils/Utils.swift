import SwiftUI

func isDomainOrIP(_ text: String) -> Bool {
    let cleanText = text.replacingOccurrences(of: "https://", with: "")
        .replacingOccurrences(of: "http://", with: "")
        .replacingOccurrences(of: "www.", with: "")

    let ipPattern = #"^(\d{1,3}\.){3}\d{1,3}$"#
    if cleanText.range(of: ipPattern, options: .regularExpression) != nil {
        return true
    }

    let domainPattern =
        #"^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$"#

    return cleanText.range(of: domainPattern, options: .regularExpression) != nil
        && cleanText.contains(".")
}
