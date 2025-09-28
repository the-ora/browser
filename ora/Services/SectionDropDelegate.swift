import AppKit
import SwiftUI

struct SectionDropDelegate: DropDelegate {
    let items: [Tab]
    @Binding var draggedItem: UUID?
    let targetSection: TabSection
    let tabManager: TabManager

    func dropEntered(info: DropInfo) {
        guard let provider = info.itemProviders(for: [.text]).first else { return }
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
                    from.type = tabType(for: self.targetSection)
                    let maxOrder = container.tabs.max(by: { $0.order < $1.order })?.order ?? 0
                    from.order = maxOrder + 1
                } else if let to = self.items.last {
                    // Handle dropping at the end of the section
                    if isInSameSection(from: from, to: to) {
                        // Moving within the same section - place after the last tab
                        from.order = to.order - 1
                    } else {
                        // Moving to a different section
                        moveTabBetweenSections(from: from, to: to)
                        // Place it at the end of the new section
                        from.order = to.order - 1
                    }
                }
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        return true
    }

    private func isInSameSection(from: Tab, to: Tab) -> Bool {
        return from.type == to.type
    }

    private func moveTabBetweenSections(from: Tab, to: Tab) {
        // Change the tab type to match the target section
        from.type = to.type

        // If moving to pinned or fav, save the URL
        if to.type == .pinned || to.type == .fav {
            from.savedURL = from.url
        } else {
            from.savedURL = nil
        }
    }

    private func tabType(for section: TabSection) -> TabType {
        switch section {
        case .fav:
            return .fav
        case .pinned:
            return .pinned
        case .normal:
            return .normal
        }
    }
}
