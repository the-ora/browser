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

    private func pushTabs(in tab: Tab?, startingAfter idx: Int, _ amount: Int = 1) {
        for tab in tab?.children ?? tabs {
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

    func combineToTileset(withSourceTab src: Tab, andDestinationTab dst: Tab) {
        // Remove from tabset if exists
        removeTabFromTileset(tab: src)

        if let tabset = tilesets.first(where: { $0.tabs.contains(dst) }) {
            tabset.tabs.append(src)
            reorderTabs(from: src, to: tabset.tabs.last!, withReparentingBehavior: .sibling)
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
        }
    }

    func bringToTop(tab target: Tab) {
        for tab in tabs {
            if tab.order > target.order {
                tab.order -= 1
            } else {
                tab.order += 1
            }
        }
        target.order = 0
    }

    func reorderTabs(
        from: Tab,
        to: Tab,
        withReparentingBehavior reparentingBehavior: ReparentingBehavior = .sibling
    ) {
        let containingTilesetTabs = tilesets.first(where: { $0.tabs.contains(from) })?.tabs ?? [from]
        let numRelevantTabs = containingTilesetTabs.count

        from.dissociateFromRelatives()
        switch reparentingBehavior {
        case .sibling:
            to.parent?.children.insert(from, at: 0)
            pushTabs(in: to.parent, startingAfter: to.order, numRelevantTabs)
            for (i, tab) in containingTilesetTabs.enumerated() {
                tab.order = to.order + 1 + i
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

    func flattenTabs() {
        for tab in tabs {
            tab.parent = nil
        }
    }
}
