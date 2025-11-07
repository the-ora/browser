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

    @Relationship(deleteRule: .cascade) var tilesets: [TabTileset] = []
    @Relationship(deleteRule: .cascade) private(set) var tabs: [Tab] = []
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

    private func pushTabs(
        in tab: Tab?,
        ofType type: TabType, startingAfter idx: Int,
        _ amount: Int = 1
    ) {
        for tab in tab?.children ?? tabs where tab.type == type {
            if tab.order > idx {
                tab.order += amount
            }
        }
    }

    func addTab(_ tab: Tab) {
        var orderBase: Int
        if SettingsStore.shared.treeTabsEnabled {
            orderBase = (tab.parent?.children ?? tabs).map(\.order).max() ?? -1
        } else if let parent = tab.parent {
            orderBase = parent.order
            pushTabs(
                in: nil,
                ofType: tab.type,
                startingAfter: parent.order
            )
        } else {
            orderBase = tabs.map(\.order).max() ?? -1
        }

        if !SettingsStore.shared.treeTabsEnabled {
            tab.parent = nil
        }

        tab.order = orderBase + 1
        tabs.append(tab)
    }

    func removeTabFromTileset(tab: Tab) {
        guard tab.tileset != nil else { return }
        for (i, tileset) in tilesets.enumerated() {
            if let tabIndex = tileset.tabs.firstIndex(of: tab) {
                tileset.tabs.remove(at: tabIndex)
                if tileset.tabs.count <= 1 {
                    tilesets.remove(at: i)
                }
                break
            }
        }
        tab.tileset = nil
    }

    // TODO: Handle combining two tilesets
    func combineToTileset(withSourceTab src: Tab, andDestinationTab dst: Tab) {
        // Remove from tabset if exists
        removeTabFromTileset(tab: src)

        if let tabset = tilesets.first(where: { $0.tabs.contains(dst) }) {
            reorderTabs(from: src, to: tabset.tabs.last!, withReparentingBehavior: .sibling)
            tabset.tabs.append(src)
        } else {
            reorderTabs(from: src, to: dst, withReparentingBehavior: .sibling)
            let ts = TabTileset(tabs: [])
            tilesets.append(ts)
            ts.tabs = [src, dst]
        }
    }

    func moveTab(_ tab: Tab, toSection section: TabType) {
        let tabset = tilesets.first(where: { $0.tabs.contains(tab) })?.tabs ?? [tab]
        for tab in tabset {
            tab.switchSections(to: section)
            if [.pinned, .fav].contains(section) {
                tab.abandonChildren()
            }
        }
    }

    func reorderTabs(
        from: Tab,
        to: Tab,
        withReparentingBehavior reparentingBehavior: ReparentingBehavior = .sibling
    ) {
        let containingTilesetTabs = tilesets.first(where: { $0.tabs.contains(from) })?.tabs ?? [from]
        let numRelevantTabs = containingTilesetTabs.count
        reorderTabs(from: from, to: to.type)

        switch reparentingBehavior {
        case .sibling:
            if let parent = to.parent {
                parent.children.insert(from, at: 0)
                from.parent = parent
            } else {
                from.parent = nil
            }
            // Find the highest tab in the tileset to push after
            let maxToTilesetOrder = tilesets.first(where: { $0.tabs.contains(to) })?.tabs.map(\.order).max() ?? to.order

            pushTabs(
                in: to.parent,
                ofType: to.type,
                startingAfter: maxToTilesetOrder,
                numRelevantTabs
            )
            for (i, tab) in containingTilesetTabs.enumerated() {
                tab.order = maxToTilesetOrder + 1 + i
            }
        case .child:
            to.children.insert(from, at: 0)
            for (i, tab) in containingTilesetTabs.enumerated() {
                tab.order = -containingTilesetTabs.count + i
            }
            for child in to.children {
                child.order += numRelevantTabs
            }
        }
    }

    func reorderTabs(from: Tab, to: TabType, offsetTargetTypeOrder: Bool = false) {
        let containingTilesetTabs = tilesets.first(where: { $0.tabs.contains(from) })?.tabs ?? [from]

        containingTilesetTabs.forEach { $0.dissociateFromRelatives() }

        if from.type != to {
            moveTab(from, toSection: to)
        }
        if offsetTargetTypeOrder {
            for tab in tabs where tab.type == to {
                tab.order += containingTilesetTabs.count
            }
        }
        for (i, tab) in containingTilesetTabs.enumerated() {
            tab.order = i
        }
    }

    func flattenTabs() {
        for tab in tabs {
            tab.parent = nil
        }
    }
}
