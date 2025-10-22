import Foundation
import SwiftData

// MARK: - TabContainer

enum ReparentingBehavior {
    case sibling, child
}

@Model
class TabContainer: ObservableObject, Identifiable {
    var id: UUID
    var name: String
    var emoji: String
    var createdAt: Date
    var lastAccessedAt: Date

    @Relationship(deleteRule: .cascade) var tabs: [Tab] = []
    @Relationship(deleteRule: .cascade) var folders: [Folder] = []
    @Relationship() var history: [History] = []

    init(
        id: UUID = UUID(),
        name: String = "Default",
        isActive: Bool = true,
        emoji: String = "💩"
    ) {
        let nowDate = Date()
        self.id = id
        self.name = name
        self.emoji = emoji
        self.createdAt = nowDate
        self.lastAccessedAt = nowDate
    }

    private func pushTabs(in tab: Tab, startingAfter idx: Int) {
        for tab in tab.children {
            if tab.order > idx {
                tab.order += 1
            }
        }
    }

    func reorderTabs(
        from: Tab,
        to: Tab,
        withReparentingBehavior reparentingBehavior: ReparentingBehavior = .sibling
    ) {
        if let parent = from.parent {
            parent.children.removeAll(where: { $0.id == from.id })
            for child in parent.children {
                if child.order > from.order {
                    child.order -= 1
                }
            }
        }
        switch reparentingBehavior {
        case .sibling:
            to.parent?.children.insert(from, at: 0)
            if let parent = to.parent {
                pushTabs(in: parent, startingAfter: to.order)
            }
            from.order = to.order + 1
        case .child:
            to.children.insert(from, at: 0)
            from.order = -1
            for child in to.children {
                child.order += 1
            }
        }

//        let dir = from.order - to.order > 0 ? -1 : 1
//
//        let tabOrder = self.tabs.sorted { dir == -1 ? $0.order > $1.order : $0.order < $1.order }
//
//        var started = false
//        for (index, tab) in tabOrder.enumerated() {
//            if tab.id == from.id {
//                started = true
//            }
//            if tab.id == to.id {
//                break
//            }
//            if started {
//                let currentTab = tab
//                let nextTab = tabOrder[index + 1]
//
//                let tempOrder = currentTab.order
//                currentTab.order = nextTab.order
//                nextTab.order = tempOrder
//            }
//        }
    }
}
