import AppKit
import Inject
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
    @EnvironmentObject var toolbarManager: ToolbarManager

    @Query var containers: [TabContainer]
    @Query(filter: nil, sort: [.init(\History.lastAccessedAt, order: .reverse)])
    var histories: [History]

    private let columns = Array(repeating: GridItem(spacing: 10), count: 3)

    @ObserveInjection var inject

    @State private var isHoveringSidebarToggle = false

    /// Downloads transition state
    @State private var dragOffset: CGFloat = 0

    private var isShowingDownloads: Bool {
        downloadManager.isShowingDownloadsHistory
    }

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
        GeometryReader { geo in
            let width = geo.size.width
            let progress = transitionProgress(for: width)

            ZStack(alignment: .leading) {
                // Spaces content - pushes back and blurs out when downloads is shown
                spacesContent
                    .frame(width: width)
                    .offset(x: width * 0.12 * progress)
                    .scaleEffect(CGFloat(1.0) - 0.06 * progress, anchor: .center)
                    .opacity(CGFloat(1.0) - 0.5 * progress)
                    .allowsHitTesting(progress < 0.5)

                // Downloads history - slides in from leading edge
                DownloadsHistoryView()
                    .frame(width: width)
                    .offset(x: -width + width * progress)
                    .shadow(color: .black.opacity(0.08 * Double(progress)), radius: 8, x: 4, y: 0)
                    .allowsHitTesting(progress >= 0.5)
            }
            .clipped()
            // Swipe-to-dismiss gesture on the whole sidebar when downloads is showing
            .simultaneousGesture(downloadsNavigationGesture(width: width))
        }
        .enableInjection()
    }

    /// Computes transition progress (0 = spaces visible, 1 = downloads visible)
    /// incorporating both the boolean state and any interactive drag offset.
    private func transitionProgress(for width: CGFloat) -> CGFloat {
        let base: CGFloat = isShowingDownloads ? 1.0 : 0.0
        // dragOffset > 0 means dragging right (toward spaces), < 0 means dragging left (toward downloads)
        let dragContribution = -dragOffset / max(width, 1)
        return min(1, max(0, base + dragContribution))
    }

    // MARK: - Gesture

    /// Handles swipe-to-dismiss (right swipe when in downloads) and
    /// swipe-to-enter (left swipe from first container).
    private func downloadsNavigationGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 30)
            .onChanged { value in
                if isShowingDownloads {
                    // Swipe right to dismiss downloads
                    if value.translation.width > 0 {
                        dragOffset = value.translation.width
                    }
                } else if selectedContainerIndex.wrappedValue == 0 {
                    // Swipe left from first container to show downloads
                    if value.translation.width < 0 {
                        dragOffset = value.translation.width
                    }
                }
            }
            .onEnded { value in
                let threshold = width * 0.25
                if isShowingDownloads {
                    if value.translation.width > threshold
                        || value.predictedEndTranslation.width > threshold * 2
                    {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
                            downloadManager.isShowingDownloadsHistory = false
                            dragOffset = 0
                        }
                    } else {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                            dragOffset = 0
                        }
                    }
                } else if selectedContainerIndex.wrappedValue == 0 {
                    if -value.translation.width > threshold
                        || -value.predictedEndTranslation.width > threshold * 2
                    {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
                            downloadManager.isShowingDownloadsHistory = true
                            dragOffset = 0
                        }
                    } else {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                            dragOffset = 0
                        }
                    }
                } else {
                    dragOffset = 0
                }
            }
    }

    // MARK: - Spaces Content

    private var spacesContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if sidebarManager.sidebarPosition == .secondary, !toolbarManager.isToolbarHidden {
                Spacer().frame(height: 8)
            } else {
                SidebarHeader()
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
                .environmentObject(toolbarManager)
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
                top: 4,
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
