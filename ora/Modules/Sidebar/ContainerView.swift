import SwiftUI

struct ContainerView: View {
    let container: TabContainer
    let selectedContainer: String
    let containers: [TabContainer]

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var toolbarManager: ToolbarManager
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var privacyMode: PrivacyMode

    @State var isDragging = false
    @State private var draggedItem: UUID?
    @State private var editingURLString: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if toolbarManager.isToolbarHidden, let tab = tabManager.activeTab {
                SidebarURLDisplay(
                    tab: tab,
                    editingURLString: $editingURLString
                )
                .transition(.asymmetric(
                    insertion: .push(from: .top).combined(with: .opacity),
                    removal: .push(from: .bottom).combined(with: .opacity)
                ))
            }
            if !privacyMode.isPrivate {
                FavTabsGrid(
                    tabs: favoriteTabs,
                    draggedItem: $draggedItem,
                    onDrag: dragTab,
                    selectedContainerId: selectedContainer,
                    onSelect: selectTab,
                    onFavoriteToggle: toggleFavorite,
                    onClose: removeTab,
                    onDuplicate: duplicateTab,
                    onMoveToContainer: moveTab
                )
            } else {
                VStack(alignment: .center, spacing: 8) {
                    Text("Private Browsing")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text("Your activity is not being saved")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))
                )
                .padding(.horizontal)
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    if !privacyMode.isPrivate {
                        PinnedTabsList(
                            tabs: pinnedTabs,
                            draggedItem: $draggedItem,
                            onDrag: dragTab,
                            onSelect: selectTab,
                            onPinToggle: togglePin,
                            onFavoriteToggle: toggleFavorite,
                            onClose: removeTab,
                            onDuplicate: duplicateTab,
                            onMoveToContainer: moveTab,
                            containers: containers
                        )
                        Divider()
                    }
                    NormalTabsList(
                        tabs: normalTabs,
                        draggedItem: $draggedItem,
                        onDrag: dragTab,
                        onSelect: selectTab,
                        onPinToggle: togglePin,
                        onFavoriteToggle: toggleFavorite,
                        onClose: removeTab,
                        onDuplicate: duplicateTab,
                        onMoveToContainer: moveTab,
                        onAddNewTab: addNewTab
                    )
                }
            }
        }
        .modifier(OraWindowDragGesture(isDragging: $isDragging))
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
        isDragging = true
        draggedItem = tabId
        let provider = TabItemProvider(object: tabId.uuidString as NSString)
        provider.didEnd = {
            draggedItem = nil
        }
        return provider
    }

    private func dropTab(_ tabId: String) {
        isDragging = false
        draggedItem = nil
    }

    private func duplicateTab(_ tab: Tab) {
        tabManager.duplicateTab(tab)
    }
}

private struct OraWindowDragGesture: ViewModifier {
    @Binding var isDragging: Bool

    func body(content: Content) -> some View {
        Group {
            if isDragging {
                content
            } else {
                if #available(macOS 15.0, *) {
                    content.gesture(WindowDragGesture())
                } else {
                    content.gesture(BackportWindowDragGesture(isDragging: $isDragging))
                }
            }
        }
    }
}

private struct BackportWindowDragGesture: Gesture {
    @Binding var isDragging: Bool

    struct Value: Equatable {
        static func == (lhs: Value, rhs: Value) -> Bool { true }
    }

    init(isDragging: Binding<Bool>) {
        self._isDragging = isDragging
    }

    var body: some Gesture<Value> {
        DragGesture()
            .onChanged { _ in
                /// Makes intent cleaner, if we're dragging, then just return
                /// Maybe some other case needs to be watched for here
                guard !isDragging else {
                    return
                }
                guard let win = NSApp.keyWindow, let event = NSApp.currentEvent else {
                    return
                }

                win.performDrag(with: event)
            }
            .map { _ in Value() }
    }
}

class TabItemProvider: NSItemProvider {
    var didEnd: (() -> Void)?
    deinit {
        didEnd?()
    }
}
