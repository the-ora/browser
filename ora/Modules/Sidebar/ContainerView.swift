import SwiftUI

struct ContainerView: View {
    let container: TabContainer
    let selectedContainer: String
    let containers: [TabContainer]

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var tabManager: TabManager
    @State private var draggedItem: UUID?
    @State private var showCreateFolderDialog = false
    @State private var newFolderName = ""

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
                    
                    // Display folders
                    ForEach(folders) { folder in
                        FolderView(
                            folder: folder,
                            draggedItem: $draggedItem,
                            onDrag: dragTab,
                            onSelect: selectTab,
                            onPinToggle: togglePin,
                            onFavoriteToggle: toggleFavorite,
                            onClose: removeTab,
                            onMoveToContainer: moveTab,
                            availableContainers: containers
                        )
                    }
                    
                    NormalTabsList(
                        tabs: normalTabsNotInFolders,
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
            }
        }
        .modifier(WindowDragIfAvailable())
        .contextMenu {
            Button("Create New Folder") {
                showCreateFolderDialog = true
            }
        }
        .sheet(isPresented: $showCreateFolderDialog) {
            CreateFolderSheet(
                isPresented: $showCreateFolderDialog,
                folderName: $newFolderName,
                onCreate: {
                    if !newFolderName.isEmpty {
                        _ = tabManager.createFolder(name: newFolderName, in: container)
                        newFolderName = ""
                    }
                }
            )
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
    
    private var normalTabsNotInFolders: [Tab] {
        return container.tabs
            .sorted(by: { $0.order > $1.order })
            .filter { $0.type == .normal && $0.folder == nil }
    }
    
    private var folders: [Folder] {
        return container.folders
            .sorted(by: { $0.order < $1.order })
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

private struct WindowDragIfAvailable: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content.gesture(WindowDragGesture())
        } else {
            content
        }
    }
}

class TabItemProvider: NSItemProvider {
    var didEnd: (() -> Void)?
    deinit {
        didEnd?()
    }
}
