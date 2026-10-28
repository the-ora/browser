import SwiftUI

struct ContainerView: View {
    let container: TabContainer
    let selectedContainer: String
    let containers: [TabContainer]

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var toolbarManager: ToolbarManager
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var privacyMode: PrivacyMode
    @EnvironmentObject var toastManager: ToastManager

    @State private var draggedItem: UUID?
    /// Identifies the current drag, so a late end of a previous one (even of
    /// the same tab) does not cancel it.
    @State private var dragSession: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if toolbarManager.isToolbarHidden {
                SidebarURLDisplay()
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
        .modifier(OraWindowDragGesture())
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
        toastManager.show(
            "Moved to \(newContainer.emoji) \(newContainer.name)",
            icon: .system("arrow.right.arrow.left")
        )
    }

    private func dragTab(_ tabId: UUID) -> NSItemProvider {
        let session = UUID()
        dragSession = session
        draggedItem = tabId
        let provider = TabItemProvider(object: tabId.uuidString as NSString)
        // The provider may be released after the next drag has started: only
        // end the drag it belongs to.
        provider.didEnd = {
            guard dragSession == session else { return }
            dragSession = nil
            draggedItem = nil
        }
        return provider
    }

    private func duplicateTab(_ tab: Tab) {
        tabManager.duplicateTab(tab)
    }
}

/// Lets the window be moved by dragging the sidebar's empty space. The
/// gesture sits behind the tabs, so it never competes with a tab drag: on top
/// of them it could hijack the drag, which then stuck to the mouse.
private struct OraWindowDragGesture: ViewModifier {
    func body(content: Content) -> some View {
        content.background {
            Color.clear
                .contentShape(Rectangle())
                .modifier(WindowDragArea())
        }
    }
}

private struct WindowDragArea: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content.gesture(WindowDragGesture())
        } else {
            content.gesture(BackportWindowDragGesture())
        }
    }
}

private struct BackportWindowDragGesture: Gesture {
    struct Value: Equatable {
        static func == (lhs: Value, rhs: Value) -> Bool {
            true
        }
    }

    var body: some Gesture<Value> {
        DragGesture()
            .onChanged { _ in
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
