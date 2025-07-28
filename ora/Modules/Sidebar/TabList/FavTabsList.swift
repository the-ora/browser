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
  let onMoveToContainer:
    (
      Tab,
      TabContainer
    ) -> Void

  private let columns = Array(repeating: GridItem(spacing: 10), count: 3)

  private var paddingCount: Int {
    let remainder = tabs.count % 3
    return remainder == 0 ? 0 : 3 - remainder
  }

  var body: some View {
    LazyVGrid(columns: tabs.isEmpty ? [GridItem(spacing: 10)] : columns, spacing: 10) {
      if tabs.isEmpty {
        EmptyFavTabItem()
          .onDrop(
            of: [.text],
            delegate: SectionDropDelegate(
              items: tabs,
              draggedItem: $draggedItem,
              targetSection: .fav,
              tabManager: tabManager
            )
          )
      } else {
        ForEach(tabs) { tab in
          FavTabItem(
            tab: tab,
            isSelected: tabManager.isActive(tab),
            isDragging: draggedItem == tab.id,
            onTap: { onSelect(tab) },
            onFavoriteToggle: { onFavoriteToggle(tab) },
            onClose: { onClose(tab) },
            onMoveToContainer: { onMoveToContainer(tab, $0) }
          )
          .onDrag { onDrag(tab.id) }
          .onDrop(
            of: [.text],
            delegate: TabDropDelegate(
              item: tab,
              draggedItem: $draggedItem,
              targetSection: .fav
            )
          )
        }
      }
    }.onDrop(
      of: [.text],
      delegate: SectionDropDelegate(
        items: tabs,
        draggedItem: $draggedItem,
        targetSection: .fav,
        tabManager: tabManager
      )
    )
  }
}
