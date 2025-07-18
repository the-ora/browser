import SwiftUI
import SwiftData

struct NormalTabsList: View {
  let tabs: [Tab]
  @Binding var draggedItem: UUID?
  let onDrag: (UUID) -> NSItemProvider
  let onSelect: (Tab) -> Void
  let onPinToggle: (Tab) -> Void
  let onFavoriteToggle: (Tab) -> Void
  let onClose: (Tab) -> Void
    let onMoveToContainer: (
        Tab,
        TabContainer
    ) -> Void
  let onAddNewTab: () -> Void
  @Query var containers: [TabContainer]
    @EnvironmentObject var tabManger: TabManager
    
  var body: some View {
    LazyVStack(spacing: 6) {
      NewTabButton(addNewTab: onAddNewTab)
      ForEach(tabs) { tab in
        TabItem(
          tab: tab,
          isSelected: tabManger.isActive(tab),
          isDragging: draggedItem == tab.id,
          onTap: { onSelect(tab) },
          onPinToggle: { onPinToggle(tab) },
          onFavoriteToggle: { onFavoriteToggle(tab) },
          onClose: { onClose(tab) },
          onMoveToContainer: { onMoveToContainer(tab, $0) },
          availableContainers: containers
        )
        .onDrag { onDrag(tab.id) }
        .onDrop(
          of: [.text],
          delegate: TabDropDelegate(
            item: tab,
            draggedItem: $draggedItem,
            targetSection: .regular
          )
        )
      }
    }
    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: tabs.map(\.id))
  }
}
