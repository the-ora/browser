import Foundation
import SwiftData

// MARK: - TabContainer

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

    func reorderTabs(from: Tab, to: Tab) {
        let dir = from.order - to.order > 0 ? -1 : 1

        let tabOrder = self.tabs.sorted { dir == -1 ? $0.order > $1.order : $0.order < $1.order }

        var started = false
        for (index, tab) in tabOrder.enumerated() {
            if tab.id == from.id {
                started = true
            }
            if tab.id == to.id {
                break
            }
            if started {
                let currentTab = tab
                let nextTab = tabOrder[index + 1]

                let tempOrder = currentTab.order
                currentTab.order = nextTab.order
                nextTab.order = tempOrder
            }
        }
    }
}
