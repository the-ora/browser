import SwiftUI

struct ContainerView: View {
    let container: TabContainer
    let selectedContainer: String
    let containers: [TabContainer]

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var tabManager: TabManager
    @Environment(\.theme) private var theme
    @State private var audioTooltip: AudioTooltip?
    @State private var draggedItem: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            FavTabsGrid(
                tabs: favoriteTabs,
                draggedItem: $draggedItem,
                onDrag: dragTab,
                selectedContainerId: selectedContainer,
                onSelect: selectTab,
                onFavoriteToggle: toggleFavorite,
                onClose: removeTab,
                onMoveToContainer: moveTab
            )

            VerticalScrollView {
                ZStack(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 16) {
                        PinnedTabsList(
                            tabs: pinnedTabs,
                            draggedItem: $draggedItem,
                            onDrag: dragTab,
                            onSelect: selectTab,
                            onPinToggle: togglePin,
                            onFavoriteToggle: toggleFavorite,
                            onClose: removeTab,
                            onMoveToContainer: moveTab,
                            containers: containers
                        )
                        Divider()
                        NormalTabsList(
                            tabs: normalTabs,
                            draggedItem: $draggedItem,
                            onDrag: dragTab,
                            onSelect: selectTab,
                            onPinToggle: togglePin,
                            onFavoriteToggle: toggleFavorite,
                            onClose: removeTab,
                            onMoveToContainer: moveTab,
                            onAddNewTab: addNewTab
                        )
                    }

                    GeometryReader { proxy in
                        if let tip = audioTooltip {
                            let containerRect = proxy.frame(in: .global)
                            let x = tip.rect.minX - containerRect.minX
                            let y = max(0, tip.rect.minY - 28 - containerRect.minY)
                            Text(tip.text)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(theme.solidWindowBackgroundColor.opacity(1))
                                )
                                .foregroundColor(.white)
                                .offset(x: x, y: y)
                                .zIndex(999)
                                .allowsHitTesting(false)
                                .transition(.opacity.combined(with: .scale))
                        }
                    }
                }
                .onPreferenceChange(AudioTooltipPreferenceKey.self) { audioTooltip = $0 }
            }
        }
    }

    private var favoriteTabs: [Tab] {
        return container.tabs
            .sorted(by: { $0.order > $1.order })
            .filter { $0.type == .fav }
    }

    private var pinnedTabs: [Tab] {
        return container.tabs
            .sorted(by: { $0.order > $1.order })
            .filter { $0.type == .pinned }
    }

    private var normalTabs: [Tab] {
        return container.tabs
            .sorted(by: { $0.order > $1.order })
            .filter { $0.type == .normal }
    }

    private func addNewTab() {
        appState.showLauncher = true
    }

    private func removeTab(_ tab: Tab) {
        tabManager.closeTab(tab: tab)
    }

    private func togglePin(_ tab: Tab) {
        tabManager.togglePinTab(tab)
    }

    private func toggleFavorite(_ tab: Tab) {
        tabManager.toggleFavTab(tab)
    }

    private func selectTab(_ tab: Tab) {
        tabManager.activateTab(tab)
    }

    private func moveTab(
        _ tab: Tab,
        _ newContainer: TabContainer
    ) {
        tabManager
            .moveTabToContainer(
                tab,
                toContainer: newContainer
            )
    }

    private func dragTab(_ tabId: UUID) -> NSItemProvider {
        draggedItem = tabId
        let provider = TabItemProvider(object: tabId.uuidString as NSString)
        provider.didEnd = {
            draggedItem = nil
        }
        return provider
    }

    private func dropTab(_ tabId: String) {
        draggedItem = nil
    }
}

class TabItemProvider: NSItemProvider {
    var didEnd: (() -> Void)?
    deinit {
        didEnd?()
    }
}
