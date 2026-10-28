import SwiftUI

enum TabSection {
    case fav
    case pinned
    case normal
}

// MARK: - Tab Utility Functions

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
