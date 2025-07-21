import SwiftUI

enum KeyboardShortcuts {
  struct Tabs {
    static let new = KeyboardShortcut("t", modifiers: [.command])
    static let close = KeyboardShortcut("w", modifiers: [.command])
    static let reopenClosed = KeyboardShortcut("t", modifiers: [.command, .shift])
    static let next = KeyboardShortcut(.tab, modifiers: [.control])
    static let previous = KeyboardShortcut(.tab, modifiers: [.control, .shift])
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

  struct Navigation {
    static let back = KeyboardShortcut("[", modifiers: [.command])
    static let forward = KeyboardShortcut("]", modifiers: [.command])
    static let reload = KeyboardShortcut("r", modifiers: [.command])
    static let hardReload = KeyboardShortcut("r", modifiers: [.command, .shift])
  }

  struct Window {
    static let new = KeyboardShortcut("n", modifiers: [.command])
    static let close = KeyboardShortcut("w", modifiers: [.command, .shift])
    static let fullscreen = KeyboardShortcut("f", modifiers: [.command, .control])
  }

  struct Address {
    static let focus = KeyboardShortcut("l", modifiers: [.command])
    static let find = KeyboardShortcut("f", modifiers: [.command])
    static let findNext = KeyboardShortcut("g", modifiers: [.command])
    static let findPrevious = KeyboardShortcut("g", modifiers: [.command, .shift])
  }

  struct Folders {
  }

  struct History {
    static let show = KeyboardShortcut("y", modifiers: [.command])
  }

  struct Zoom {
    static let zoomIn = KeyboardShortcut("+", modifiers: [.command])
    static let zoomOut = KeyboardShortcut("-", modifiers: [.command])
    static let resetZoom = KeyboardShortcut("0", modifiers: [.command])
  }

  struct Private {
    static let newPrivateWindow = KeyboardShortcut("n", modifiers: [.command, .shift])
  }

  struct Developer {
    static let toggleDevTools = KeyboardShortcut("i", modifiers: [.command, .option])
    static let reloadIgnoringCache = KeyboardShortcut("r", modifiers: [.command, .shift])
  }

  struct App {
    static let quit = KeyboardShortcut("q", modifiers: [.command])
    static let hide = KeyboardShortcut("h", modifiers: [.command])
    static let preferences = KeyboardShortcut(",", modifiers: [.command])
    static let toggleSidebar = KeyboardShortcut("s", modifiers: [.command])
  }
}