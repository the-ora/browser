import SwiftUI

enum MoveDirection {
    case up
    case down
}

struct LauncherMouseHasMovedKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var launcherMouseHasMoved: Bool {
        get { self[LauncherMouseHasMovedKey.self] }
        set { self[LauncherMouseHasMovedKey.self] = newValue }
    }
}
