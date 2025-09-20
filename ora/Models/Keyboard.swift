import AppKit
import Carbon.HIToolbox
import SwiftUI

// MARK: - Model types

/// A semantic key combo (persistable key identity + modifiers) with computed vars
/// for a SwiftUI KeyboardShortcut and a display string.
struct KeyChord: Equatable, Codable {
    let keyEquivalent: KeyEquivalent
    let modifiers: SwiftUI.EventModifiers

    var keyboardShortcut: KeyboardShortcut { KeyboardShortcut(keyEquivalent, modifiers: modifiers) }

    // MARK: - String-based storage for Codable support

    /// The underlying character as String for Codable support
    private let characterString: String

    /// Initialize from character string (used internally for Codable)
    private init(characterString: String, modifiers: SwiftUI.EventModifiers) {
        self.characterString = characterString
        self.keyEquivalent = KeyEquivalent(Character(characterString))
        self.modifiers = modifiers
    }

    var display: String {
        var parts: [String] = []
        // Display order: control, option, shift, command (follows macOS convention)
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        parts.append(keyEquivalent.display)
        return parts.joined()
    }

    init(keyEquivalent: KeyEquivalent, modifiers: SwiftUI.EventModifiers) {
        self.keyEquivalent = keyEquivalent
        self.modifiers = modifiers
        self.characterString = String(keyEquivalent.character)
    }

    init?(fromEvent event: NSEvent) {
        var mods: SwiftUI.EventModifiers = []
        let flags = event.modifierFlags
        if flags.contains(.command) { mods.insert(.command) }
        if flags.contains(.option) { mods.insert(.option) }
        if flags.contains(.shift) { mods.insert(.shift) }
        if flags.contains(.control) { mods.insert(.control) }

        // Convert NSEvent to KeyEquivalent directly
        let keyEquivalent: KeyEquivalent
        switch event.keyCode {
        case UInt16(kVK_Tab): keyEquivalent = .tab
        case UInt16(kVK_LeftArrow): keyEquivalent = .leftArrow
        case UInt16(kVK_RightArrow): keyEquivalent = .rightArrow
        case UInt16(kVK_DownArrow): keyEquivalent = .downArrow
        case UInt16(kVK_UpArrow): keyEquivalent = .upArrow
        case UInt16(kVK_Escape): keyEquivalent = .escape
        case UInt16(kVK_Return): keyEquivalent = .return
        case UInt16(kVK_Space): keyEquivalent = .space
        case UInt16(kVK_Delete): keyEquivalent = .delete
        case UInt16(kVK_ForwardDelete): keyEquivalent = .deleteForward
        default:
            // For character keys, use the character directly
            if let chars = event.charactersIgnoringModifiers, let first = chars.first {
                keyEquivalent = KeyEquivalent(first)
            } else {
                return nil
            }
        }

        self.keyEquivalent = keyEquivalent
        self.modifiers = mods
        self.characterString = String(keyEquivalent.character)
    }

    // Codable Support

    private enum CodingKeys: String, CodingKey {
        case characterString, modifiers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.characterString = try container.decode(String.self, forKey: .characterString)
        let rawModifiers = try container.decode(Int.self, forKey: .modifiers)
        self.modifiers = SwiftUI.EventModifiers(rawValue: rawModifiers)
        self.keyEquivalent = KeyEquivalent(Character(characterString))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(characterString, forKey: .characterString)
        try container.encode(modifiers.rawValue, forKey: .modifiers)
    }
}

/// A keyboard shortcut definition with all necessary information
struct KeyboardShortcutDefinition: Identifiable, Equatable {
    let id: String
    let name: String
    let category: String
    let defaultChord: KeyChord

    /// Current chord (either custom override or default)
    var currentChord: KeyChord {
        if let custom = CustomKeyboardShortcutManager.shared.getShortcut(id: id) {
            return custom
        }
        return defaultChord
    }

    /// SwiftUI KeyboardShortcut for use in views
    var keyboardShortcut: KeyboardShortcut {
        currentChord.keyboardShortcut
    }

    /// Display string for the current shortcut (used in settings UI)
    var display: String {
        currentChord.display
    }
}

// MARK: - KeyEquivalent Display Extension

extension KeyEquivalent {
    var display: String {
        switch self {
        case .tab: return "⇥"
        case .leftArrow: return "←"
        case .rightArrow: return "→"
        case .downArrow: return "↓"
        case .upArrow: return "↑"
        case .escape: return "⎋"
        case .return: return "↩"
        case .space: return "␣"
        case .delete: return "⌫"
        case .deleteForward: return "⌦"
        default:
            // For character keys, return uppercased
            return String(character).uppercased()
        }
    }
}
