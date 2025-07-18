import AppKit
import SwiftUI
import SwiftData

struct SidebarView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var appState: AppState
    @State private var selectedContainer = "personal"
    @State private var isContainerDropdownOpen = false
    @State private var draggedItem: UUID?
    //  @State private var containers: [ContainerData] = SidebarView.defaultContainers
    @Query var containers: [TabContainer]
    
    
    private let columns = Array(repeating: GridItem(spacing: 10), count: 3)
    
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
            
            ScrollView(.vertical, showsIndicators: false) {
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
            
            ContainerSelector(
                isDropdownOpen: $isContainerDropdownOpen
            )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
    }
    
    private var favoriteTabs: [Tab] {
        return tabManager.activeContainer?.tabs
            .sorted(by: { $0.createdAt > $1.createdAt })
            .filter { $0.type == .fav } ?? []
    }
    
    private var pinnedTabs: [Tab] {
        return tabManager.activeContainer?.tabs
            .sorted(by: { $0.createdAt > $1.createdAt })
            .filter { $0.type == .pinned } ?? []
    }
    
    private var normalTabs: [Tab] {
        return tabManager.activeContainer?.tabs
            .sorted(by: { $0.createdAt > $1.createdAt })
            .filter { $0.type == .normal } ?? []
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
                to: newContainer
            )
    }
    
    private func dragTab(_ tabId: UUID) -> NSItemProvider {
        draggedItem = tabId
        return NSItemProvider(object: NSString(string: tabId.uuidString))
    }
    
    private func dropTab(_ tabId: String) {
        draggedItem = nil
    }
}

