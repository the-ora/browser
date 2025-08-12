import AppKit
import SwiftData
import SwiftUI

struct FavTabItem: View {
    let tab: Tab
    let isSelected: Bool
    let isDragging: Bool
    let onTap: () -> Void
    let onFavoriteToggle: () -> Void
    let onClose: () -> Void
    let onMoveToContainer: (TabContainer) -> Void

    @Environment(\.theme) private var theme
    @Query var containers: [TabContainer]
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var historyManager: HistoryManager
    @EnvironmentObject var downloadManager: DownloadManager

    @State private var isHovering = false

    var body: some View {
        ZStack {
            if let favicon = tab.favicon, tab.isWebViewReady {
                AsyncImage(
                    url: favicon
                ) { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                } placeholder: {
                    LocalFavIcon(
                        faviconLocalFile: tab.faviconLocalFile,
                        textColor: Color(.white)
                    )
                }
            } else {
                LocalFavIcon(
                    faviconLocalFile: tab.faviconLocalFile,
                    textColor: Color(.white)
                )
            }
        }
        .onTapGesture {
            onTap()
            if !tab.isWebViewReady {
                tab
                    .restoreTransientState(
                        historyManger: historyManager,
                        downloadManager: downloadManager,
                        tabManager: tabManager
                    )
            }
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
        .foregroundColor(theme.foreground)
        .frame(height: 48)
        .frame(maxWidth: .infinity)
        .opacity(isDragging ? 0.0 : 1.0)
        .background(backgroundColor)
        .cornerRadius(10)
        .overlay(
            isDragging
                ? RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    theme.invertedSolidWindowBackgroundColor.opacity(0.25),
                    style: StrokeStyle(lineWidth: 1, dash: [5, 5])
                )
                : isSelected
                ? RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    theme.invertedSolidWindowBackgroundColor,
                    lineWidth: 1
                )
                : nil
        )
        .onTapGesture {
            onTap()
            if !tab.isWebViewReady {
                tab
                    .restoreTransientState(
                        historyManger: historyManager,
                        downloadManager: downloadManager,
                        tabManager: tabManager
                    )
            }
        }
        .onHover { isHovering = $0 }
        .contextMenu {
            Button(action: onFavoriteToggle) {
                Label("Remove from Favorites", systemImage: "star.slash")
            }

            // Divider()

            //      Menu("Move to Container") {
            //        ForEach(containers) { container in
            //            if container.id != tabManager.activeContainer?.id {
            //            Button(action: { onMoveToContainer(container) }) {
            //              Label(container.title, systemImage: container.icon)
            //            }
            //          }
            //        }
            //      }

            Divider()

            Button(role: .destructive, action: onClose) {
                Label("Close Tab", systemImage: "xmark")
            }
        }
    }

    private var backgroundColor: Color {
        if isDragging {
            return theme.activeTabBackground.opacity(0.1)
        } else if isSelected {
            return theme.invertedSolidWindowBackgroundColor.opacity(0.3)
        } else if isHovering {
            return theme.activeTabBackground.opacity(0.3)
        }
        return theme.mutedBackground
    }
}
