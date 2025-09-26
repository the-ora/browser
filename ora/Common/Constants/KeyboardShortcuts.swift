import AppKit
import SwiftUI

enum KeyboardShortcuts {
    // MARK: - Tabs

    enum Tabs {
        static let new = KeyboardShortcutDefinition(
            id: "tabs.new",
            name: "New Tab",
            category: "Tabs",
            defaultChord: KeyChord(keyEquivalent: .init("t"), modifiers: [.command])
        )
        static let close = KeyboardShortcutDefinition(
            id: "tabs.close",
            name: "Close Tab",
            category: "Tabs",
            defaultChord: KeyChord(keyEquivalent: .init("w"), modifiers: [.command])
        )
        static let restore = KeyboardShortcutDefinition(
            id: "tabs.restore",
            name: "Restore Tab",
            category: "Tabs",
            defaultChord: KeyChord(keyEquivalent: .init("z"), modifiers: [.command])
        )
        static let reopenClosed = KeyboardShortcutDefinition(
            id: "tabs.reopenClosed",
            name: "Reopen Closed Tab",
            category: "Tabs",
            defaultChord: KeyChord(keyEquivalent: .init("t"), modifiers: [.command, .shift])
        )
        static let next = KeyboardShortcutDefinition(
            id: "tabs.next",
            name: "Next Tab",
            category: "Tabs",
            defaultChord: KeyChord(keyEquivalent: .tab, modifiers: [.control])
        )
        static let previous = KeyboardShortcutDefinition(
            id: "tabs.previous",
            name: "Previous Tab",
            category: "Tabs",
            defaultChord: KeyChord(keyEquivalent: .tab, modifiers: [.control, .shift])
        )
        static let moveRight = KeyboardShortcutDefinition(
            id: "tabs.moveRight",
            name: "Move Tab Right",
            category: "Tabs",
            defaultChord: KeyChord(keyEquivalent: .rightArrow, modifiers: [.option, .command])
        )
        static let moveLeft = KeyboardShortcutDefinition(
            id: "tabs.moveLeft",
            name: "Move Tab Left",
            category: "Tabs",
            defaultChord: KeyChord(keyEquivalent: .leftArrow, modifiers: [.option, .command])
        )
        static let pin = KeyboardShortcutDefinition(
            id: "tabs.pin",
            name: "Pin Tab",
            category: "Tabs",
            defaultChord: KeyChord(keyEquivalent: .init("d"), modifiers: [.command])
        )
        static let tab1 = KeyboardShortcutDefinition(
            id: "tabs.tab1",
            name: "Tab 1",
            category: "Tabs",
            defaultChord: KeyChord(keyEquivalent: .init("1"), modifiers: [.command])
        )
        static let tab2 = KeyboardShortcutDefinition(
            id: "tabs.tab2",
            name: "Tab 2",
            category: "Tabs",
            defaultChord: KeyChord(keyEquivalent: .init("2"), modifiers: [.command])
        )
        static let tab3 = KeyboardShortcutDefinition(
            id: "tabs.tab3",
            name: "Tab 3",
            category: "Tabs",
            defaultChord: KeyChord(keyEquivalent: .init("3"), modifiers: [.command])
        )
        static let tab4 = KeyboardShortcutDefinition(
            id: "tabs.tab4",
            name: "Tab 4",
            category: "Tabs",
            defaultChord: KeyChord(keyEquivalent: .init("4"), modifiers: [.command])
        )
        static let tab5 = KeyboardShortcutDefinition(
            id: "tabs.tab5",
            name: "Tab 5",
            category: "Tabs",
            defaultChord: KeyChord(keyEquivalent: .init("5"), modifiers: [.command])
        )
        static let tab6 = KeyboardShortcutDefinition(
            id: "tabs.tab6",
            name: "Tab 6",
            category: "Tabs",
            defaultChord: KeyChord(keyEquivalent: .init("6"), modifiers: [.command])
        )
        static let tab7 = KeyboardShortcutDefinition(
            id: "tabs.tab7",
            name: "Tab 7",
            category: "Tabs",
            defaultChord: KeyChord(keyEquivalent: .init("7"), modifiers: [.command])
        )
        static let tab8 = KeyboardShortcutDefinition(
            id: "tabs.tab8",
            name: "Tab 8",
            category: "Tabs",
            defaultChord: KeyChord(keyEquivalent: .init("8"), modifiers: [.command])
        )
        static let tab9 = KeyboardShortcutDefinition(
            id: "tabs.tab9",
            name: "Tab 9",
            category: "Tabs",
            defaultChord: KeyChord(keyEquivalent: .init("9"), modifiers: [.command])
        )
    }

    // MARK: - Navigation

    enum Navigation {
        static let back = KeyboardShortcutDefinition(
            id: "navigation.back",
            name: "Back",
            category: "Navigation",
            defaultChord: KeyChord(keyEquivalent: .init("["), modifiers: [.command])
        )
        static let forward = KeyboardShortcutDefinition(
            id: "navigation.forward",
            name: "Forward",
            category: "Navigation",
            defaultChord: KeyChord(keyEquivalent: .init("]"), modifiers: [.command])
        )
        static let reload = KeyboardShortcutDefinition(
            id: "navigation.reload",
            name: "Reload",
            category: "Navigation",
            defaultChord: KeyChord(keyEquivalent: .init("r"), modifiers: [.command])
        )
        static let hardReload = KeyboardShortcutDefinition(
            id: "navigation.hardReload",
            name: "Hard Reload",
            category: "Navigation",
            defaultChord: KeyChord(keyEquivalent: .init("r"), modifiers: [.command, .shift])
        )
    }

    // MARK: - Window

    enum Window {
        static let new = KeyboardShortcutDefinition(
            id: "window.new",
            name: "New Window",
            category: "Window",
            defaultChord: KeyChord(keyEquivalent: .init("n"), modifiers: [.command])
        )
        static let newPrivate = KeyboardShortcutDefinition(
            id: "window.newPrivate",
            name: "New Private Window",
            category: "Window",
            defaultChord: KeyChord(keyEquivalent: .init("n"), modifiers: [.command, .shift])
        )
        static let close = KeyboardShortcutDefinition(
            id: "window.close",
            name: "Close Window",
            category: "Window",
            defaultChord: KeyChord(keyEquivalent: .init("w"), modifiers: [.command, .shift])
        )
        static let fullscreen = KeyboardShortcutDefinition(
            id: "window.fullscreen",
            name: "Fullscreen",
            category: "Window",
            defaultChord: KeyChord(keyEquivalent: .init("f"), modifiers: [.command, .control])
        )
    }

    // MARK: - Address

    enum Address {
        static let copyURL = KeyboardShortcutDefinition(
            id: "address.copyURL",
            name: "Copy URL",
            category: "Address",
            defaultChord: KeyChord(keyEquivalent: .init("c"), modifiers: [.command, .shift])
        )
        static let focus = KeyboardShortcutDefinition(
            id: "address.focus",
            name: "Focus Address Bar",
            category: "Address",
            defaultChord: KeyChord(keyEquivalent: .init("l"), modifiers: [.command])
        )
    }

    // MARK: - Edit

    enum Edit {
        static let find = KeyboardShortcutDefinition(
            id: "edit.find",
            name: "Find",
            category: "Edit",
            defaultChord: KeyChord(keyEquivalent: .init("f"), modifiers: [.command])
        )
        static let findNext = KeyboardShortcutDefinition(
            id: "edit.findNext",
            name: "Find Next",
            category: "Edit",
            defaultChord: KeyChord(keyEquivalent: .init("g"), modifiers: [.command])
        )
        static let findPrevious = KeyboardShortcutDefinition(
            id: "edit.findPrevious",
            name: "Find Previous",
            category: "Edit",
            defaultChord: KeyChord(keyEquivalent: .init("g"), modifiers: [.command, .shift])
        )
    }

    // MARK: - History

    enum History {
        static let show = KeyboardShortcutDefinition(
            id: "history.show",
            name: "Show History",
            category: "History",
            defaultChord: KeyChord(keyEquivalent: .init("y"), modifiers: [.command])
        )
    }

    // MARK: - Zoom

    enum Zoom {
        static let zoomIn = KeyboardShortcutDefinition(
            id: "zoom.zoomIn",
            name: "Zoom In",
            category: "Zoom",
            defaultChord: KeyChord(keyEquivalent: .init("+"), modifiers: [.command])
        )
        static let zoomOut = KeyboardShortcutDefinition(
            id: "zoom.zoomOut",
            name: "Zoom Out",
            category: "Zoom",
            defaultChord: KeyChord(keyEquivalent: .init("-"), modifiers: [.command])
        )
        static let reset = KeyboardShortcutDefinition(
            id: "zoom.reset",
            name: "Reset Zoom",
            category: "Zoom",
            defaultChord: KeyChord(keyEquivalent: .init("0"), modifiers: [.command])
        )
    }

    // MARK: - Developer

    enum Developer {
        static let toggleDevTools = KeyboardShortcutDefinition(
            id: "developer.toggleDevTools",
            name: "Toggle DevTools",
            category: "Developer",
            defaultChord: KeyChord(keyEquivalent: .init("i"), modifiers: [.command, .option])
        )
        static let reloadIgnoringCache = KeyboardShortcutDefinition(
            id: "developer.reloadIgnoringCache",
            name: "Reload (Ignoring Cache)",
            category: "Developer",
            defaultChord: KeyChord(keyEquivalent: .init("r"), modifiers: [.command, .shift])
        )
    }

    // MARK: - App

    enum App {
        static let quit = KeyboardShortcutDefinition(
            id: "app.quit",
            name: "Quit",
            category: "App",
            defaultChord: KeyChord(keyEquivalent: .init("q"), modifiers: [.command])
        )
        static let hide = KeyboardShortcutDefinition(
            id: "app.hide",
            name: "Hide",
            category: "App",
            defaultChord: KeyChord(keyEquivalent: .init("h"), modifiers: [.command])
        )
        static let preferences = KeyboardShortcutDefinition(
            id: "app.preferences",
            name: "Preferences",
            category: "App",
            defaultChord: KeyChord(keyEquivalent: .init(","), modifiers: [.command])
        )
        static let toggleSidebar = KeyboardShortcutDefinition(
            id: "app.toggleSidebar",
            name: "Toggle Sidebar",
            category: "App",
            defaultChord: KeyChord(keyEquivalent: .init("s"), modifiers: [.command])
        )
        static let toggleToolbar = KeyboardShortcutDefinition(
            id: "app.toggleToolbar",
            name: "Toggle Toolbar",
            category: "App",
            defaultChord: KeyChord(keyEquivalent: .init("d"), modifiers: [.command, .shift])
        )
    }

    /// All keyboard shortcut definitions
    static let allShortcuts: [KeyboardShortcutDefinition] = [
        // Tabs
        Tabs.new, Tabs.close, Tabs.restore, Tabs.reopenClosed, Tabs.next, Tabs.previous,
        Tabs.moveRight, Tabs.moveLeft, Tabs.pin,
        Tabs.tab1, Tabs.tab2, Tabs.tab3, Tabs.tab4, Tabs.tab5,
        Tabs.tab6, Tabs.tab7, Tabs.tab8, Tabs.tab9,

        // Navigation
        Navigation.back, Navigation.forward, Navigation.reload, Navigation.hardReload,

        // Window
        Window.new, Window.newPrivate, Window.close, Window.fullscreen,

        // Address
        Address.copyURL, Address.focus,

        // Edit
        Edit.find, Edit.findNext, Edit.findPrevious,

        // History
        History.show,

        // Zoom
        Zoom.zoomIn, Zoom.zoomOut, Zoom.reset,

        // Developer
        Developer.toggleDevTools, Developer.reloadIgnoringCache,

        // App
        App.quit, App.hide, App.preferences, App.toggleSidebar, App.toggleToolbar
    ]

    /// Get shortcuts grouped by category for settings display
    static var itemsByCategory: [(category: String, items: [KeyboardShortcutDefinition])] {
        Dictionary(grouping: allShortcuts, by: \.category)
            .map { (category: $0.key, items: $0.value) }
            .sorted { $0.category.caseInsensitiveCompare($1.category) == .orderedAscending }
    }
}
