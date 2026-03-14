import SwiftUI

struct LauncherMain: View {
    @Binding var text: String
    @Binding var match: LauncherMatch?
    var isFocused: FocusState<Bool>.Binding
    let onTabPress: () -> Void
    let onSubmit: (String?) -> Void
    @ObservedObject var viewModel: LauncherViewModel

    @Environment(\.theme) private var theme

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
                    onSubmit: {
                        viewModel.executeCommand()
                    },
                    onDelete: {
                        if text.isEmpty, let currentMatch = match {
                            text = currentMatch.originalAlias
                            match = nil
                            return true
                        }
                        return false
                    },
                    onMoveUp: {
                        viewModel.moveFocusedElement(.up)
                    },
                    onMoveDown: {
                        viewModel.moveFocusedElement(.down)
                    },
                    cursorColor: match?.color ?? theme.foreground,
                    placeholder: getPlaceholder(match: match)
                )
                .onChange(of: text) { _, newValue in
                    viewModel.currentText = newValue
                    viewModel.searchHandler(newValue)
                }
                .textFieldStyle(PlainTextFieldStyle())
                .focused(isFocused)
            }
            .animation(nil, value: match?.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)

            if match == nil, !viewModel.suggestions.isEmpty {
                LauncherSuggestionsView(
                    text: $text,
                    suggestions: $viewModel.suggestions,
                    focusedElement: $viewModel.focusedElement
                )
            }
        }
        .padding(8)
        .frame(minWidth: 320, maxWidth: 814, alignment: .leading)
        .background(theme.launcherMainBackground)
        .background(BlurEffectView(material: .popover, blendingMode: .withinWindow))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .inset(by: 0.25)
                .stroke(
                    Color(match?.color ?? theme.foreground)
                        .opacity(0.15),
                    lineWidth: 0.5
                )
        )
        .shadow(
            color: Color.black.opacity(0.1),
            radius: 40, x: 0, y: 24
        )
    }

    private func getPlaceholder(match: LauncherMatch?) -> String {
        guard let match else {
            return "Search the web or enter url..."
        }

        if let engine = viewModel.searchEngineService.getSearchEngine(byName: match.text) {
            let prefix = engine.isAIChat ? "Ask" : "Search on"
            return "\(prefix) \(engine.name)"
        }

        return "Search on \(match.text)"
    }

    private func getIconName(match: LauncherMatch?, text: String) -> String {
        if match != nil {
            return "magnifyingglass"
        }
        return isValidURL(text) ? "globe" : "magnifyingglass"
    }
}
