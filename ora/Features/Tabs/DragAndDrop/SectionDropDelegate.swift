import AppKit
import SwiftUI

struct SectionDropDelegate: DropDelegate {
    let items: [Tab]
    @Binding var draggedItem: UUID?
    let targetSection: TabSection
    let tabManager: TabManager

    /// Drop on an empty section (no tab to drop onto): the tab joins it.
    func dropEntered(info: DropInfo) {
        guard items.isEmpty,
              let draggedID = draggedItem,
              let container = tabManager.activeContainer,
              let moved = container.tabs.first(where: { $0.id == draggedID })
        else { return }

        performHapticFeedback(pattern: .alignment)
        let newType = tabType(for: targetSection)
        moved.type = newType
        // Pinned and favorite tabs come back to their saved URL.
        moved.savedURL = newType == .normal ? nil : moved.url
        moved.order = 1
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        try? tabManager.modelContext.save()
        return true
    }
}
