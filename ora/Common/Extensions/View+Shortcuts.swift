import SwiftUI

// Attach app shortcuts that update as overrides change.
private struct OraKeyboardShortcutModifier: ViewModifier {
    let shortcut: KeyboardShortcutDefinition
    @EnvironmentObject private var shortcutManager: CustomKeyboardShortcutManager

    func body(content: Content) -> some View {
        content
            .keyboardShortcut(shortcut.keyboardShortcut)
    }
}

// Attach a tooltip that includes the current shortcut display.
private struct OraShortcutHelpModifier: ViewModifier {
    let helpText: String
    let shortcut: KeyboardShortcutDefinition
    @EnvironmentObject private var shortcutManager: CustomKeyboardShortcutManager

    func body(content: Content) -> some View {
        content
            .help("\(helpText) (\(shortcut.currentChord.display))")
    }
}

extension View {
    /// Use in place of `.keyboardShortcut` to auto-update on custom shortcut changes.
    func oraShortcut(_ shortcut: KeyboardShortcutDefinition) -> some View {
        modifier(OraKeyboardShortcutModifier(shortcut: shortcut))
    }

    /// Helper to keep tooltips in sync with the current shortcut mapping.
    /// Results in a tooltip like: "Copy URL (⇧⌘C)"
    func oraShortcutHelp(_ helpText: String, for shortcut: KeyboardShortcutDefinition) -> some View {
        modifier(OraShortcutHelpModifier(helpText: helpText, shortcut: shortcut))
    }
}
