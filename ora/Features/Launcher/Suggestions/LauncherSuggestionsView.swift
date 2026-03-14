import SwiftUI

enum SuggestionFocus: Hashable {
    case suggestion(id: UUID)
}

struct LauncherSuggestionsView: View {
    @Environment(\.theme) private var theme
    @Binding var text: String
    @StateObject private var searchEngineService = SearchEngineService()
    @Binding var suggestions: [LauncherSuggestion]
    @Binding var focusedElement: UUID

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(suggestions) { suggestion in
                let engine = suggestion.type == .aiChat && suggestion.name != nil ? searchEngineService
                    .getSearchEngine(byName: suggestion.name!) : searchEngineService.getDefaultAIChat()
                LauncherSuggestionItem(
                    suggestion: suggestion,
                    defaultAI: engine,
                    focusedElement: $focusedElement
                )
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
            searchEngineService.setTheme(theme)
        }
        // .onChange(of: theme) { _, newValue in
        //     searchEngineService.setTheme(newValue)
        // }
    }
}
