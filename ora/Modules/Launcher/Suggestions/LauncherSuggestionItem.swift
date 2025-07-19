import SwiftUI

enum LauncherSuggestionType {
  case openedTab, suggestedQuery, suggestedLink, aiChat
}

struct LauncherSuggestion: Identifiable {
  let id = UUID()
  let type: LauncherSuggestionType
  let title: String
  let url: URL?
  let icon: String?
  let faviconURL: String?
  let action: () -> Void

  init(
    type: LauncherSuggestionType,
    title: String,
    url: URL? = nil,
    icon: String? = nil,
    faviconURL: String? = nil,
    action: @escaping () -> Void
  ) {
    self.type = type
    self.title = title
    self.url = url
    self.icon = icon
    self.faviconURL = faviconURL
    self.action = action
  }
}

struct LauncherSuggestionItem: View {
  let suggestion: LauncherSuggestion
  @FocusState.Binding var focusedElement: SuggestionFocus?
  let defaultAI: SearchEngine?

  @State private var isHovered = false
  @Environment(\.theme) private var theme

  private var isAIChat: Bool {
    suggestion.type == .aiChat
  }

  private var shouldShowURL: Bool {
    suggestion.url != nil && !isAIChat && suggestion.type != .suggestedQuery
  }

  private var foregroundColor: Color {
    if (focusedElement == .suggestion(id: suggestion.id) || isHovered) && isAIChat {
      return defaultAI?.foregroundColor ?? .secondary
    } else if focusedElement == .suggestion(id: suggestion.id) {
      return theme.foreground
    }
    return .secondary
  }

  private var backgroundColor: Color {
    guard focusedElement == .suggestion(id: suggestion.id) || isHovered else { return .clear }
    return isAIChat
      ? defaultAI?.color ?? .clear
      : isHovered ? theme.foreground.opacity(0.07) : theme.foreground.opacity(0.1)
  }

  private var aiIcon: String {
    guard isAIChat && defaultAI?.icon != nil else { return "" }
    return focusedElement == .suggestion(id: suggestion.id) || isHovered
      ? defaultAI!.icon
      : defaultAI!.icon + "-inverted"
  }

  @ViewBuilder
  var icon: some View {
    if isAIChat && defaultAI?.icon != nil {
      Image(
        aiIcon
      )
      .resizable()
      .frame(width: 14, height: 14)
    } else if let faviconURL = suggestion.faviconURL {
      AsyncImage(url: URL(string: faviconURL)) { image in
        image
          .resizable()
          .frame(width: 14, height: 14)
      } placeholder: {
        Image(systemName: "globe")
          .resizable()
          .frame(width: 14, height: 14)
          .foregroundStyle(
            focusedElement == .suggestion(id: suggestion.id) || isHovered
              ? theme.foreground : .secondary)
      }
    } else {
      Image(systemName: "magnifyingglass")
        .resizable()
        .frame(width: 14, height: 14)
        .foregroundStyle(
          focusedElement == .suggestion(id: suggestion.id) || isHovered
            ? theme.foreground : .secondary)
    }
  }

  @ViewBuilder
  var actionLabel: some View {
    if isAIChat {
      HStack(alignment: .center, spacing: 10) {
        Text("Ask \(defaultAI?.name ?? "")")
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(
            focusedElement == .suggestion(id: suggestion.id) || isHovered
              ? defaultAI?.foregroundColor ?? .secondary : .secondary)
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(
        focusedElement == .suggestion(id: suggestion.id) || isHovered
          ? defaultAI?.foregroundColor?.opacity(0.10) ?? .clear : theme.foreground.opacity(0.07)
      )
      .cornerRadius(6)
    } else if suggestion.type == .openedTab {
      HStack(alignment: .center, spacing: 10) {
        Text("Switch to tab")
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(
            focusedElement == .suggestion(id: suggestion.id) || isHovered
              ? theme.foreground : .secondary)
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(theme.foreground.opacity(0.07))
      .cornerRadius(6)
    }
  }

  var body: some View {
    HStack(alignment: .center, spacing: 8) {
      icon
      HStack(alignment: .center, spacing: 8) {
        Text(suggestion.title)
          .font(.system(size: 16, weight: .medium))
          .bold()
          .foregroundStyle(foregroundColor)

        if shouldShowURL {
          Text(" — \(suggestion.url?.absoluteString ?? "")")
            .font(.system(size: 14))
            .foregroundStyle(Color(.secondaryLabelColor))
        }
      }
      Spacer()
      actionLabel
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 10)
    .frame(width: 798, alignment: .leading)
    .background(backgroundColor)
    .cornerRadius(8)
    .onTapGesture {
      suggestion.action()
    }
    .onHover { hover in
      isHovered = hover
    }
    .focused($focusedElement, equals: .suggestion(id: suggestion.id))
  }
}
