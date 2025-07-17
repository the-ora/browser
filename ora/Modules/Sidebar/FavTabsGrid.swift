import SwiftUI
import AppKit

struct FavTabsGrid: View {
  let tabs: [TabData]
  let selectedTabId: String?
  let draggedItem: String?
  @Binding var containers: [ContainerData]
  let selectedContainerId: String
  let onSelect: (String) -> Void
  let onFavoriteToggle: (String) -> Void
  let onClose: (String) -> Void
  let onMoveToContainer: (String, String) -> Void

  private let columns = Array(repeating: GridItem(spacing: 10), count: 3)

  var body: some View {
    LazyVGrid(columns: columns, spacing: 10) {
      ForEach(tabs) { tab in
        FavTabItem(
          tab: tab,
          isSelected: selectedTabId == tab.id,
          isDragging: draggedItem == tab.id,
          onTap: { onSelect(tab.id) },
          onFavoriteToggle: { onFavoriteToggle(tab.id) },
          onClose: { onClose(tab.id) },
          onMoveToContainer: { onMoveToContainer(tab.id, $0) },
          availableContainers: containers,
          selectedContainerId: selectedContainerId
        )
        .onDrag { NSItemProvider(object: NSString(string: tab.id)) }
        .onDrop(
          of: [.text],
          delegate: TabDropDelegate(
            item: tab,
            containers: $containers,
            selectedContainerId: selectedContainerId,
            draggedItem: .constant(draggedItem),
            targetSection: .favorites
          )
        )
      }
    }
  }
}
