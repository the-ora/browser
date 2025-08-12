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
                LauncherSuggestionItem(
                    suggestion: suggestion,
                    defaultAI: searchEngineService.getDefaultAIChat(),
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
