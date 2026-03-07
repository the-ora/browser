import AppKit
import SwiftUI

struct PasswordAutofillOverlayView: View {
    let overlay: PasswordAutofillOverlayState
    let tab: Tab

    private let overlayWidth: CGFloat = 320
    private let cornerRadius: CGFloat = 18

    @State private var selectedSuggestionIndex = 0

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
            .background {
                KeyCaptureView(onKeyDownResult: handleKeyDown)
                    .allowsHitTesting(false)
            }
            .onAppear(perform: resetSelection)
            .onChange(of: overlay) { _, _ in
                resetSelection()
            }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let generatedPassword = overlay.generatedPassword {
                PasswordSuggestionButton(
                    host: overlay.focus.hostname,
                    isSelected: selectedSuggestionIndex == 0
                ) {
                    tab.passwordCoordinator?.fillGeneratedPassword(for: overlay)
                } onHoverChanged: { isHovering in
                    if isHovering {
                        selectedSuggestionIndex = 0
                    }
                } content: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Use Strong Password")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color(nsColor: .labelColor))
                        Text(generatedPassword)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                            .lineLimit(1)
                    }
                }
            }

            if overlay.matchingEntries.isEmpty {
                Text("No saved credentials for this site.")
                    .font(.caption)
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            } else {
                ForEach(Array(visibleEntries.enumerated()), id: \.element.id) { index, entry in
                    PasswordSuggestionButton(
                        host: entry.host,
                        isSelected: selectedSuggestionIndex == savedEntrySelectionIndex(for: index)
                    ) {
                        tab.passwordCoordinator?.autofill(entry, for: overlay)
                    } onHoverChanged: { isHovering in
                        if isHovering {
                            selectedSuggestionIndex = savedEntrySelectionIndex(for: index)
                        }
                    } content: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.displayUsername)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color(nsColor: .labelColor))
                            Text(entry.host)
                                .font(.caption)
                                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                        }
                    }
                }
            }
            VStack {}.frame(height: 2)
            Divider()

            Button("Manage Passwords") {
                tab.passwordCoordinator?.openPasswordsSettings()
            }
            .buttonStyle(.plain)
            .font(.caption.weight(.medium))
            .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            .padding(.vertical, 4)
        }
        .padding(8)
    }

    private var visibleEntries: [SavedPasswordSummary] {
        Array(overlay.matchingEntries.prefix(4))
    }

    private var suggestionCount: Int {
        visibleEntries.count + (overlay.generatedPassword == nil ? 0 : 1)
    }

    private func savedEntrySelectionIndex(for entryIndex: Int) -> Int {
        entryIndex + (overlay.generatedPassword == nil ? 0 : 1)
    }

    private func resetSelection() {
        selectedSuggestionIndex = suggestionCount > 0 ? 0 : -1
    }

    private func moveSelection(by delta: Int) {
        guard suggestionCount > 0 else { return }

        let nextIndex = selectedSuggestionIndex + delta
        selectedSuggestionIndex = min(max(nextIndex, 0), suggestionCount - 1)
    }

    private func activateSelection() {
        guard suggestionCount > 0 else { return }

        if overlay.generatedPassword != nil, selectedSuggestionIndex == 0 {
            tab.passwordCoordinator?.fillGeneratedPassword(for: overlay)
            return
        }

        let entryIndex = selectedSuggestionIndex - (overlay.generatedPassword == nil ? 0 : 1)
        guard visibleEntries.indices.contains(entryIndex) else { return }
        tab.passwordCoordinator?.autofill(visibleEntries[entryIndex], for: overlay)
    }

    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        switch event.keyCode {
        case 125:
            moveSelection(by: 1)
            return nil
        case 126:
            moveSelection(by: -1)
            return nil
        case 36, 76:
            activateSelection()
            return nil
        case 53:
            tab.passwordCoordinator?.dismissOverlay()
            return nil
        default:
            return event
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
                Image(systemName: "touchid")
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
