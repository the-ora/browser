import SwiftUI
import AppKit

// MARK: - Model types

struct ShortcutItem: Identifiable, Equatable {
    let id: String
    let name: String
    let display: String
}

/// A semantic key combo (persistable key identity + modifiers) with computed vars
/// for a SwiftUI KeyboardShortcut and a display string.
struct KeyChord: Equatable {
    let key: StoredKey
    let modifiers: EventModifiers

    var keyboardShortcut: KeyboardShortcut { KeyboardShortcut(key.keyEquivalent, modifiers: modifiers) }

    var display: String {
        var parts: [String] = []
        // Display order: control, option, shift, command (follows macOS convention)
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        parts.append(key.display)
        return parts.joined()
    }
    
    init(key: StoredKey, modifiers: EventModifiers) {
        self.key = key
        self.modifiers = modifiers
    }

    init?(fromEvent event: NSEvent) {
        var mods: EventModifiers = []
        let flags = event.modifierFlags
        if flags.contains(.command) { mods.insert(.command) }
        if flags.contains(.option) { mods.insert(.option) }
        if flags.contains(.shift) { mods.insert(.shift) }
        if flags.contains(.control) { mods.insert(.control) }
        self = KeyChord(key: StoredKey.from(event: event), modifiers: mods)
    }
}

// MARK: - Persistable key identity

enum StoredKey: Codable, Equatable {
    case special(Special)
    case char(String)

    enum CodingKeys: String, CodingKey { case type, value }
    enum Kind: String, Codable { case special, char }

    enum Special: String, Codable, Equatable {
        case tab, leftArrow, rightArrow, upArrow, downArrow, escape, returnKey, space, delete

        var keyEquivalent: KeyEquivalent {
            switch self {
            case .tab: return .tab
            case .leftArrow: return .leftArrow
            case .rightArrow: return .rightArrow
            case .upArrow: return .upArrow
            case .downArrow: return .downArrow
            case .escape: return .escape
            case .returnKey: return .return
            case .space: return .space
            case .delete: return .delete
            }
        }

        var display: String {
            switch self {
            case .tab: return "⇥"
            case .leftArrow: return "←"
            case .rightArrow: return "→"
            case .upArrow: return "↑"
            case .downArrow: return "↓"
            case .escape: return "⎋"
            case .returnKey: return "↩"
            case .space: return "␣"
            case .delete: return "⌫"
            }
        }

        static func fromKeyCode(_ keyCode: UInt16) -> Special? {
            switch keyCode {
            case 48: return .tab
            case 123: return .leftArrow
            case 124: return .rightArrow
            case 125: return .downArrow
            case 126: return .upArrow
            case 53: return .escape
            case 36: return .returnKey
            case 49: return .space
            case 51: return .delete
            default: return nil
            }
        }
    }

    static func from(event: NSEvent) -> StoredKey {
        if let special = Special.fromKeyCode(event.keyCode) {
            return .special(special)
        }
        if let chars = event.charactersIgnoringModifiers, let first = chars.first {
            return .char(String(first))
        }
        //TODO: Fix default fallback/make optional (should be rare)
        return .special(.escape)
    }

    // Codable
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(Kind.self, forKey: .type)
        switch type {
        case .special:
            let value = try container.decode(Special.self, forKey: .value)
            self = .special(value)
        case .char:
            let value = try container.decode(String.self, forKey: .value)
            self = .char(value)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .special(let value):
            try container.encode(Kind.special, forKey: .type)
            try container.encode(value, forKey: .value)
        case .char(let value):
            try container.encode(Kind.char, forKey: .type)
            try container.encode(value, forKey: .value)
        }
    }
}

extension StoredKey {
    var keyEquivalent: KeyEquivalent {
        switch self {
        case .special(let s):
            return s.keyEquivalent
        case .char(let s):
            guard let first = s.first else { return .escape }
            return KeyEquivalent(first)
        }
    }

    var display: String {
        switch self {
        case .special(let s):
            return s.display
        case .char(let s):
            return s.uppercased()
        }
    }
}

// MARK: - Persistent custom shortcut

struct CustomKeyboardShortcut: Identifiable, Codable {
    let id: String
    let key: StoredKey
    let modifierFlags: UInt

    init(id: String, event: NSEvent) {
        self.id = id
        self.key = StoredKey.from(event: event)
        self.modifierFlags = event.modifierFlags.rawValue
    }

    var nsModifierFlags: NSEvent.ModifierFlags { .init(rawValue: modifierFlags) }

    var keyChord: KeyChord? {
        var mods: EventModifiers = []
        let flags = nsModifierFlags
        if flags.contains(.command) { mods.insert(.command) }
        if flags.contains(.option) { mods.insert(.option) }
        if flags.contains(.shift) { mods.insert(.shift) }
        if flags.contains(.control) { mods.insert(.control) }
        return KeyChord(key: key, modifiers: mods)
    }
}

protocol ShortcutProviding: RawRepresentable, Identifiable, CaseIterable {
    static var category: String { get }
    static var allItems: [ShortcutItem] { get }
    
    var rawValue: String { get }
    var id: String { get }
    var name: String { get }
    var category: String { get }
    var defaultChord: KeyChord { get }
    var currentChord: KeyChord { get }
    var keyboardShortcut: KeyboardShortcut { get }
    var item: ShortcutItem { get }
}

extension ShortcutProviding {
    /// Unique ID ("tabs.new" or "navigation.back")
    var id: String { "\(Self.category.lowercased()).\(String(describing: self))" }
    /// Name for display ("New Tab" or "Back")
    var name: String { rawValue }
    /// Category for display in Settings ("Tabs" or "Navigation")
    var category: String { Self.category }
    /// Either the custom key chord if set or the default
    var currentChord: KeyChord {
        if let custom = CustomKeyboardShortcutManager.shared.getShortcut(id: id),
           let chord = custom.keyChord {
            return chord
        }
        return defaultChord
    }
    /// KeyboardShortcut generated from the current KeyChord
    var keyboardShortcut: KeyboardShortcut { currentChord.keyboardShortcut }
    /// ShortcutItem to display in Settings
    var item: ShortcutItem {
        ShortcutItem(
            id: id,
            name: name,
            display: currentChord.display
        )
    }
    
    static var allItems: [ShortcutItem] {
        return allCases.map({ $0.item })
    }
}

enum KeyboardShortcuts {
    enum Tabs: String, ShortcutProviding {
        static let category = "Tabs"
        
        case new = "New Tab"
        case close = "Close Tab"
        case restore = "Restore Tab"
        case reopenClosed = "Reopen Closed Tab"
        case next = "Next Tab"
        case previous = "Previous Tab"
        case moveRight = "Move Tab Right"
        case moveLeft = "Move Tab Left"
        case pin = "Pin Tab"
        case tab1 = "Tab 1"
        case tab2 = "Tab 2"
        case tab3 = "Tab 3"
        case tab4 = "Tab 4"
        case tab5 = "Tab 5"
        case tab6 = "Tab 6"
        case tab7 = "Tab 7"
        case tab8 = "Tab 8"
        case tab9 = "Tab 9"
        
        var defaultChord: KeyChord {
            switch self {
                case .new: KeyChord(key: .char("t"), modifiers: [.command])
                case .close: KeyChord(key: .char("w"), modifiers: [.command])
                case .restore: KeyChord(key: .char("z"), modifiers: [.command])
                case .reopenClosed: KeyChord(key: .char("t"), modifiers: [.command, .shift])
                case .next: KeyChord(key: .special(.tab), modifiers: [.control])
                case .previous: KeyChord(key: .special(.tab), modifiers: [.control, .shift])
                case .moveRight: KeyChord(key: .special(.rightArrow), modifiers: [.option, .command])
                case .moveLeft: KeyChord(key: .special(.leftArrow), modifiers: [.option, .command])
                case .pin: KeyChord(key: .char("d"), modifiers: [.command])
                case .tab1: KeyChord(key: .char("1"), modifiers: [.command])
                case .tab2: KeyChord(key: .char("2"), modifiers: [.command])
                case .tab3: KeyChord(key: .char("3"), modifiers: [.command])
                case .tab4: KeyChord(key: .char("4"), modifiers: [.command])
                case .tab5: KeyChord(key: .char("5"), modifiers: [.command])
                case .tab6: KeyChord(key: .char("6"), modifiers: [.command])
                case .tab7: KeyChord(key: .char("7"), modifiers: [.command])
                case .tab8: KeyChord(key: .char("8"), modifiers: [.command])
                case .tab9: KeyChord(key: .char("9"), modifiers: [.command])
            }
        }
    }
    
    enum Navigation: String, ShortcutProviding {
        static let category = "Navigation"
        
        case back = "Back"
        case forward = "Forward"
        case reload = "Reload"
        case hardReload = "Hard Reload"
        
        var defaultChord: KeyChord {
            switch self {
                case .back: KeyChord(key: .char("["), modifiers: [.command])
                case .forward: KeyChord(key: .char("]"), modifiers: [.command])
                case .reload: KeyChord(key: .char("r"), modifiers: [.command])
                case .hardReload: KeyChord(key: .char("r"), modifiers: [.command, .shift])
            }
        }
    }
    
    enum Window: String, ShortcutProviding {
        static let category = "Window"
        
        case new = "New"
        case newPrivate = "New Private"
        case close = "Close"
        case fullscreen = "Fullscreen"
        
        var defaultChord: KeyChord {
            switch self {
                case .new: KeyChord(key: .char("n"), modifiers: [.command])
                case .newPrivate: KeyChord(key: .char("n"), modifiers: [.command, .shift])
                case .close: KeyChord(key: .char("w"), modifiers: [.command, .shift])
                case .fullscreen: KeyChord(key: .char("f"), modifiers: [.command, .control])
            }
        }
    }

    enum Address: String, ShortcutProviding {
        static let category = "Address"
        
        case copyURL = "Copy URL"
        case focus = "Focus"
        
        var defaultChord: KeyChord {
            switch self {
                case .copyURL: KeyChord(key: .char("c"), modifiers: [.command, .shift])
                case .focus: KeyChord(key: .char("l"), modifiers: [.command])
            }
        }
    }
    
    enum Edit: String, ShortcutProviding {
        static let category = "Edit"
        
        case find = "Find"
        case findNext = "Find Next"
        case findPrevious = "Find Previous"
        
        var defaultChord: KeyChord {
            switch self {
                case .find: KeyChord(key: .char("f"), modifiers: [.command])
                case .findNext: KeyChord(key: .char("g"), modifiers: [.command])
                case .findPrevious: KeyChord(key: .char("g"), modifiers: [.command, .shift])
            }
        }
    }
    
    enum History: String, ShortcutProviding {
        static let category = "History"
        
        case show = "Show History"
        
        var defaultChord: KeyChord {
            switch self {
                case .show: KeyChord(key: .char("y"), modifiers: [.command])
            }
        }
    }

    enum Zoom: String, ShortcutProviding {
        static let category = "Zoom"
        
        case zoomIn = "Zoom In"
        case zoomOut = "Zoom Out"
        case reset = "Reset Zoom"
        
        var defaultChord: KeyChord {
            switch self {
                case .zoomIn: KeyChord(key: .char("+"), modifiers: [.command])
                case .zoomOut: KeyChord(key: .char("-"), modifiers: [.command])
                case .reset: KeyChord(key: .char("0"), modifiers: [.command])
            }
        }
    }
    
    enum Developer: String, ShortcutProviding {
        static let category = "Developer"
        
        case toggleDevTools = "Toggle DevTools"
        case reloadIgnoringCache = "Reload (Ignoring Cache)"
        
        var defaultChord: KeyChord {
            switch self {
                case .toggleDevTools: KeyChord(key: .char("i"), modifiers: [.command, .option])
                case .reloadIgnoringCache: KeyChord(key: .char("r"), modifiers: [.command, .shift])
            }
        }
    }
    
    enum App: String, ShortcutProviding {
        static let category = "App"
        
        case quit = "Quit"
        case hide = "Hide"
        case preferences = "Preferences"
        case toggleSidebar = "Toggle Sidebar"
        case toggleToolbar = "Toggle Toolbar"
        
        var defaultChord: KeyChord {
            switch self {
                case .quit: KeyChord(key: .char("q"), modifiers: [.command])
                case .hide: KeyChord(key: .char("h"), modifiers: [.command])
                case .preferences: KeyChord(key: .char(","), modifiers: [.command])
                case .toggleSidebar: KeyChord(key: .char("s"), modifiers: [.command])
                case .toggleToolbar: KeyChord(key: .char("d"), modifiers: [.command, .shift])
            }
        }
    }

    static var itemsByCategory: [(category: String, items: [ShortcutItem])] {
        //TODO: Make this more dynamic, potentially refactor away from grouped enums
        return [
            (Tabs.category, Tabs.allItems),
            (Navigation.category, Navigation.allItems),
            (Window.category, Window.allItems),
            (Address.category, Address.allItems),
            (Edit.category, Edit.allItems),
            (History.category, History.allItems),
            (Developer.category, Developer.allItems),
            (App.category, App.allItems),
        ].sorted { $0.category.caseInsensitiveCompare($1.category) == .orderedAscending }
    }
}
