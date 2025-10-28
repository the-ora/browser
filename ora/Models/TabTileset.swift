//
//  TabTileset.swift
//  ora
//
//  Created by Jack Hogan on 28/10/25.
//

import Foundation
import SwiftData

@Model
class TabTileset: ObservableObject, Identifiable {
    var id: UUID

    var tabs: [Tab]

    init(id: UUID = UUID(), tabs: [Tab]) {
        self.id = id
        self.tabs = tabs
    }

    func deparentTabs() {
        for tab in tabs {
            tab.dissociateFromRelatives()
        }
    }
}
