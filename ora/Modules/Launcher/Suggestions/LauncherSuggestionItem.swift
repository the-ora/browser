import SwiftUI

enum LauncherSuggestionType {
    case openedTab, suggestedQuery, suggestedLink, aiChat
}

struct LauncherSuggestion: Identifiable {
    let id = UUID()
    let type: LauncherSuggestionType
    let title: String
    let name: String?
    let url: URL?
    let icon: String?
    let faviconURL: URL?
    let faviconLocalFile: URL?
    let action: () -> Void

    init(
        type: LauncherSuggestionType,
        title: String,
        name: String? = nil,
        url: URL? = nil,
        icon: String? = nil,
        faviconURL: URL? = nil,
        faviconLocalFile: URL? = nil,
        action: @escaping () -> Void
    ) {
        self.type = type
        self.title = title
        self.name = name
        self.url = url
        self.icon = icon
        self.faviconURL = faviconURL
        self.faviconLocalFile = faviconLocalFile
        self.action = action
    }
}

struct LauncherSuggestionItem: View {
    let suggestion: LauncherSuggestion
    let defaultAI: SearchEngine?
    @Binding var focusedElement: UUID

    @State private var isHovered = false
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var toolbarManager: ToolbarManager

    init(suggestion: LauncherSuggestion, defaultAI: SearchEngine?, focusedElement: Binding<UUID>) {
        self.suggestion = suggestion
        self.defaultAI = defaultAI
        self._focusedElement = focusedElement
    }

    private var isAIChat: Bool {
        suggestion.type == .aiChat
    }

    private var shouldShowURL: Bool {
        suggestion.url != nil && !isAIChat && suggestion.type != .suggestedQuery && suggestion.type != .openedTab
    }

    private var foregroundColor: Color {
        if focusedElement == suggestion.id || isHovered, isAIChat {
            return defaultAI?.foregroundColor ?? .secondary
        } else if focusedElement == suggestion.id {
            return theme.foreground
        }
        return .secondary
    }

    private var backgroundColor: Color {
        if focusedElement != suggestion.id || isHovered { return .clear }
        return isAIChat
            ? defaultAI?.color ?? .clear
            : isHovered ? theme.foreground.opacity(0.07) : theme.foreground.opacity(0.1)
    }

    private var aiIcon: String {
        guard isAIChat && defaultAI?.icon != nil else { return "" }
        return focusedElement == suggestion.id || isHovered
            ? defaultAI!.icon
            : defaultAI!.icon + "-inverted"
    }

    @ViewBuilder
    var icon: some View {
        if isAIChat, defaultAI?.icon != nil {
            Image(
                aiIcon
            )
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
                Text("Ask \(suggestion.name ?? defaultAI?.name ?? "")  ↩")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(
                        focusedElement == suggestion.id || isHovered
                            ? defaultAI?.foregroundColor ?? .secondary : .secondary
                    )
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                focusedElement == suggestion.id || isHovered
                    ? defaultAI?.foregroundColor?.opacity(0.10) ?? .clear : theme.foreground.opacity(0.07)
            )
            .cornerRadius(6)
        } else if suggestion.type == .openedTab {
            HStack(alignment: .center, spacing: 8) {
                Text("Switch to tab ")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(
                        focusedElement == suggestion.id || isHovered
                            ? theme.foreground : .secondary
                    )

                Image(systemName: "arrow.right")
                    .resizable()
                    .frame(width: 12, height: 12)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(
                                focusedElement == suggestion.id || isHovered
                                    ? theme.foreground : theme.foreground.opacity(0.07)
                            )
                    )
                    .foregroundStyle(
                        focusedElement == suggestion.id || isHovered
                            ? theme.background : .secondary
                    )
            }
            // .padding(.horizontal, 8)
            // .padding(.vertical, 4)
            // .background(theme.foreground.opacity(0.07))
            .cornerRadius(6)
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
                        .frame(width: 250, alignment: .leading)
                        .lineLimit(1)
                        .truncationMode(.middle)
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
            appState.showLauncher = false
        }
        .onHover { hover in
            if hover {
                focusedElement = suggestion.id
            }
        }
//        .focused($focusedElement, equals: suggestion.id)
    }
}
