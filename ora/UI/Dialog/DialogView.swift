import SwiftUI

// MARK: - Confirm Dialog

struct ConfirmDialogView: View {
    let title: String
    var message: String?
    var icon: OraIconType?
    var iconColor: Color?
    var iconImage: Image?
    var confirmLabel: String = "Confirm"
    var confirmVariant: OraButtonVariant = .default
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        // Outer frame
        VStack(alignment: .leading, spacing: 0) {
            // Inner content
            VStack(alignment: .leading, spacing: 0) {
                if let iconImage {
                    Group {
                        iconImage
                            .resizable()
                            .scaledToFit()
                            .frame(width: 42, height: 42)
                    }
                    .padding(2)
                    .background(Color.white)
                    .cornerRadius(12)
                    .padding(.bottom, 16)
                } else if let icon {
                    OraIcons(icon: icon, size: .custom(42), color: iconColor ?? theme.mutedForeground)
                        .padding(.bottom, 16)
                }

                Text(title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(theme.foreground)

                if let message {
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundColor(theme.mutedForeground)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }

                Spacer()

                HStack {
                    OraButton(label: "Cancel", variant: .secondary, keyboardShortcut: "esc", action: onCancel)
                    Spacer()
                    OraButton(label: confirmLabel, variant: confirmVariant, keyboardShortcut: "return") {
                        onConfirm()
                        onCancel()
                    }
                }
            }
            .frame(width: ContainerConstants.UI.minDialogWidth, height: ContainerConstants.UI.minDialogHeight)
            .padding(12)
            .background(theme.popoverMutedBackground)
            .cornerRadius(11)
            .overlay {
                ConditionallyConcentricRectangle(cornerRadius: 11)
                    .stroke(theme.border, lineWidth: 0.5)
            }
        }
        .padding(3)
        .background(theme.popoverBackground)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
    }
}

// MARK: - View extension

extension View {
    @ViewBuilder
    func dialogs(manager: DialogManager) -> some View {
        self.frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                DialogsOverlay(dialogs: manager.dialogs) { id in
                    manager.dismiss(id: id)
                }
            }
    }
}

private struct DialogsOverlay: View {
    let dialogs: [Dialog]
    let dismiss: (String) -> Void

    private static let transition: AnyTransition = .asymmetric(
        insertion: .offset(y: -16).combined(with: .scale(scale: 0.96)).combined(with: .opacity),
        removal: .offset(y: -16).combined(with: .scale(scale: 0.96)).combined(with: .opacity)
    )

    var body: some View {
        ZStack {
            if let dialog = dialogs.last {
                // Backdrop
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { dismiss(dialog.id) }
                    .transition(.opacity)

                // Dialog content — wrapped so SwiftUI sees a concrete type
                DialogContentView(content: dialog.content)
                    .id(dialog.id)
                    .transition(Self.transition)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.82), value: dialogs.map(\.id))
    }
}

private struct DialogContentView: View {
    let content: AnyView
    var body: some View { content }
}
