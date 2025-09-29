import AppKit
import SwiftUI

private struct WindowEnvironmentKey: EnvironmentKey {
    static let defaultValue: NSWindow? = nil
}

extension EnvironmentValues {
    var window: NSWindow? {
        get { self[WindowEnvironmentKey.self] }
        set { self[WindowEnvironmentKey.self] = newValue }
    }
}
