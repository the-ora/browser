import AppKit
import SwiftUI

struct LocalFavIcon: View {
    let faviconLocalFile: URL?
    let textColor: Color

    @State private var image: NSImage?

    var body: some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .cornerRadius(4)
                .grayscale(1.0)
        } else {
            Image(systemName: "globe")
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .foregroundColor(textColor)
                .onAppear(perform: loadFavicon)
        }
    }

    private func loadFavicon() {
        guard let localURL = faviconLocalFile,
              FileManager.default.fileExists(atPath: localURL.path) else { return }

        // Loading may block briefly, so you can even do it async if needed
        DispatchQueue.global(qos: .utility).async {
            if let loadedImage = NSImage(contentsOfFile: localURL.path) {
                DispatchQueue.main.async {
                    self.image = loadedImage
                }
            }
        }
    }
}

struct FavIcon: View {
    let isWebViewReady: Bool
    let favicon: URL?
    let faviconLocalFile: URL?
    let textColor: Color
    var isPlayingMedia: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            if let favicon, isWebViewReady {
                AsyncImage(
                    url: favicon
                ) { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                } placeholder: {
                    LocalFavIcon(
                        faviconLocalFile: faviconLocalFile,
                        textColor: textColor
                    )
                }
            } else {
                LocalFavIcon(
                    faviconLocalFile: faviconLocalFile,
                    textColor: textColor
                )
            }

            if isPlayingMedia {
                Image(systemName: "speaker.wave.2.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 8, height: 8)
                    .foregroundColor(textColor.opacity(0.8))
            }
        }
        .frame(width: isPlayingMedia ? 28 : 16, height: 16)
    }
}

struct TabItem: View {
    let tab: Tab
    let isSelected: Bool
    let isDragging: Bool
    let onTap: () -> Void
    let onPinToggle: () -> Void
    let onFavoriteToggle: () -> Void
    let onClose: () -> Void
    let onDuplicate: () -> Void
    let onMoveToContainer: (TabContainer) -> Void
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var historyManager: HistoryManager
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var privacyMode: PrivacyMode
    let availableContainers: [TabContainer]

    @Environment(\.theme) private var theme
    @State private var isHovering = false

    var body: some View {
        HStack {
            FavIcon(
                isWebViewReady: tab.isWebViewReady,
                favicon: tab.favicon,
                faviconLocalFile: tab.faviconLocalFile,
                textColor: textColor,
                isPlayingMedia: tab.isPlayingMedia
            )
            tabTitle
            Spacer()
            actionButton
        }
        .onAppear {
            if tabManager.isActive(tab) {
                tab
                    .restoreTransientState(
                        historyManager: historyManager,
                        downloadManager: downloadManager,
                        tabManager: tabManager,
                        isPrivate: privacyMode.isPrivate
                    )
            }
        }
        .onTapGesture {
            onTap()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                if !tab.isWebViewReady {
                    tab
                        .restoreTransientState(
                            historyManager: historyManager,
                            downloadManager: downloadManager,
                            tabManager: tabManager,
                            isPrivate: privacyMode.isPrivate
                        )
                }
            }
        }
        .padding(8)
        .opacity(isDragging ? 0.0 : 1.0)
        .background(backgroundColor, in: .rect(cornerRadius: 10))
        .overlay(
            isDragging ?
                ConditionallyConcentricRectangle(cornerRadius: 10)
                .stroke(
                    theme.invertedSolidWindowBackgroundColor.opacity(0.25),
                    style: StrokeStyle(lineWidth: 1, dash: [5, 5])
                )
                : nil
        )
        .contentShape(ConditionallyConcentricRectangle(cornerRadius: 10))
        .onTapGesture {
            onTap()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                if !tab.isWebViewReady {
                    tab
                        .restoreTransientState(
                            historyManager: historyManager,
                            downloadManager: downloadManager,
                            tabManager: tabManager,
                            isPrivate: privacyMode.isPrivate
                        )
                }
            }
        }
        .onHover { isHovering = $0 }
        .contextMenu { contextMenuItems }
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isDragging)
        .geometryGroup()
    }

    private var tabTitle: some View {
        Text(tab.title)
            .font(.system(size: 13))
            .foregroundColor(textColor)
            .lineLimit(1)
    }

    private var backgroundColor: Color {
        if isDragging {
            return theme.activeTabBackground.opacity(0.1)
        } else if isSelected {
            return theme.activeTabBackground
        } else if isHovering {
            return theme.activeTabBackground.opacity(0.3)
        }
        return .clear
    }

    private var textColor: Color {
        isSelected ? .white : theme.foreground
    }

    @ViewBuilder
    private var actionButton: some View {
        if isHovering, tab.type == .pinned, !tab.isWebViewReady {
            ActionButton(icon: "pin.slash", color: textColor, action: onPinToggle).help("Unpin Tab")
        } else if isHovering {
            ActionButton(icon: "xmark", color: textColor, action: onClose).help("Close Tab")
        }
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        Button(action: onPinToggle) {
            Label(
                tab.type == .pinned ? "Unpin Tab" : "Pin Tab",
                systemImage: tab.type == .pinned ? "pin.slash" : "pin"
            )
        }

        Button(action: onFavoriteToggle) {
            Label(
                tab.type == .fav ? "Remove from Favorites" : "Add to Favorites",
                systemImage: tab.type == .fav ? "star.slash" : "star"
            )
        }

        Button(action: onDuplicate) {
            Label("Duplicate Tab", systemImage: "doc.on.doc")
        }
        .disabled(!tab.isWebViewReady)

        Divider()

        if availableContainers.count > 1 {
            Divider()

            Menu("Move to Container") {
                ForEach(availableContainers) { container in
                    if tab.container.id != container.id {
                        Button(action: { onMoveToContainer(container) }) {
                            Text(container.emoji.isEmpty ? container.name : "\(container.emoji) \(container.name)")
                        }
                    }
                }
            }

            Divider()
        }

        Button(role: .destructive, action: onClose) {
            Label("Close Tab", systemImage: "xmark")
        }
    }
}

struct ActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .frame(width: 12, height: 12)
                .foregroundColor(color)
                .fontWeight(.semibold)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
