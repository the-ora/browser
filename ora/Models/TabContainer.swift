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
        // Get all tabs of the same type, sorted by current order (descending)
        let sameTypeTabs = tabs.filter { $0.type == from.type }.sorted(by: { $0.order > $1.order })

        // Find positions in the sorted array
        guard let fromIndex = sameTypeTabs.firstIndex(where: { $0.id == from.id }),
              let toIndex = sameTypeTabs.firstIndex(where: { $0.id == to.id })
        else {
            return
        }

        // Handle the special case where we're moving a tab to after the last position
        // If from and to are the same tab, or if we're moving the last tab, we need special handling
        let newToIndex: Int
        if from.id == to.id {
            // Moving to the same position - do nothing
            return
        } else if fromIndex < toIndex {
            // Moving forward in the list (down in UI)
            newToIndex = toIndex
        } else {
            // Moving backward in the list (up in UI)
            newToIndex = toIndex
        }

        // Create a new array with the tabs in the desired order
        var reorderedTabs = sameTypeTabs
        let movedTab = reorderedTabs.remove(at: fromIndex)
        reorderedTabs.insert(movedTab, at: newToIndex)

        // Update the order values for all tabs of this type
        let baseOrder = sameTypeTabs.first?.order ?? 1000
        for (index, tab) in reorderedTabs.enumerated() {
            tab.order = baseOrder - index
        }
    }
}
