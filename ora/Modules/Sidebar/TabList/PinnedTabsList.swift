import SwiftData
import SwiftUI

struct PinnedTabsList: View {
    let tabs: [Tab]
    @Binding var draggedItem: UUID?
    @State private var isHoveringOverEmpty = false
    let onDrag: (UUID) -> NSItemProvider
    let onSelect: (Tab) -> Void
    let onPinToggle: (Tab) -> Void
    let onFavoriteToggle: (Tab) -> Void
    let onClose: (Tab) -> Void
    let onDuplicate: (Tab) -> Void
    let onMoveToContainer: (Tab, TabContainer) -> Void
    let containers: [TabContainer]
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var sidebarManager: SidebarManager
    @Environment(\.theme) var theme

    private var spaceName: String? {
        if let active = tabManager.activeContainer {
            return "\(active.emoji) \(active.name)"
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(spaceName ?? "Pinned")
                .font(.callout)
                .foregroundColor(theme.mutedForeground)
                .padding(.top, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            if tabs.isEmpty {
                Group {
                    if sidebarManager.stickyPinned || isHoveringOverEmpty {
                        EmptyPinnedTabs()
                    } else {
                        Capsule().frame(height: 3).opacity(0)
                    }
                }
            } else {
                ForEach(tabs) { tab in
                    TabItem(
                        tab: tab,
                        isSelected: tabManager.isActive(tab),
                        isDragging: draggedItem == tab.id,
                        onTap: { onSelect(tab) },
                        onPinToggle: { onPinToggle(tab) },
                        onFavoriteToggle: { onFavoriteToggle(tab) },
                        onClose: { onClose(tab) },
                        onDuplicate: { onDuplicate(tab) },
                        onMoveToContainer: { onMoveToContainer(tab, $0) },
                        availableContainers: containers
                    )
                    .onDrag { onDrag(tab.id) }
                    .onDrop(
                        of: [.text],
                        delegate: TabDropDelegate(
                            item: tab,
                            draggedItem: $draggedItem,
                            targetSection: .pinned
                        )
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onDrop(
            of: [.text],
            delegate: SectionDropDelegate(
                items: tabs,
                draggedItem: $draggedItem,
                targetSection: .pinned,
                tabManager: tabManager,
                isHovering: $isHoveringOverEmpty
            )
        )
        .onChange(of: tabs.count) { _, new in
            if new > 0 {
                sidebarManager.stickyPinned = false
            }
        }
    }
}
