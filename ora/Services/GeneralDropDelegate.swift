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

extension UUID {
    static let zero: UUID = .init(uuidString: "00000000-0000-0000-0000-000000000000")!
}

struct NilDropDelegate: DropDelegate {
    func dropEntered(info: DropInfo) {}

    func dropExited(info: DropInfo) {}

    func dropUpdated(info: DropInfo) -> DropProposal? {
        .init(operation: .forbidden)
    }

    func performDrop(info: DropInfo) -> Bool { false }
}

/// Adds a tab to the top of the list
struct TopDropDelegate: DropDelegate {
    let container: TabContainer
    @Binding var targetedItem: TargetedDropItem?
    @Binding var draggedItem: UUID?
    let representative: DelegateTarget
    let section: TabType

    func dropEntered(info: DropInfo) {
        targetedItem = representative
            .toDropItem(withId: .zero)
    }

    func dropExited(info: DropInfo) {
        targetedItem = nil
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        .init(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        defer {
            draggedItem = nil
            targetedItem = nil
        }

        guard let provider = info.itemProviders(for: [.text]).first else { return false }
        performHapticFeedback(pattern: .alignment)
        provider.loadObject(ofClass: NSString.self) {
            object,
                _ in
            if let string = object as? String,
               let uuid = UUID(uuidString: string)
            {
                DispatchQueue.main.async {
                    // First try to find the tab in the target container
                    var from = container.tabs.first(where: { $0.id == uuid })

                    // If not found, try to find it in all containers of the same type
                    if from == nil {
                        // Look through all tabs in all containers to find the dragged tab
                        for container in container.tabs.compactMap(\.container).unique() {
                            if let foundTab = container.tabs.first(where: { $0.id == uuid }) {
                                from = foundTab
                                break
                            }
                        }
                    }

                    guard let from else { return }

                    withAnimation(
                        .spring(
                            response: 0.3,
                            dampingFraction: 0.8
                        )
                    ) {
                        container
                            .reorderTabs(
                                from: from,
                                to: section,
                                offsetTargetTypeOrder: true
                            )
                    }
                }
            }
        }
        return true
    }
}

enum GeneralDropDelegateItem {
    case tab(Tab), container(TabContainer)

    var container: TabContainer {
        switch self {
        case let .tab(tab):
            return tab.container
        case let .container(tabContainer):
            return tabContainer
        }
    }
}

struct GeneralDropDelegate: DropDelegate {
    let item: GeneralDropDelegateItem  // to
    let representative: DelegateTarget
    @Binding var draggedItem: UUID?
    @Binding var targetedItem: TargetedDropItem?

    let targetSection: TabType

    func dropEntered(info: DropInfo) {
        if case let .tab(tab) = item {
            targetedItem = representative.toDropItem(withId: tab.id)
        }
    }

    func dropExited(info: DropInfo) {
        targetedItem = nil
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        .init(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        defer {
            draggedItem = nil
            targetedItem = nil
        }

        guard let provider = info.itemProviders(for: [.text]).first else { return false }
        performHapticFeedback(pattern: .alignment)
        provider.loadObject(ofClass: NSString.self) {
            object,
                _ in
            if let string = object as? String,
               let uuid = UUID(uuidString: string)
            {
                if case let .tab(tab) = item {
                    if uuid == tab.id {
                        return
                    }

                    // No assigning a parent to its child
                    var itemParent = tab.parent
                    while let parent = itemParent {
                        if parent.id == uuid {
                            return
                        }
                        itemParent = parent.parent
                    }
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

                    withAnimation(
                        .spring(
                            response: 0.3,
                            dampingFraction: 0.8
                        )
                    ) {
                        switch item {
                        case let .tab(tab):
                            if case let .tab(tabset) = representative, tabset {
                                self.item.container
                                    .combineToTileset(
                                        withSourceTab: from,
                                        andDestinationTab: tab
                                    )
                            } else {
                                self.item.container
                                    .reorderTabs(
                                        from: from,
                                        to: tab,
                                        withReparentingBehavior: SettingsStore.shared.treeTabsEnabled ? representative
                                            .reparentingBehavior : .sibling
                                    )
                            }
                        case .container:
                            self.item.container
                                .reorderTabs(
                                    from: from,
                                    to: targetSection
                                )
                        }
                    }
                }
            }
        }
        return true
    }
}
