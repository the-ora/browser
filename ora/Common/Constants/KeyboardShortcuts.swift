import SwiftUI

struct ShortcutItem: Identifiable {
    let id = UUID()
    let category: String
    let name: String
    let display: String
}

enum KeyboardShortcuts {
    enum Tabs {
        static let new = KeyboardShortcut("t", modifiers: [.command])
        static let close = KeyboardShortcut("w", modifiers: [.command])
        static let restore = KeyboardShortcut("z", modifiers: [.command])
        static let reopenClosed = KeyboardShortcut("t", modifiers: [.command, .shift])
        static let next = KeyboardShortcut(.tab, modifiers: [.control])
        static let previous = KeyboardShortcut(.tab, modifiers: [.control, .shift])
        static let nextAlt = KeyboardShortcut("]", modifiers: [.command, .shift])
        static let previousAlt = KeyboardShortcut("[", modifiers: [.command, .shift])
        static let moveRight = KeyboardShortcut(.rightArrow, modifiers: [.option, .command])
        static let moveLeft = KeyboardShortcut(.leftArrow, modifiers: [.option, .command])
        static let pin = KeyboardShortcut("d", modifiers: [.command])

        static let tab1 = KeyboardShortcut("1", modifiers: [.command])
        static let tab2 = KeyboardShortcut("2", modifiers: [.command])
        static let tab3 = KeyboardShortcut("3", modifiers: [.command])
        static let tab4 = KeyboardShortcut("4", modifiers: [.command])
        static let tab5 = KeyboardShortcut("5", modifiers: [.command])
        static let tab6 = KeyboardShortcut("6", modifiers: [.command])
        static let tab7 = KeyboardShortcut("7", modifiers: [.command])
        static let tab8 = KeyboardShortcut("8", modifiers: [.command])
        static let tab9 = KeyboardShortcut("9", modifiers: [.command])
    }

    enum Navigation {
        static let back = KeyboardShortcut("[", modifiers: [.command])
        static let forward = KeyboardShortcut("]", modifiers: [.command])
        static let reload = KeyboardShortcut("r", modifiers: [.command])
        static let hardReload = KeyboardShortcut("r", modifiers: [.command, .shift])
    }

    enum Window {
        static let new = KeyboardShortcut("n", modifiers: [.command])
        static let close = KeyboardShortcut("w", modifiers: [.command, .shift])
        static let fullscreen = KeyboardShortcut("f", modifiers: [.command, .control])
    }

    enum Address {
        static let focus = KeyboardShortcut("l", modifiers: [.command])
        static let find = KeyboardShortcut("f", modifiers: [.command])
        static let findNext = KeyboardShortcut("g", modifiers: [.command])
        static let findPrevious = KeyboardShortcut("g", modifiers: [.command, .shift])
    }

    struct Folders {}

    enum History {
        static let show = KeyboardShortcut("y", modifiers: [.command])
    }

    enum Zoom {
        static let zoomIn = KeyboardShortcut("+", modifiers: [.command])
        static let zoomOut = KeyboardShortcut("-", modifiers: [.command])
        static let resetZoom = KeyboardShortcut("0", modifiers: [.command])
    }

    enum Private {
        static let newPrivateWindow = KeyboardShortcut("n", modifiers: [.command, .shift])
    }

    enum Developer {
        static let toggleDevTools = KeyboardShortcut("i", modifiers: [.command, .option])
        static let reloadIgnoringCache = KeyboardShortcut("r", modifiers: [.command, .shift])
    }

    enum App {
        static let quit = KeyboardShortcut("q", modifiers: [.command])
        static let hide = KeyboardShortcut("h", modifiers: [.command])
        static let preferences = KeyboardShortcut(",", modifiers: [.command])
        static let toggleSidebar = KeyboardShortcut("s", modifiers: [.command])
    }
}

extension KeyboardShortcuts {
    static var allItems: [ShortcutItem] {
        [
            // Tabs
            .init(category: "Tabs", name: "New Tab", display: "⌘T"),
            .init(category: "Tabs", name: "Close Tab", display: "⌘W"),
            .init(category: "Tabs", name: "Restore", display: "⌘Z"),
            .init(category: "Tabs", name: "Reopen Closed", display: "⇧⌘T"),
            .init(category: "Tabs", name: "Next Tab", display: "^⇥"),
            .init(category: "Tabs", name: "Previous Tab", display: "^⇧⇥"),
            .init(category: "Tabs", name: "Next Tab (Alt)", display: "⇧⌘]"),
            .init(category: "Tabs", name: "Previous Tab (Alt)", display: "⇧⌘["),
            .init(category: "Tabs", name: "Move Tab Right", display: "⌥⌘→"),
            .init(category: "Tabs", name: "Move Tab Left", display: "⌥⌘←"),
            .init(category: "Tabs", name: "Pin Tab", display: "⌘D"),
            .init(category: "Tabs", name: "Tab 1", display: "⌘1"),
            .init(category: "Tabs", name: "Tab 2", display: "⌘2"),
            .init(category: "Tabs", name: "Tab 3", display: "⌘3"),
            .init(category: "Tabs", name: "Tab 4", display: "⌘4"),
            .init(category: "Tabs", name: "Tab 5", display: "⌘5"),
            .init(category: "Tabs", name: "Tab 6", display: "⌘6"),
            .init(category: "Tabs", name: "Tab 7", display: "⌘7"),
            .init(category: "Tabs", name: "Tab 8", display: "⌘8"),
            .init(category: "Tabs", name: "Tab 9", display: "⌘9"),

            // Navigation
            .init(category: "Navigation", name: "Back", display: "⌘["),
            .init(category: "Navigation", name: "Forward", display: "⌘]"),
            .init(category: "Navigation", name: "Reload", display: "⌘R"),
            .init(category: "Navigation", name: "Hard Reload", display: "⇧⌘R"),

            // Window
            .init(category: "Window", name: "New Window", display: "⌘N"),
            .init(category: "Window", name: "Close Window", display: "⇧⌘W"),
            .init(category: "Window", name: "Fullscreen", display: "⌃⌘F"),

            // Address
            .init(category: "Address", name: "Focus Address Bar", display: "⌘L"),
            .init(category: "Address", name: "Find", display: "⌘F"),
            .init(category: "Address", name: "Find Next", display: "⌘G"),
            .init(category: "Address", name: "Find Previous", display: "⇧⌘G"),

            // History
            .init(category: "History", name: "Show History", display: "⌘Y"),

            // Zoom
            .init(category: "Zoom", name: "Zoom In", display: "⌘+"),
            .init(category: "Zoom", name: "Zoom Out", display: "⌘-"),
            .init(category: "Zoom", name: "Reset Zoom", display: "⌘0"),

            // Private
            .init(category: "Private", name: "New Private Window", display: "⇧⌘N"),

            // Developer
            .init(category: "Developer", name: "Toggle DevTools", display: "⌥⌘I"),
            .init(category: "Developer", name: "Reload Ignoring Cache", display: "⇧⌘R"),

            // App
            .init(category: "App", name: "Quit", display: "⌘Q"),
            .init(category: "App", name: "Hide", display: "⌘H"),
            .init(category: "App", name: "Preferences", display: "⌘,"),
            .init(category: "App", name: "Toggle Sidebar", display: "⌘S")
        ]
    }

    static var itemsByCategory: [(category: String, items: [ShortcutItem])] {
        let grouped = Dictionary(grouping: allItems, by: { $0.category })
        return grouped.keys.sorted().map { key in
            (category: key, items: grouped[key]!.sorted { $0.name < $1.name })
        }
    }
}
