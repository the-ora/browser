import SwiftUI

enum OraButtonVariant {
    case `default`
    case secondary
    case outline
    case ghost
    case destructive
}

enum OraButtonSize {
    case sm
    case md
    case lg
}

struct OraButton: View {
    let label: String
    var variant: OraButtonVariant = .default
    var size: OraButtonSize = .md
    var isDisabled: Bool = false
    var isLoading: Bool = false
    var keyboardShortcut: String?
    var leadingIcon: String?
    var trailingIcon: String?
    var labelColorOverride: Color?
    let action: () -> Void

    @Environment(\.theme) private var theme
    @State private var isHovering = false

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
        case .sm: 6
        case .md: 8
        case .lg: 10
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

    private var iconSpacing: CGFloat {
        switch size {
        case .sm: 4
        case .md: 6
        case .lg: 8
        }
    }

    private var shortcutSize: CGFloat {
        switch size {
        case .sm: 16
        case .md: 18
        case .lg: 20
        }
    }

    // MARK: - Variant colors

    private var backgroundColor: Color {
        guard !isDisabled else { return theme.disabledBackground }
        switch variant {
        case .default:
            return isHovering ? theme.accent.opacity(0.85) : theme.accent
        case .secondary:
            return isHovering ? theme.mutedBackground.opacity(0.5) : theme.mutedBackground.opacity(0.8)
        case .outline, .ghost:
            return isHovering ? theme.mutedBackground : .clear
        case .destructive:
            return isHovering ? theme.destructive.opacity(0.85) : theme.destructive
        }
    }

    private var labelColor: Color {
        guard !isDisabled else { return theme.disabledForeground }
        if let override = labelColorOverride { return override }
        switch variant {
        case .default, .destructive:
            return .white
        case .secondary, .outline, .ghost:
            return theme.foreground
        }
    }

    private var strokeColor: Color {
        guard variant == .outline else { return .clear }
        return isDisabled ? theme.border.opacity(0.4) : theme.border
    }

    // MARK: - Body

    var body: some View {
        Button(action: action) {
            HStack(spacing: iconSpacing) {
                if let icon = leadingIcon {
                    Image(systemName: icon)
                        .font(.system(size: fontSize - 1, weight: .medium))
                }

                Text(label)
                    .font(.system(size: fontSize, weight: .medium))
                    .foregroundColor(labelColor)

                if let icon = trailingIcon {
                    Image(systemName: icon)
                        .font(.system(size: fontSize - 1, weight: .medium))
                        .foregroundColor(labelColor)
                }

                if let shortcut = keyboardShortcut {
                    Spacer().frame(width: 3)

                    let systemIcons = ["return", "command", "shift", "control", "option", "escape", "delete.left"]
                    let isSystemIcon = systemIcons.contains(shortcut)

                    Group {
                        if isSystemIcon {
                            Image(systemName: shortcut)
                        } else {
                            Text(shortcut.lowercased()).opacity(0.5)
                        }
                    }
                    .font(.system(size: fontSize - 3, weight: .semibold))
                    .frame(minWidth: shortcutSize, minHeight: shortcutSize)
                    .padding(.horizontal, isSystemIcon || shortcut.count == 1 ? 0 : 4)
                    .background(labelColor.opacity(variant == .default || variant == .destructive ? 0.15 : 0.07))
                    .cornerRadius(4)
                    .foregroundColor(labelColor)
                }
            }
            .padding(.horizontal, hPadding)
            .padding(.vertical, vPadding)
            .background(backgroundColor)
            .overlay {
                ConditionallyConcentricRectangle(cornerRadius: cornerRadius)
                    .stroke(strokeColor, lineWidth: 1)
            }
            .clipShape(ConditionallyConcentricRectangle(cornerRadius: cornerRadius))
            .animation(.easeInOut(duration: 0.12), value: isHovering)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Preview

#Preview {
    VStack(alignment: .center, spacing: 24) {
        OraButton(label: "Primary", keyboardShortcut: "return", action: {})
        OraButton(label: "Secondary", variant: .secondary, keyboardShortcut: "return", action: {})
        OraButton(label: "Outline", variant: .outline, keyboardShortcut: "return", action: {})
        OraButton(label: "Ghost", variant: .ghost, keyboardShortcut: "return", action: {})
        OraButton(label: "Destructive", variant: .destructive, keyboardShortcut: "return", action: {})
    }
    .padding(40)
    .frame(width: 300)
    .withTheme()
}
