import SwiftUI
import AppKit

struct RegularTabsList: View {
  let tabs: [TabData]
  let selectedTabId: String?
  let draggedItem: String?
  @Binding var containers: [ContainerData]
  let selectedContainerId: String
  let onSelect: (String) -> Void
  let onPinToggle: (String) -> Void
  let onFavoriteToggle: (String) -> Void
  let onClose: (String) -> Void
  let onMoveToContainer: (String, String) -> Void
  let onAddNewTab: () -> Void

  var body: some View {
    LazyVStack(spacing: 6) {
      NewTabButton(addNewTab: onAddNewTab)
      ForEach(tabs) { tab in
        TabItem(
          tab: tab,
          isSelected: selectedTabId == tab.id,
          isDragging: draggedItem == tab.id,
          onTap: { onSelect(tab.id) },
          onPinToggle: { onPinToggle(tab.id) },
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
            targetSection: .regular
          )
        )
      }
    }
    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: tabs.map(\.id))
  }
}