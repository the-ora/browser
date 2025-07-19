import SwiftUI

enum SuggestionFocus: Hashable {
  case suggestion(id: UUID)
}

struct LauncherSuggestionsView: View {
  @Environment(\.theme) private var theme
  @Binding var text: String
  @StateObject private var searchEngineService = SearchEngineService()

  @State private var suggestions: [LauncherSuggestion] = [
    LauncherSuggestion(
      type: .openedTab, title: "Tab 1",
      action: { print("Debug: Executing action for Tab 1") }),
    LauncherSuggestion(
      type: .openedTab, title: "Tab 2",
      action: { print("Debug: Executing action for Tab 2") }),
    LauncherSuggestion(
      type: .suggestedQuery, title: "Search on Google",
      action: { print("Debug: Executing action for suggested query") }),
    LauncherSuggestion(
      type: .suggestedLink, title: "Open link", url: URL(string: "https://www.google.com"),
      action: { print("Debug: Executing action for suggested link") }),
    LauncherSuggestion(
      type: .aiChat, title: "Grok",
      action: { print("Debug: Executing action for AI search") }),
  ]

  @FocusState private var focusedElement: SuggestionFocus?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(suggestions) { suggestion in
        LauncherSuggestionItem(suggestion: suggestion, focusedElement: $focusedElement, defaultAI: searchEngineService.getDefaultAIChat())
          .focusable()
          .focused($focusedElement, equals: .suggestion(id: suggestion.id))
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.top, 4)
    .overlay(
      Rectangle()
        .frame(height: 1)
        .foregroundColor(theme.border.opacity(0.5)),
      alignment: .top
    )
    .onAppear {
      focusedElement = .suggestion(id: suggestions[0].id)
    }
  }
}
