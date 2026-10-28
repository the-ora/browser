import AppKit
import SwiftUI

extension Array where Element: Hashable {
    func unique() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

struct TabDropDelegate: DropDelegate {
    let item: Tab  // to
    @Binding var draggedItem: UUID?

    let targetSection: TabSection

    func dropEntered(info: DropInfo) {
        // The dragged tab is known right away: reading it back from the drag
        // item was asynchronous, so the list lagged and fast moves could be
        // applied out of order.
        guard let draggedID = draggedItem, draggedID != item.id,
              let moved = item.container.tabs.first(where: { $0.id == draggedID })
        else { return }

        performHapticFeedback(pattern: .alignment)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            item.container.moveTab(moved, onto: item)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        .init(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        try? item.container.modelContext?.save()
        return true
    }
}
