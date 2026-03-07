import AppKit
import SwiftUI

/// Utility functions for clipboard operations
enum ClipboardUtils {
    /// Copies the given text to the system clipboard
    static func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Triggers copy with animation states
    /// - Parameters:
    ///   - text: The text to copy
    ///   - showCopiedAnimation: Binding to control animation visibility
    ///   - startWheelAnimation: Binding to control wheel animation
    static func triggerCopy(
        _ text: String,
        showCopiedAnimation: Binding<Bool>,
        startWheelAnimation: Binding<Bool>
    ) {
        // Prevent double-trigger if both Command and view shortcut fire
        if showCopiedAnimation.wrappedValue { return }
        copyToClipboard(text)
        withAnimation {
            showCopiedAnimation.wrappedValue = true
            startWheelAnimation.wrappedValue = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation {
                showCopiedAnimation.wrappedValue = false
                startWheelAnimation.wrappedValue = false
            }
        }
    }
}
