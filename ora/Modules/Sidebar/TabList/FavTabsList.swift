import SwiftUI
import AppKit

struct FavTabsGrid: View {
    @EnvironmentObject var tabManger: TabManager
  let tabs: [Tab]
  @Binding var draggedItem: UUID?
  let onDrag: (UUID) -> NSItemProvider
  let selectedContainerId: String
  let onSelect: (Tab) -> Void
  let onFavoriteToggle: (Tab) -> Void
  let onClose: (Tab) -> Void
    let onMoveToContainer: (
        Tab,
        TabContainer
    ) -> Void

  private let columns = Array(repeating: GridItem(spacing: 10), count: 3)

  var body: some View {
    LazyVGrid(columns: columns, spacing: 10) {
      ForEach(tabs) { tab in
        FavTabItem(
          tab: tab,
          isSelected: tabManger.isActive(tab),
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
            targetSection: .favorites
          )
        )
      }
    }
  }
}
