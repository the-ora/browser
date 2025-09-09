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
    @State private var isAudioButtonHovering = false
    @State private var showAudioTooltip = false
    @State private var audioHoverWorkItem: DispatchWorkItem?
    @State private var muteToggleScale: CGFloat = 1.0

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
            // Audio indicator overlay button
            if tab.isMediaActive {
                VStack {
                    HStack {
                        ZStack(alignment: .topLeading) {
                            Button(action: {
                                withAnimation(.easeOut(duration: 0.15).repeatCount(1, autoreverses: true)) {
                                    muteToggleScale = 1.2
                                }
                                tab.toggleMute()
                            }) {
                                Image(systemName: tab.isMuted ? "speaker.slash.fill" : "speaker.wave.3.fill")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .padding(6)
                                    .frame(width: 24, height: 24)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(isAudioButtonHovering ? theme.activeTabBackground
                                                .opacity(0.25) : .clear
                                            )
                                    )
                                    .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    .scaleEffect(muteToggleScale)
                                    .animation(.spring(duration: 0.4), value: muteToggleScale)
                                    .animation(.spring(duration: 0.4), value: tab.isMuted)
                            }
                            .buttonStyle(.plain)

                            if showAudioTooltip {
                                Text(tab.isMuted ? "Unmute this tab" : "Mute this tab")
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(theme.activeTabBackground.opacity(0.95))
                                    )
                                    .foregroundColor(.white)
                                    .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 2)
                                    .offset(y: -26)
                                    .zIndex(10)
                                    .allowsHitTesting(false)
                                    .animation(.easeInOut(duration: 0.12), value: showAudioTooltip)
                                    .animation(.spring(duration: 0.4), value: tab.isMuted)
                                    .transition(.opacity.combined(with: .scale))
                            }
                        }
                        .zIndex(1)
                        .onHover { hovering in
                            isAudioButtonHovering = hovering
                            audioHoverWorkItem?.cancel()
                            if hovering {
                                let work = DispatchWorkItem { self.showAudioTooltip = true }
                                audioHoverWorkItem = work
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
                            } else {
                                showAudioTooltip = false
                                audioHoverWorkItem = nil
                            }
                        }
                        Spacer()
                    }
                    Spacer()
                }
                .padding(4)
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
