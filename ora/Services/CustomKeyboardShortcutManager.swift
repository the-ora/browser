import Foundation
import AppKit

class CustomKeyboardShortcutManager: ObservableObject {
    static let shared = CustomKeyboardShortcutManager()

    @Published private(set) var customShortcuts: [String: CustomKeyboardShortcut] = [:]

    private let settingsStore = SettingsStore.shared

    private init() {
        loadCustomShortcuts()
    }

    private func loadCustomShortcuts() {
        customShortcuts = settingsStore.customKeyboardShortcuts
    }

    func setCustomShortcut(for item: ShortcutItem, event: NSEvent) {
        let customShortcut = CustomKeyboardShortcut(id: item.id, event: event)
        customShortcuts[item.id] = customShortcut
        settingsStore.setCustomKeyboardShortcut(customShortcut)
    }

    func removeCustomShortcut(for item: ShortcutItem) {
        customShortcuts.removeValue(forKey: item.id)
        settingsStore.removeCustomKeyboardShortcut(id: item.id)
    }

    func getShortcut(id: String) -> CustomKeyboardShortcut? {
        return customShortcuts[id]
    }

    func hasCustomShortcut(for item: ShortcutItem) -> Bool {
        return customShortcuts[item.id] != nil
    }
}
