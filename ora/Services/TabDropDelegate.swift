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
        guard let provider = info.itemProviders(for: [.text]).first else { return }
        performHapticFeedback(pattern: .alignment)
        provider.loadObject(ofClass: NSString.self) { object, _ in
            if let string = object as? String,
               let uuid = UUID(uuidString: string)
            {
                DispatchQueue.main.async {
                    // First try to find the tab in the target container
                    var from = self.item.container.tabs.first(where: { $0.id == uuid })

                    // If not found, try to find it in all containers of the same type
                    if from == nil {
                        // Look through all tabs in all containers to find the dragged tab
                        for container in self.item.container.tabs.compactMap(\.container).unique() {
                            if let foundTab = container.tabs.first(where: { $0.id == uuid }) {
                                from = foundTab
                                break
                            }
                        }
                    }

                    guard let from else { return }

                    if isInSameSection(
                        from: from,
                        to: self.item
                    ) {
                        withAnimation(
                            .spring(
                                response: 0.3,
                                dampingFraction: 0.8
                            )
                        ) {
                            self.item.container
                                .reorderTabs(
                                    from: from,
                                    to: self.item
                                )
                        }
                    } else {
                        moveTabBetweenSections(from: from, to: self.item)
                    }
                }
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        .init(operation: .move)
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

        // Reorder the tabs in the new section
        from.container.reorderTabs(from: from, to: to)
    }
}
