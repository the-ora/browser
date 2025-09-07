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

    var body: some View {
        HStack {
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
        }
        .frame(width: 16, height: 16)
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
    let onMoveToContainer: (TabContainer) -> Void
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var historyManager: HistoryManager
    @EnvironmentObject var downloadManager: DownloadManager
    let availableContainers: [TabContainer]

    @Environment(\.theme) private var theme
    @State private var isHovering = false

    var body: some View {
        HStack {
            FavIcon(
                isWebViewReady: tab.isWebViewReady,
                favicon: tab.favicon,
                faviconLocalFile: tab.faviconLocalFile,
                textColor: textColor
            )
            tabTitle
            Spacer()
            actionButton
        }
        .onAppear {
            if tabManager.isActive(tab) {
                tab
                    .restoreTransientState(
                        historyManger: historyManager,
                        downloadManager: downloadManager,
                        tabManager: tabManager
                    )
            }
        }
        .onTapGesture {
            onTap()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                if !tab.isWebViewReady {
                    tab
                        .restoreTransientState(
                            historyManger: historyManager,
                            downloadManager: downloadManager,
                            tabManager: tabManager
                        )
                }
            }
        }
        .padding(8)
        .opacity(isDragging ? 0.0 : 1.0)
        .background(backgroundColor)
        .cornerRadius(10)
        .overlay(
            isDragging ?
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    theme.invertedSolidWindowBackgroundColor.opacity(0.25),
                    style: StrokeStyle(lineWidth: 1, dash: [5, 5])
                )
                : nil
        )
        .onTapGesture {
            onTap()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                if !tab.isWebViewReady {
                    tab
                        .restoreTransientState(
                            historyManger: historyManager,
                            downloadManager: downloadManager,
                            tabManager: tabManager
                        )
                }
            }
        }
//        .onTapGesture(perform: onTap)
        .onHover { isHovering = $0 }
        .contextMenu { contextMenuItems }
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

        Divider()

        Menu("Move to Container") {
            ForEach(availableContainers) { container in
                if tab.container.id != tabManager.activeContainer?.id {
                    Button(action: { onMoveToContainer(tab.container) }) {
                        Label {
                            Text(container.name)
                        } icon: {
                            Text(container.emoji) // This is where you show the emoji
                        }
                    }
                }
            }
        }

        Divider()

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
