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
        from.deparent()
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
    }
}
