import Foundation

class ToolbarManager: ObservableObject {
    @Published var isToolbarHidden: Bool = false
    @Published var showFullURL: Bool = (UserDefaults.standard.object(forKey: "showFullURL") as? Bool) ?? true {
        didSet { UserDefaults.standard.set(showFullURL, forKey: "showFullURL") }
    }
}
