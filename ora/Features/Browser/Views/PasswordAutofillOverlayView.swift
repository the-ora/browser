import AppKit
import SwiftUI

struct PasswordAutofillOverlayView: View {
    let overlay: PasswordAutofillOverlayState
    let tab: Tab

    private let overlayWidth: CGFloat = 320
    private let cornerRadius: CGFloat = 18
    @State private var isManagePasswordsHovered = false

    var body: some View {
        content
            .frame(width: overlayWidth)
            .background {
                ZStack {
                    BlurEffectView(material: .popover, blendingMode: .withinWindow)
                    Color(nsColor: .windowBackgroundColor).opacity(0.5)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.7), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 8)
            .offset(
                x: max(12, overlay.focus.rect.cgRect.minX),
                y: overlay.focus.rect.cgRect.maxY + 10
            )
            .allowsHitTesting(true)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 4) {
            if overlay.suggestions.isEmpty {
                Text("No autofill suggestions available.")
                    .font(.caption)
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            } else {
                ForEach(Array(overlay.suggestions.enumerated()), id: \.element.id) { index, suggestion in
                    PasswordSuggestionButton(
                        host: suggestion.host,
                        isSelected: overlay.selectedSuggestionIndex == index,
                        accessorySymbolName: suggestion.accessorySymbolName
                    ) {
                        activate(suggestion)
                    } onHoverChanged: { isHovering in
                        if isHovering {
                            tab.passwordCoordinator?.updateSelection(to: index, for: overlay)
                        }
                    } content: {
                        suggestionContent(for: suggestion)
                    }
                }
            }
            VStack {}.frame(height: 2)
            Divider()

            Button("Manage Passwords") {
                tab.passwordCoordinator?.openPasswordsManager()
            }
            .buttonStyle(.plain)
            .font(.caption.weight(.medium))
            .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .labelColor).opacity(isManagePasswordsHovered ? 0.06 : 0))
            )
            .onHover { isHovering in
                isManagePasswordsHovered = isHovering
            }
        }
        .padding(8)
    }

    @ViewBuilder
    private func suggestionContent(for suggestion: PasswordAutofillSuggestion) -> some View {
        switch suggestion {
        case let .generatedPassword(_, password):
            VStack(alignment: .leading, spacing: 3) {
                Text("Use Strong Password")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(nsColor: .labelColor))
                Text(password)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    .lineLimit(1)
            }
        case let .savedCredential(entry):
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayUsername)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(nsColor: .labelColor))
                Text(entry.host)
                    .font(.caption)
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            }
        case let .email(suggestion):
            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.email)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(nsColor: .labelColor))
                Text("Use email from \(suggestion.host)")
                    .font(.caption)
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            }
        }
    }

    private func activate(_ suggestion: PasswordAutofillSuggestion) {
        switch suggestion {
        case .generatedPassword:
            tab.passwordCoordinator?.fillGeneratedPassword(for: overlay)
        case let .savedCredential(entry):
            tab.passwordCoordinator?.autofill(entry, for: overlay)
        case let .email(emailSuggestion):
            tab.passwordCoordinator?.fillEmailSuggestion(emailSuggestion, for: overlay)
        }
    }
}

private extension PasswordAutofillSuggestion {
    var accessorySymbolName: String {
        switch self {
        case .generatedPassword:
            return "key.horizontal.fill"
        case .savedCredential:
            return "touchid"
        case .email:
            return "at"
        }
    }
}

struct PasswordAutofillTriggerView: View {
    let overlay: PasswordAutofillOverlayState
    let tab: Tab

    private let buttonSize: CGFloat = 24
    private let fieldInset: CGFloat = 9
    private let cornerRadius: CGFloat = 6

    @State private var isHovering = false

    var body: some View {
        GeometryReader { proxy in
            Button {
                tab.passwordCoordinator?.presentTriggerOverlay()
            } label: {
                Image(systemName: "key.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: "#4A4A4A"))
                    .frame(width: buttonSize, height: buttonSize)
                    .background {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                Color(hex: "#EFEFEF")
                                    .opacity(isHovering ? 1 : 0.7)
                            )
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 0.8)
                            .fill(Color.white.opacity(isHovering ? 0.08 : 0))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
            .buttonStyle(.plain)
            .onHover { isHovering = $0 }
            .offset(
                x: triggerX(in: proxy.size),
                y: triggerY(in: proxy.size)
            )
        }
    }

    private func triggerX(in size: CGSize) -> CGFloat {
        let rect = overlay.focus.rect.cgRect
        let preferred = rect.maxX - buttonSize - fieldInset
        return min(max(8, preferred), max(8, size.width - buttonSize - 8))
    }

    private func triggerY(in size: CGSize) -> CGFloat {
        let rect = overlay.focus.rect.cgRect
        let preferred = rect.midY - (buttonSize / 2)
        return min(max(8, preferred), max(8, size.height - buttonSize - 8))
    }
}

private struct PasswordSuggestionButton<Content: View>: View {
    let host: String
    let isSelected: Bool
    let accessorySymbolName: String
    let action: () -> Void
    let onHoverChanged: (Bool) -> Void
    @ViewBuilder let content: () -> Content

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                SiteFaviconView(host: host, size: 18)
                content()
                Spacer(minLength: 0)
                Image(systemName: accessorySymbolName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    .opacity(isHovering || isSelected ? 1 : 0.3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor).opacity(isHovering || isSelected ? 1 : 0))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovering in
            self.isHovering = isHovering
            onHoverChanged(isHovering)
        }
    }
}

struct SiteFaviconView: View {
    let host: String
    var size: CGFloat = 24
    var cornerRadius: CGFloat = 6

    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(2)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.white)
                    )
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(nsColor: .clear))
                    .overlay {
                        Image(systemName: "globe")
                            .resizable()
                            .scaledToFit()
                            .padding(2)
                            .frame(width: size, height: size)
                            .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onAppear(perform: loadFavicon)
        .onChange(of: host) {
            loadFavicon()
        }
    }

    private func loadFavicon() {
        let normalizedHost = PasswordManagerService.normalizeHost(host)
        guard !normalizedHost.isEmpty else {
            image = nil
            return
        }

        FaviconService.shared.fetchFaviconSync(for: "https://\(normalizedHost)") { favicon in
            DispatchQueue.main.async {
                self.image = favicon
            }
        }
    }
}
