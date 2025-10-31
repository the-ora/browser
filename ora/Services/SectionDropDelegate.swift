import AppKit
import SwiftUI

struct SectionDropDelegate: DropDelegate {
    let items: [Tab]
    @Binding var draggedItem: UUID?
    @Binding var isHovering: Bool
    let targetSection: TabSection
    let tabManager: TabManager

    init(
        items: [Tab],
        draggedItem: Binding<UUID?>,
        targetSection: TabSection,
        tabManager: TabManager,
        isHovering: Binding<Bool>? = nil
    ) {
        self.items = items
        self._draggedItem = draggedItem
        self.targetSection = targetSection
        self.tabManager = tabManager
        self._isHovering = isHovering ?? .constant(false)
    }

    func dropEntered(info: DropInfo) {
        isHovering = true
    }

    func dropExited(info: DropInfo) {
        isHovering = false
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        isHovering = false
        guard let provider = info.itemProviders(for: [.text]).first else { return false }
        performHapticFeedback(pattern: .alignment)

        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard
                let string = object as? String,
                let uuid = UUID(uuidString: string)
            else { return }

            DispatchQueue.main.async {
                guard let container = self.items.first?.container ?? self.tabManager.activeContainer,
                      let from = container.tabs.first(where: { $0.id == uuid })
                else { return }

                if self.items.isEmpty {
                    // Section is empty, just change type and order
                    let newType = tabType(for: self.targetSection)
                    from.type = newType
                    // Update savedURL when moving into pinned/fav; clear when moving to normal
                    switch newType {
                    case .pinned, .fav:
                        from.savedURL = from.url
                    case .normal:
                        from.savedURL = nil
                    }
                    let maxOrder = container.tabs.max(by: { $0.order < $1.order })?.order ?? 0
                    from.order = maxOrder + 1
                    try? self.tabManager.modelContext.save()
                }
                // else if let to = self.items.last {
                // if isInSameSection(from: from, to: to) {
                // withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                //   container.reorderTabs(from: from, to: to)
                // }
                // } else {
                // moveTabBetweenSections(from: from, to: to)
                // }
                // }
            }
        }
        draggedItem = nil
        return true
    }
}
