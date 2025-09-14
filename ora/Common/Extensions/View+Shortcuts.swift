import SwiftUI

// Attach app shortcuts that update as overrides change.
private struct OraKeyboardShortcutModifier<Shortcut: ShortcutProviding>: ViewModifier {
    let shortcut: Shortcut
    @EnvironmentObject private var shortcutManager: CustomKeyboardShortcutManager

    func body(content: Content) -> some View {
        content
            .keyboardShortcut(shortcut.keyboardShortcut)
    }
}

// Attach a tooltip that includes the current shortcut display.
private struct OraShortcutHelpModifier<Shortcut: ShortcutProviding>: ViewModifier {
    let helpText: String //TODO - Add localized string support
    let shortcut: Shortcut
    @EnvironmentObject private var shortcutManager: CustomKeyboardShortcutManager

    func body(content: Content) -> some View {
        content
            .help("\(helpText) (\(shortcut.currentChord.display))")
    }
}

extension View {
    /// Use in place of `.keyboardShortcut(AppShortcut.xyz.keyboardShortcut)` to auto-update on changes.
    func oraShortcut(_ shortcut: some ShortcutProviding) -> some View {
        modifier(OraKeyboardShortcutModifier(shortcut: shortcut))
    }

    /// Helper to keep tooltips in sync with the current shortcut mapping.
    /// Results in a tooltip like: "Copy URL (⇧⌘C)"
    func oraShortcutHelp(_ helpText: String, for shortcut: some ShortcutProviding) -> some View {
        modifier(OraShortcutHelpModifier(helpText: helpText, shortcut: shortcut))
    }
}

