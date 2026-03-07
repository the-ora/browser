import Combine
import SwiftUI
import WebKit

struct TabSnapshot {
    let image: NSImage
    let url: String
}

struct FloatingTabSwitcher: View {
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var keyModifierListener: KeyModifierListener
    @Environment(\.theme) var theme

    @FocusState private var focusedTab: Tab.ID?
    @State private var tabSnapshots: [Tab: TabSnapshot] = [:]
    @State private var isLoadingSnapshots = false

    // MARK: - Constants

    private enum Constants {
        static let previewWidth: CGFloat = 200
        static let previewHeight: CGFloat = 125
        static let maxTabsToShow = 5
        static let cornerRadius: CGFloat = 10
        static let containerCornerRadius: CGFloat = 32
    }

    var body: some View {
        ZStack {
            backgroundOverlay
            tabSwitcherContainer
        }
        .onExitCommand {
            closeFloatingTabSwitch()
        }
        .onAppear {
            preloadSnapshots()
            if !recentTabs.isEmpty {
                let to = recentTabs.count == 1 ? 0 : 1
                focusedTab = recentTabs[to].id
            }
        }
        .onChange(of: appState.isFloatingTabSwitchVisible) { _, isVisible in
            if isVisible {
                preloadSnapshots()
                if !recentTabs.isEmpty {
                    let to = recentTabs.count == 1 ? 0 : 1
                    focusedTab = recentTabs[to].id
                }
            }
        }
        .onChange(of: keyModifierListener.modifierFlags) { _, newFlags in
            handleModifierChange(newFlags)
        }
    }

    // MARK: - View Components

    private var backgroundOverlay: some View {
        Color.black.opacity(0.3)
            .ignoresSafeArea()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.3), value: appState.isFloatingTabSwitchVisible)
            .onTapGesture {
                closeFloatingTabSwitch()
            }
    }

    private var tabSwitcherContainer: some View {
        HStack(spacing: 12) {
            if tabManager.activeContainer != nil {
                if recentTabs.isEmpty {
                    ZStack {
                        RoundedRectangle(cornerRadius: Constants.cornerRadius, style: .continuous)
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: Constants.previewWidth, height: Constants.previewHeight)

                        Text("There are no active tabs")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                } else {
                    ForEach(recentTabs, id: \.id) { tab in
                        tabPreviewItem(for: tab)
                            .focusEffectDisabled()
                    }
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
        .background(BlurEffectView(material: .popover, blendingMode: .withinWindow))
        .background(theme.background.opacity(0.3))
        .cornerRadius(Constants.containerCornerRadius)
        .shadow(color: .blue.opacity(0.07), radius: 16, x: 0, y: 12)
        .background(keyboardHandler)
        .overlay(containerBorder)
    }

    private func tabPreviewItem(for tab: Tab) -> some View {
        Group {
            if tab.isWebViewReady {
                readyTabView(for: tab)
            } else {
                loadingTabView
            }
        }
        .shadow(
            color: focusedTab == tab.id ? theme.primary.opacity(0.3) : .clear,
            radius: 8, x: 0, y: 2
        )
        .animation(.easeOut(duration: 0.1), value: focusedTab)
        .focusable()
        .focused($focusedTab, equals: tab.id)
    }

    private func readyTabView(for tab: Tab) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            tabPreviewImage(for: tab)

            if focusedTab == tab.id {
                tabTitleBar(for: tab)
            }
        }
        .frame(width: Constants.previewWidth, alignment: .leading)
        .padding(.horizontal, 4)
        .onHover { isHovered in
            if isHovered {
                focusedTab = tab.id
            }
        }
        .onTapGesture {
            activateTab(tab)
        }
    }

    @ViewBuilder
    private func tabPreviewImage(for tab: Tab) -> some View {
        if let snapshot = tabSnapshots[tab] {
            Image(nsImage: snapshot.image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: Constants.previewWidth, height: Constants.previewHeight)
                .clipped()
                .cornerRadius(Constants.cornerRadius)
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 4)
                .drawingGroup()
                .overlay(focusBorder(for: tab))
        } else {
            RoundedRectangle(cornerRadius: Constants.cornerRadius, style: .continuous)
                .fill(Color.gray.opacity(0.3))
                .frame(width: Constants.previewWidth, height: Constants.previewHeight)
                .overlay(focusBorder(for: tab))
        }
    }

    private func focusBorder(for tab: Tab) -> some View {
        RoundedRectangle(cornerRadius: Constants.cornerRadius, style: .continuous)
            .stroke(
                focusedTab == tab.id ? theme.invertedSolidWindowBackgroundColor : Color.clear,
                lineWidth: 2
            )
    }

    private func tabTitleBar(for tab: Tab) -> some View {
        HStack(spacing: 8) {
            FavIcon(
                isWebViewReady: tab.isWebViewReady,
                favicon: tab.favicon,
                faviconLocalFile: tab.faviconLocalFile,
                textColor: theme.foreground,
                isPlayingMedia: tab.isPlayingMedia
            )
            .frame(width: 16, height: 16)

            Text(tab.title)
                .font(.system(size: 12))
                .foregroundColor(theme.foreground)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private var loadingTabView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Constants.cornerRadius, style: .continuous)
                .fill(Color.gray)
                .frame(width: Constants.previewWidth, height: Constants.previewHeight)

            ProgressView()
                .frame(width: 24, height: 24)
        }
    }

    private var keyboardHandler: some View {
        KeyCaptureView { event in
            if event.modifierFlags.contains([.control, .shift]) {
                focusPreviousTab()
            } else if event.modifierFlags.contains(.control) {
                focusNextTab()
                preWarmSnapshotsIfNeeded()
            }
        }
    }

    private var containerBorder: some View {
        RoundedRectangle(cornerRadius: Constants.containerCornerRadius, style: .continuous)
            .stroke(Color(.separatorColor), lineWidth: 1.5)
    }

    // MARK: - Computed Properties

    private var recentTabs: [Tab] {
        guard let activeContainer = tabManager.activeContainer else { return [] }
        return activeContainer.tabs
            .filter(\.isWebViewReady)
            .sorted { (lhs: Tab, rhs: Tab) in
                (lhs.lastAccessedAt ?? Date()) > (rhs.lastAccessedAt ?? Date())
            }
            .prefix(Constants.maxTabsToShow)
            .map { $0 }
    }

    // MARK: - Methods

    private func focusNextTab() {
        guard let currentFocusedTab = focusedTab,
              let currentIndex = recentTabs.firstIndex(where: { $0.id == currentFocusedTab })
        else {
            focusedTab = recentTabs.first?.id
            return
        }

        let nextIndex = (currentIndex + 1) % recentTabs.count
        focusedTab = recentTabs[nextIndex].id
    }

    private func focusPreviousTab() {
        guard let currentFocusedTab = focusedTab,
              let currentIndex = recentTabs.firstIndex(where: { $0.id == currentFocusedTab })
        else {
            focusedTab = recentTabs.first?.id
            return
        }

        let previousIndex = (currentIndex - 1 + recentTabs.count) % recentTabs.count
        focusedTab = recentTabs[previousIndex].id
    }

    private func activateTab(_ tab: Tab) {
        tabManager.activateTab(tab)
        closeFloatingTabSwitch()
    }

    private func handleModifierChange(_ newFlags: NSEvent.ModifierFlags) {
        guard !newFlags.contains(.control) else { return }

        if let focusedTabId = focusedTab,
           let tab = recentTabs.first(where: { $0.id == focusedTabId })
        {
            tabManager.activateTab(tab)
        }
        closeFloatingTabSwitch()
    }

    private func preWarmSnapshotsIfNeeded() {
        if !isLoadingSnapshots, tabSnapshots.count < recentTabs.count {
            preloadSnapshots()
        }
    }

    private func preloadSnapshots() {
        guard !isLoadingSnapshots else { return }
        isLoadingSnapshots = true

        let currentTabs = Set(recentTabs)
        tabSnapshots = tabSnapshots.filter { currentTabs.contains($0.key) }

        let snapshotGroup = DispatchGroup()

        for tab in recentTabs {
            guard tab.isWebViewReady else { continue }

            let currentURL = tab.webView.url?.absoluteString ?? ""

            if let existingSnapshot = tabSnapshots[tab],
               existingSnapshot.url == currentURL
            {
                continue
            }

            snapshotGroup.enter()
            takeSnapshot(for: tab, url: currentURL, group: snapshotGroup)
        }

        snapshotGroup.notify(queue: .main) {
            self.isLoadingSnapshots = false
        }
    }

    private func takeSnapshot(for tab: Tab, url: String, group: DispatchGroup) {
        DispatchQueue.global(qos: .userInteractive).async {
            let config = self.createSnapshotConfiguration(for: tab)

            DispatchQueue.main.async {
                tab.webView.takeSnapshot(with: config) { image, _ in
                    defer { group.leave() }

                    guard let cgImage = image?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                        return
                    }

                    // Preserve the original aspect ratio of the snapshot
                    let originalSize = CGSize(width: cgImage.width, height: cgImage.height)
                    let nsImage = NSImage(cgImage: cgImage, size: originalSize)

                    self.tabSnapshots[tab] = TabSnapshot(image: nsImage, url: url)
                }
            }
        }
    }

    private func createSnapshotConfiguration(for tab: Tab) -> WKSnapshotConfiguration {
        let config = WKSnapshotConfiguration()
        config.afterScreenUpdates = false
        // Don't force a specific width - let the webview determine natural size
        return config
    }

    private func closeFloatingTabSwitch() {
        appState.isFloatingTabSwitchVisible = false
    }
}
