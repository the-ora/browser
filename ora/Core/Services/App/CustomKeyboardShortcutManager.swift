import AppKit
import Foundation

class CustomKeyboardShortcutManager: ObservableObject {
    static let shared = CustomKeyboardShortcutManager()

    @Published private(set) var customShortcuts: [String: KeyChord] = [:]

    private let settingsStore = SettingsStore.shared

    private init() {
        loadCustomShortcuts()
    }

    private func loadCustomShortcuts() {
        customShortcuts = settingsStore.customKeyboardShortcuts
    }

    func setCustomShortcut(for shortcut: KeyboardShortcutDefinition, event: NSEvent) {
        if let keyChord = KeyChord(fromEvent: event) {
            customShortcuts[shortcut.id] = keyChord
            settingsStore.setCustomKeyboardShortcut(id: shortcut.id, keyChord: keyChord)
        }
    }

    func removeCustomShortcut(for shortcut: KeyboardShortcutDefinition) {
        customShortcuts.removeValue(forKey: shortcut.id)
        settingsStore.removeCustomKeyboardShortcut(id: shortcut.id)
    }

    func getShortcut(id: String) -> KeyChord? {
        return customShortcuts[id]
    }

    func hasCustomShortcut(for shortcut: KeyboardShortcutDefinition) -> Bool {
        return customShortcuts[shortcut.id] != nil
    }
}
