import SwiftUI

enum OraInputVariant {
    case `default`
    case outline
    case ghost
}

struct OraInput: View {
    @Binding var text: String
    var placeholder: String = ""
    var label: String?
    var hint: String?
    var error: String?
    var variant: OraInputVariant = .default
    var size: OraButtonSize = .md
    var isDisabled: Bool = false
    var isSecure: Bool = false
    var leadingIcon: String?
    var trailingIcon: String?
    var onSubmit: (() -> Void)?

    @Environment(\.theme) private var theme
    @FocusState private var isFocused: Bool

    // MARK: - Size tokens

    private var hPadding: CGFloat {
        switch size {
        case .sm: 10
        case .md: 14
        case .lg: 18
        }
    }

    private var vPadding: CGFloat {
        switch size {
        case .sm: 5
        case .md: 7
        case .lg: 9
        }
    }

    private var fontSize: CGFloat {
        switch size {
        case .sm: 12
        case .md: 13
        case .lg: 14
        }
    }

    private var cornerRadius: CGFloat {
        switch size {
        case .sm: 8
        case .md: 10
        case .lg: 12
        }
    }

    // MARK: - Variant colors

    private var backgroundColor: Color {
        guard !isDisabled else { return theme.disabledBackground }
        switch variant {
        case .default:
            return isFocused
                ? theme.mutedBackground.opacity(0.8)
                : theme.mutedBackground
        case .outline, .ghost:
            return .clear
        }
    }

    private var borderColor: Color {
        if let _ = error { return theme.destructive }
        guard !isDisabled else { return theme.border.opacity(0.4) }

        switch variant {
        case .default:
            return isFocused ? theme.foreground.opacity(0.35) : .clear
        case .outline:
            return isFocused ? theme.foreground.opacity(0.5) : theme.border
        case .ghost:
            return .clear
        }
    }

    private var placeholderColor: Color {
        isDisabled ? theme.disabledForeground : theme.placeholder
    }

    private var textColor: Color {
        isDisabled ? theme.disabledForeground : theme.foreground
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let label {
                Text(label)
                    .font(.system(size: fontSize - 0.5, weight: .medium))
                    .foregroundColor(isDisabled ? theme.disabledForeground : theme.foreground)
            }

            HStack(spacing: 6) {
                if let icon = leadingIcon {
                    Image(systemName: icon)
                        .font(.system(size: fontSize - 1))
                        .foregroundColor(isFocused ? textColor : placeholderColor)
                }

                Group {
                    if isSecure {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .textFieldStyle(.plain)
                .font(.system(size: fontSize))
                .foregroundColor(textColor)
                .focused($isFocused)
                .onSubmit { onSubmit?() }

                if let icon = trailingIcon {
                    Image(systemName: icon)
                        .font(.system(size: fontSize - 1))
                        .foregroundColor(placeholderColor)
                }
            }
            .padding(.horizontal, hPadding)
            .padding(.vertical, vPadding)
            .background(backgroundColor)
            .overlay {
                ConditionallyConcentricRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: isFocused ? 2 : 1)
            }
            .clipShape(ConditionallyConcentricRectangle(cornerRadius: cornerRadius))
            .animation(.easeInOut(duration: 0.15), value: isFocused)
            .disabled(isDisabled)

            if let error {
                Text(error)
                    .font(.system(size: fontSize - 2))
                    .foregroundColor(theme.destructive)
                    .transition(.opacity.combined(with: .offset(y: -4)))
            } else if let hint {
                Text(hint)
                    .font(.system(size: fontSize - 2))
                    .foregroundColor(theme.mutedForeground)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: error != nil)
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var text1 = ""
    @Previewable @State var text2 = "ora-browser"
    @Previewable @State var text3 = ""
    @Previewable @State var text4 = ""
    @Previewable @State var text5 = ""
    @Previewable @State var text6 = ""

    VStack(alignment: .leading, spacing: 20) {
        Group {
            Text("Default").font(.caption).foregroundStyle(.secondary)
            OraInput(text: $text1, placeholder: "Enter value…")
            OraInput(text: $text2, placeholder: "Enter value…", label: "Repository name")
            OraInput(
                text: $text3,
                placeholder: "Enter value…",
                label: "With hint",
                hint: "This is a helper message"
            )
            OraInput(
                text: $text4,
                placeholder: "Enter value…",
                label: "With error",
                error: "This field is required"
            )
        }

        Group {
            Text("Outline").font(.caption).foregroundStyle(.secondary)
            OraInput(text: $text5, placeholder: "Search…", variant: .outline, leadingIcon: "magnifyingglass")
            OraInput(text: $text6, placeholder: "Disabled", variant: .outline, isDisabled: true)
        }

        Group {
            Text("Ghost").font(.caption).foregroundStyle(.secondary)
            OraInput(text: $text1, placeholder: "Inline edit…", variant: .ghost)
        }

        Group {
            Text("Sizes").font(.caption).foregroundStyle(.secondary)
            OraInput(text: $text1, placeholder: "Small", size: .sm)
            OraInput(text: $text1, placeholder: "Medium")
            OraInput(text: $text1, placeholder: "Large", size: .lg)
        }

        Group {
            Text("With icons").font(.caption).foregroundStyle(.secondary)
            OraInput(
                text: $text1,
                placeholder: "Search engines…",
                leadingIcon: "magnifyingglass",
                trailingIcon: "xmark.circle.fill"
            )
            OraInput(text: $text1, placeholder: "Password", isSecure: true, leadingIcon: "lock", trailingIcon: "eye")
        }
    }
    .padding(24)
    .frame(width: 360)
    .withTheme()
}
