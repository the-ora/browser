import SwiftUI

struct LauncherSuggestionsView: View {
    @Environment(\.theme) private var theme
    @Binding var text: String
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
    }
}
