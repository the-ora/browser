import AppKit
import SwiftUI

extension Array where Element: Hashable {
    func unique() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

enum DelegateTarget {
    case tab(tabset: Bool), divider

    func toDropItem(withId id: UUID) -> TargetedDropItem {
        switch self {
        case let .tab(tabset):
            return .tab(id: id, tabset: tabset)
        case .divider:
            return .divider(id)
        }
    }

    var reparentingBehavior: ReparentingBehavior {
        switch self {
        case .tab:
            return .child
        case .divider:
            return .sibling
        }
    }
}

struct TabDropDelegate: DropDelegate {
    let item: Tab  // to
    let representative: DelegateTarget
    @Binding var draggedItem: UUID?
    @Binding var targetedItem: TargetedDropItem?

    let targetSection: TabSection

    func dropEntered(info: DropInfo) {
        targetedItem = representative.toDropItem(withId: item.id)
    }

    func dropExited(info: DropInfo) {
        targetedItem = nil
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        .init(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [.text]).first else { return false }
        performHapticFeedback(pattern: .alignment)
        provider.loadObject(ofClass: NSString.self) {
            object,
                _ in
            if let string = object as? String,
               let uuid = UUID(uuidString: string)
            {
                if uuid == item.id {
                    return
                }

                // No assigning a parent to its child
                var itemParent = item.parent
                while let parent = itemParent {
                    if parent.id == uuid {
                        return
                    }
                    itemParent = parent.parent
                }
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
                            if case let .tab(tabset) = representative,
                               tabset
                            {
                                self.item.container
                                    .combineToTileset(
                                        withSourceTab: from,
                                        andDestinationTab: self.item
                                    )
                            } else {
                                self.item.container
                                    .reorderTabs(
                                        from: from,
                                        to: self.item,
                                        withReparentingBehavior: representative.reparentingBehavior
                                    )
                            }
                        }
                    } else {
                        moveTabBetweenSections(from: from, to: self.item)
                    }
                }
            }
        }
        draggedItem = nil
        targetedItem = nil
        return true
    }
}
