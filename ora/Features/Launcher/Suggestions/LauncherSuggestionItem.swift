import SwiftUI

struct LauncherSuggestionItem: View {
    let suggestion: LauncherSuggestion
    @Binding var focusedElement: UUID

    @State private var isHovered = false
    @Environment(\.theme) private var theme
    @Environment(\.launcherMouseHasMoved) private var mouseHasMoved
    @EnvironmentObject var appState: AppState

    private var isAIChat: Bool {
        suggestion.type == .aiChat
    }

    private var shouldShowURL: Bool {
        guard let url = suggestion.url else { return false }
        if isAIChat || suggestion.type == .suggestedQuery || suggestion.type == .openedTab { return false }
        let urlString = url.absoluteString
        if suggestion.title == urlString || urlString.hasSuffix("://\(suggestion.title)") || urlString
            .hasSuffix("://\(suggestion.title)/")
        { return false }
        return true
    }

    private var isFocusedOrHovered: Bool {
        focusedElement == suggestion.id || isHovered
    }

    private var foregroundColor: Color {
        if focusedElement == suggestion.id {
            return theme.foreground
        }
        return .secondary
    }

    private var backgroundColor: Color {
        if focusedElement != suggestion.id || isHovered { return .clear }
        return isAIChat ? theme.background : theme.foreground.opacity(0.1)
    }

    @ViewBuilder
    var icon: some View {
        if isAIChat, let suggestionIcon = suggestion.icon, !suggestionIcon.isEmpty {
            Image(suggestionIcon)
                .resizable()
                .frame(width: 14, height: 14)
        } else if suggestion.faviconURL != nil {
            FavIcon(
                isWebViewReady: true,
                favicon: suggestion.faviconURL,
                faviconLocalFile: suggestion.faviconLocalFile,
                textColor: Color(.secondaryLabelColor)
            )
        } else {
            Image(systemName: suggestion.type == .suggestedLink ? "globe" : "magnifyingglass")
                .resizable()
                .frame(width: 14, height: 14)
                .foregroundStyle(
                    focusedElement == suggestion.id
                        ? theme.foreground : .secondary
                )
        }
    }

    @ViewBuilder
    var actionLabel: some View {
        if isAIChat {
            HStack(alignment: .center, spacing: 10) {
                Text("Ask \(suggestion.name ?? "")  ↩")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(
                        isFocusedOrHovered ? theme.foreground : .secondary
                    )
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(theme.foreground.opacity(0.07))
            .clipShape(ConditionallyConcentricRectangle(cornerRadius: 8, style: .continuous))
        } else if suggestion.type == .openedTab {
            HStack(alignment: .center, spacing: 8) {
                Text("Switch to tab ")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(
                        isFocusedOrHovered ? theme.foreground : .secondary
                    )

                Image(systemName: "arrow.right")
                    .resizable()
                    .frame(width: 12, height: 12)
                    .padding(6)
                    .background(
                        ConditionallyConcentricRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                isFocusedOrHovered
                                    ? theme.foreground : theme.foreground.opacity(0.07)
                            )
                    )
                    .foregroundStyle(
                        isFocusedOrHovered ? theme.background : .secondary
                    )
            }
            .clipShape(ConditionallyConcentricRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            icon
            HStack(alignment: .center, spacing: 4) {
                Text(suggestion.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(foregroundColor)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if shouldShowURL {
                    Text(" — \(suggestion.url?.absoluteString ?? "")")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(.secondaryLabelColor))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer()
            actionLabel
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor)
        .clipShape(ConditionallyConcentricRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture {
            suggestion.action()
            appState.showLauncher = false
            appState.isURLBarEditing = false
        }
        .onHover { hover in
            if hover, mouseHasMoved {
                focusedElement = suggestion.id
            }
        }
    }
}
