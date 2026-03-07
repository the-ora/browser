import SwiftUI

struct PasswordAutofillOverlayView: View {
    @Environment(\.theme) private var theme

    let overlay: PasswordAutofillOverlayState
    let tab: Tab

    private let overlayWidth: CGFloat = 320

    var body: some View {
        content
            .frame(width: overlayWidth)
            .background(theme.solidWindowBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(theme.foreground.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 8)
            .offset(
                x: max(12, overlay.focus.rect.cgRect.minX),
                y: overlay.focus.rect.cgRect.maxY + 10
            )
            .allowsHitTesting(true)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(overlay.focus.action == .createAccount ? "Strong Password" : "Saved Passwords")
                        .font(.headline)
                    Text(overlay.focus.hostname)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    tab.passwordCoordinator?.dismissOverlay()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .padding(6)
                        .background(theme.background.opacity(0.65))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            if let generatedPassword = overlay.generatedPassword {
                Button {
                    tab.passwordCoordinator?.fillGeneratedPassword(for: overlay)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Use Strong Password")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.foreground)
                        Text(generatedPassword)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(red: 1.0, green: 0.96, blue: 0.82))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            if overlay.matchingEntries.isEmpty {
                Text("No saved credentials for this site.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(overlay.matchingEntries.prefix(4), id: \.id) { entry in
                    Button {
                        tab.passwordCoordinator?.autofill(entry, for: overlay)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "key.horizontal.fill")
                                .foregroundStyle(theme.foreground)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.displayUsername)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(theme.foreground)
                                Text(entry.host)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.background.opacity(0.45))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            Button("Manage Passwords") {
                tab.passwordCoordinator?.openPasswordsSettings()
            }
            .buttonStyle(.plain)
            .font(.caption.weight(.medium))
        }
        .padding(14)
    }
}
