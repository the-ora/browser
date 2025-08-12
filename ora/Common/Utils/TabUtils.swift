import SwiftUI

enum TabSection {
    case fav
    case pinned
    case normal
}

// MARK: - Tab Utility Functions

/// Determines if two tabs are in the same section
func isInSameSection(from: Tab, to: Tab) -> Bool {
    return section(for: from) == section(for: to)
}

/// Gets the section for a given tab based on its type
func section(for tab: Tab) -> TabSection {
    switch tab.type {
    case .fav: return .fav
    case .pinned: return .pinned
    case .normal: return .normal
    }
}

/// Converts a TabSection to corresponding TabType
func tabType(for section: TabSection) -> TabType {
    switch section {
    case .fav: return .fav
    case .pinned: return .pinned
    case .normal: return .normal
    }
}

/// Moves a tab between different sections
func moveTabBetweenSections(from: Tab, to: Tab) {
    from.switchSections(from: from, to: to)
    from.container.reorderTabs(from: from, to: to)
}
