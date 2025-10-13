import Foundation
import SwiftUI

class ToolbarManager: ObservableObject {
    @AppStorage("ui.toolbar.hidden") var isToolbarHidden: Bool = false
    @AppStorage("ui.toolbar.showfullurl") var showFullURL: Bool = true
}
