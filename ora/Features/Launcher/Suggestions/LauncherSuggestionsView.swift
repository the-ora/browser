import SwiftUI

struct LauncherSuggestionsView: View {
    @Environment(\.theme) private var theme
    @Binding var text: String
    @Binding var suggestions: [LauncherSuggestion]
    @Binding var focusedElement: UUID

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(suggestions) { suggestion in
                LauncherSuggestionItem(
                    suggestion: suggestion,
                    focusedElement: $focusedElement
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }
}
