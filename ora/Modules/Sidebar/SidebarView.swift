import AppKit
import SwiftUI
import SwiftData

struct SidebarView: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var historyManger: HistoryManager
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var appState: AppState
    @State private var selectedContainer = "personal"
    @State private var isContainerDropdownOpen = false
    @State private var draggedItem: UUID?
    @Query var containers: [TabContainer]
    @Query(filter: nil, sort: [.init(\History.lastAccessedAt, order: .reverse)]) var histories: [History]
    private let columns = Array(repeating: GridItem(spacing: 10), count: 3)
    
    func importArc() {
        if let root = getRoot() {
            let result = inspectItems(root)
            var newContainers: [TabContainer] = []
            
            for space in result.cleanSpaces {
                let container = tabManager
                    .addContainer(
                        name: space.title ?? "Unknown",
                        emoji: space.emoji ?? "💀"
                    )
                newContainers
                    .append(
                        container
                    )
                for tab in result.cleanTabs {
                    if space.containerIDs
                        .contains(
                            tab.parentID
                        ){
                        if let url = URL(
                            string: tab.urlString
                        ) {
                            
                            
                            let newTab = tabManager
                                .addTab(
                                    title: tab.title,
                                    url: url,
                                    container: container,
                                    historyManager: historyManger,
                                    downloadManager: downloadManager
                                )
                            
                            tabManager
                                .togglePinTab(
                                    newTab
                                )
                        }
                    }
                }
                
            }
           
            var seenContainers: Set<UUID> = []
            for container in newContainers {
              
                if seenContainers
                    .contains(container.id) {continue}
                seenContainers
                    .insert(container.id)
                for tab in result.cleanTabs {
                    
                    if result.favs
                        .contains(
                            tab.parentID
                        ){
                        if let url = URL(
                            string: tab.urlString
                        ) {
                            let newTab = tabManager
                                .addTab(
                                    title: tab.title,
                                    url: url,
                                    container: container,
                                    historyManager: historyManger,
                                    downloadManager: downloadManager
                                )
                            tabManager
                                .toggleFavTab(
                                    newTab
                                )
                        }
                    }
                }
            }
            
        }
    }
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
                
                Button("Import arc") {
                 importArc()
                }
                //                ForEach(histories){ history in
                //                    Text("#\(history.visitCount)- \(history.title)")
                //                    Text("-----------------")
                //                }
                //                Button("Switch") {
                //                    tabManager
                //                        .reorderTabs(
                //                            from: normalTabs[1],
                //                            to: normalTabs[5]
                //                        )
                //                }
            }
            
            DownloadsWidget()
                .padding(.bottom, 8)
            
            ContainerSelector(
                isDropdownOpen: $isContainerDropdownOpen
            )
        }
        .padding(
            EdgeInsets(
                top: 36,
                leading: 12,
                bottom: 12,
                trailing: 12
            )
        )
    }
    
    private var favoriteTabs: [Tab] {
        return tabManager.activeContainer?.tabs
            .sorted(by: { $0.order > $1.order })
            .filter { $0.type == .fav } ?? []
    }
    
    private var pinnedTabs: [Tab] {
        return tabManager.activeContainer?.tabs
            .sorted(by: { $0.order > $1.order })
            .filter { $0.type == .pinned } ?? []
    }
    
    private var normalTabs: [Tab] {
        return tabManager.activeContainer?.tabs
            .sorted(by: { $0.order > $1.order })
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