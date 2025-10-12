import AppKit
import SwiftData
import SwiftUI

struct SidebarView: View {
    @Environment(\.theme) private var theme
    @Environment(\.window) var window: NSWindow?
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var historyManager: HistoryManager
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var privacyMode: PrivacyMode
    @EnvironmentObject var media: MediaController
    @EnvironmentObject var sidebarManager: SidebarManager

    @Query var containers: [TabContainer]
    @Query(filter: nil, sort: [.init(\History.lastAccessedAt, order: .reverse)])
    var histories: [History]

    private let columns = Array(repeating: GridItem(spacing: 10), count: 3)

    @State private var isHoveringSidebarToggle = false

    private var shouldShowMediaWidget: Bool {
        let activeId = tabManager.activeTab?.id
        let others = media.visibleSessions.filter { session in
            guard let activeId else { return true }
            return session.tabID != activeId
        }
        return media.isVisible && !others.isEmpty
    }

    private var selectedContainerIndex: Binding<Int> {
        Binding(
            get: {
                guard let activeContainer = tabManager.activeContainer else {
                    return 0
                }
                return containers.firstIndex { $0.id == activeContainer.id } ?? 0
            },
            set: { newIndex in
                guard newIndex >= 0, newIndex < containers.count else { return }
                tabManager.activateContainer(containers[newIndex])
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if sidebarManager.sidebarPosition != .secondary {
                WindowControls(isFullscreen: appState.isFullscreen)
            }

            NSPageView(
                selection: selectedContainerIndex,
                pageObjects: containers,
                idKeyPath: \.name
            ) { container in
                ContainerView(
                    container: container,
                    selectedContainer: container.name,
                    containers: containers
                )
                .padding(.horizontal, 10)
                .environmentObject(tabManager)
                .environmentObject(historyManager)
                .environmentObject(downloadManager)
                .environmentObject(appState)
                .environmentObject(privacyMode)
            }

            if shouldShowMediaWidget {
                GlobalMediaPlayer()
                    .environmentObject(media)
                    .padding(.horizontal, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if !privacyMode.isPrivate {
                HStack {
                    DownloadsWidget()
                    Spacer()
                    ContainerSwitcher(onContainerSelected: onContainerSelected)
                    Spacer()
                    NewContainerButton()
                }
                .padding(.horizontal, 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(
            EdgeInsets(
                top: 10,
                leading: 0,
                bottom: 10,
                trailing: 0
            )
        )
        .onTapGesture(count: 2) {
            toggleMaximizeWindow()
        }
    }

    private func onContainerSelected(container: TabContainer) {
        withAnimation(.easeOut(duration: 0.1)) {
            tabManager.activateContainer(container)
        }
    }

    private func toggleMaximizeWindow() {
        window?.toggleMaximized()
    }
}

struct SidebarButton: View {
    var position: SidebarPosition
    var toggleSidebar: (() -> Void)?
    @Binding var isHovering: Bool
    var theme: Theme

    var body: some View {
        let iconName = position == .secondary ? "sidebar.right" : "sidebar.left"

        Button(action: {
            toggleSidebar?()
        }) {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 30, height: 30)
                .background(
                    ConditionallyConcentricRectangle(cornerRadius: 6)
                        .fill(isHovering ? theme.foreground.opacity(0.1) : Color.clear)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 8)
        .onHover { hovering in
            isHovering = hovering
        }
        .oraShortcutHelp("Toggle Sidebar", for: KeyboardShortcuts.App.toggleSidebar)
    }
}
