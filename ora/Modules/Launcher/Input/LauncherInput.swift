import SwiftUI

struct LauncherInput: View {
  struct Match {
    let text: String
    let color: Color
    let foregroundColor: Color
    let icon: String
    let originalAlias: String
    let searchURL: String
  }
  @Binding var text: String
  @Binding var match: Match?
  var isFocused: FocusState<Bool>.Binding
  let onTabPress: () -> Void
  let onSubmit: () -> Void
  @Environment(\.theme) private var theme

  var results: [(id: String, tile: LauncherResultTile)] {
    [
      (
        "tab1",
        LauncherResultTile(
          type: .openedTab, title: "Tab 1", url: nil, icon: nil, backgroundColor: nil,
          foregroundColor: nil, action: { print("Debug: Executing action for Tab 1") })
      ),
      (
        "query",
        LauncherResultTile(
          type: .suggestedQuery, title: "Search for \"\(text)\"", url: nil, icon: nil,
          backgroundColor: nil, foregroundColor: nil,
          action: { print("Debug: Executing action for suggested query") })
      ),
      (
        "link",
        LauncherResultTile(
          type: .suggestedLink, title: "Open link", url: URL(string: "https://www.google.com"),
          icon: nil, backgroundColor: nil, foregroundColor: nil,
          action: { print("Debug: Executing action for suggested link") })
      ),
      (
        "ai",
        LauncherResultTile(
          type: .aiSearch, title: "Ask \"\(text)\"", url: nil, icon: nil, backgroundColor: nil,
          foregroundColor: nil, action: { print("Debug: Executing action for AI search") })
      ),
    ]
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .center, spacing: 8) {
        if match == nil {
          Image(systemName: getIconName(match: match, text: text))
            .resizable()
            .frame(width: 18, height: 18)
            .foregroundStyle(Color(.placeholderTextColor))
        }

        if match != nil {
          SearchEngineCapsule(
            text: match?.text ?? "",
            color: match?.color ?? .blue,
            foregroundColor: match?.foregroundColor ?? .white,
            icon: match?.icon ?? ""
          )
        }
        LauncherTextField(
          text: $text,
          font: NSFont.systemFont(ofSize: 18, weight: .medium),
          onTab: onTabPress,
          onSubmit: onSubmit,
          onDelete: {
            if text.isEmpty && match != nil {
              text = match!.originalAlias
              match = nil
              return true
            }
            return false
          },
          cursorColor: match?.color ?? (theme.foreground),
          placeholder: getPlaceholder(match: match)
        )
        .textFieldStyle(PlainTextFieldStyle())
        .focused(isFocused)
      }
      .animation(nil, value: match?.color)
      .padding(.horizontal, 8)
      .padding(.vertical, 10)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(8)
    .frame(width: 814, alignment: .leading)
    .background(theme.background.opacity(0.8))
    .background(BlurEffectView(material: .popover, blendingMode: .withinWindow))
    .cornerRadius(16)
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .inset(by: 0.25)
        .stroke(
          Color(match?.color ?? theme.foreground).opacity(0.15),
          lineWidth: 0.5)
    )
    .shadow(
      color: Color.black.opacity(0.3),
      radius: 40, x: 0, y: 24
    )
  }

  private func getPlaceholder(match: Match?) -> String {
    if match == nil {
      return "Search the web or enter url..."
    }
    switch match!.text {
    case "X":
      return "Search on X"
    case "Youtube":
      return "Search on Youtube"
    case "Google":
      return "Search on Google"
    case "ChatGPT":
      return "Ask ChatGPT"
    case "Grok":
      return "Ask Grok"
    case "Perplexity":
      return "Ask Perplexity"
    case "Reddit":
      return "Search on Reddit"
    case "T3Chat":
      return "Ask T3Chat"
    default:
      return "Search on \(match!.text)"
    }
  }

  private func isDomainOrIP(_ text: String) -> Bool {
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

  private func getIconName(match: Match?, text: String) -> String {
    if match != nil {
      return "magnifyingglass"
    }
    return isDomainOrIP(text) ? "globe" : "magnifyingglass"
  }
}
