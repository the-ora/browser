import AppKit
import SwiftUI

struct FavTabsGrid: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var tabManager: TabManager
    let tabs: [Tab]
    @Binding var draggedItem: UUID?
    let onDrag: (UUID) -> NSItemProvider
    let selectedContainerId: String
    let onSelect: (Tab) -> Void
    let onFavoriteToggle: (Tab) -> Void
    let onClose: (Tab) -> Void
    let onDuplicate: (Tab) -> Void
    let onMoveToContainer:
        (
            Tab,
            TabContainer
        ) -> Void

    private var adaptiveColumns: [GridItem] {
        let maxColumns = 3
        let columnCount = min(max(1, tabs.count), maxColumns)
        return Array(repeating: GridItem(spacing: 10), count: columnCount)
    }

    var body: some View {
        LazyVGrid(columns: adaptiveColumns, spacing: 10) {
            if tabs.isEmpty {
                EmptyFavTabItem()
            } else {
                ForEach(tabsSortedByParent(tabs)) { iTab in
                    let tab = iTab.tabs.first!
                    FavTabItem(
                        tabs: iTab.tabs,
                        isSelected: tabManager.isActive(tab),
                        isDragging: draggedItem == tab.id,
                        onTap: { onSelect(tab) },
                        onFavoriteToggle: { onFavoriteToggle(tab) },
                        onClose: { onClose(tab) },
                        onDuplicate: { onDuplicate(tab) },
                        onMoveToContainer: { onMoveToContainer(tab, $0) }
                    )
                    .onDrag { onDrag(tab.id) }
                    .onDrop(
                        of: [.text],
                        delegate: GeneralDropDelegate(
                            item: .tab(tab),
                            representative: .tab(tabset: true),
                            draggedItem: $draggedItem, targetedItem:
                            .constant(nil),
                            targetSection: .fav
                        )
                    )
                }
            }
        }
        .onDrop(
            of: [.text],
            delegate: GeneralDropDelegate(
                item:
                .container(
                    tabManager.activeContainer!),
                representative: .divider, draggedItem: $draggedItem,
                targetedItem: .constant(nil), targetSection: .fav
            )
        )
        .animation(.easeOut(duration: 0.1), value: adaptiveColumns.count)
    }
}
