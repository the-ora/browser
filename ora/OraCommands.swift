import SwiftUI

struct OraCommands: Commands {
    @AppStorage("AppAppearance") private var appearanceRaw: String = AppAppearance.system.rawValue
    @AppStorage("ui.sidebar.hidden") private var isSidebarHidden: Bool = false
    @AppStorage("ui.sidebar.position") private var sidebarPosition: SidebarPosition = .primary
    @AppStorage("ui.toolbar.hidden") private var isToolbarHidden: Bool = false
    @AppStorage("ui.toolbar.showfullurl") private var showFullURL: Bool = true
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Window") { openWindow(id: "normal") }
                .keyboardShortcut(KeyboardShortcuts.Window.new.keyboardShortcut)

            Button("New Private Window") { openWindow(id: "private") }
                .keyboardShortcut(KeyboardShortcuts.Window.newPrivate.keyboardShortcut)

            Button("New Tab") {
                NotificationCenter.default.post(name: .showLauncher, object: NSApp.keyWindow)
            }.keyboardShortcut(KeyboardShortcuts.Tabs.new.keyboardShortcut)

            Divider()

            ImportDataButton()

            Divider()

            Button("Close Tab") {
                NotificationCenter.default.post(name: .closeActiveTab, object: NSApp.keyWindow)
            }.keyboardShortcut(KeyboardShortcuts.Tabs.close.keyboardShortcut)

            Button("Close Window") {
                if let keyWindow = NSApp.keyWindow, keyWindow.title == "Settings" {
                    keyWindow.performClose(nil)
                }
            }
            .keyboardShortcut("w", modifiers: .command)
            .disabled({
                guard let keyWindow = NSApp.keyWindow else { return true }
                return keyWindow.title != "Settings"
            }())
        }

        CommandMenu("Edit") {
            Button("Restore Last Tab") {
                NotificationCenter.default.post(name: .restoreLastTab, object: NSApp.keyWindow)
            }
            .keyboardShortcut(KeyboardShortcuts.Tabs.restore.keyboardShortcut)

            Divider()

            Button("Find in Page") {
                NotificationCenter.default.post(name: .findInPage, object: NSApp.keyWindow)
            }
            .keyboardShortcut(KeyboardShortcuts.Edit.find.keyboardShortcut)

            Divider()

            Button("Copy URL") {
                NotificationCenter.default.post(name: .copyAddressURL, object: nil)
            }
            .keyboardShortcut(KeyboardShortcuts.Address.copyURL.keyboardShortcut)
        }

        CommandGroup(replacing: .sidebar) {
            // APPEARANCE
            Picker("Appearance", selection: Binding(
                get: { AppAppearance(rawValue: appearanceRaw) ?? .system },
                set: { newValue in
                    appearanceRaw = newValue.rawValue
                    NotificationCenter.default.post(
                        name: .setAppearance,
                        object: NSApp.keyWindow,
                        userInfo: ["appearance": newValue.rawValue]
                    )
                }
            )) {
                ForEach(AppAppearance.allCases) { mode in
                    Text(mode.rawValue.capitalized).tag(mode)
                }
            }

            Divider()

            // VISIBILITY
            Button(isSidebarHidden ? "Show Sidebar" : "Hide Sidebar") {
                NotificationCenter.default.post(name: .toggleSidebar, object: nil)
            }
            .keyboardShortcut(KeyboardShortcuts.App.toggleSidebar.keyboardShortcut)

            Button(isToolbarHidden ? "Show Toolbar" : "Hide Toolbar") {
                NotificationCenter.default.post(name: .toggleToolbar, object: NSApp.keyWindow)
            }
            .keyboardShortcut(KeyboardShortcuts.App.toggleToolbar.keyboardShortcut)

            Divider()

            // LAYOUT
            Button(sidebarPosition == .primary ? "Right Side Tabs" : "Left Side Tabs") {
                NotificationCenter.default.post(name: .toggleSidebarPosition, object: nil)
            }

            Button(showFullURL ? "Hide Full URL" : "Show Full URL") {
                NotificationCenter.default.post(name: .toggleFullURL, object: NSApp.keyWindow)
            }
            Divider()
        }

        CommandMenu("Navigation") {
            Button("Reload Page") {
                NotificationCenter.default.post(name: .reloadPage, object: NSApp.keyWindow)
            }
            .keyboardShortcut(KeyboardShortcuts.Navigation.reload.keyboardShortcut)

            Divider()

            Button("Back") {
                NotificationCenter.default.post(name: .goBack, object: NSApp.keyWindow)
            }
            .keyboardShortcut(KeyboardShortcuts.Navigation.back.keyboardShortcut)

            Button("Forward") {
                NotificationCenter.default.post(name: .goForward, object: NSApp.keyWindow)
            }
            .keyboardShortcut(KeyboardShortcuts.Navigation.forward.keyboardShortcut)
        }

        CommandMenu("Tabs") {
            Button("Pin Tab") {
                NotificationCenter.default.post(name: .togglePinTab, object: NSApp.keyWindow)
            }.keyboardShortcut(KeyboardShortcuts.Tabs.pin.keyboardShortcut)

            Divider()

            Button("Next Tab") {
                NotificationCenter.default.post(name: .nextTab, object: NSApp.keyWindow)
            }
            .keyboardShortcut(KeyboardShortcuts.Tabs.next.keyboardShortcut)

            Button("Previous Tab") {
                NotificationCenter.default.post(name: .previousTab, object: NSApp.keyWindow)
            }
            .keyboardShortcut(KeyboardShortcuts.Tabs.previous.keyboardShortcut)

            Divider()

            // Quick Tab Selection (1–9)
            ForEach(1 ... 9, id: \.self) { index in
                Button("Tab \(index)") {
                    NotificationCenter.default.post(
                        name: .selectTabAtIndex,
                        object: NSApp.keyWindow,
                        userInfo: ["index": index]
                    )
                }
                .keyboardShortcut(KeyboardShortcuts.Tabs.keyboardShortcut(for: index))
            }
        }

        CommandGroup(replacing: .appInfo) {
            Button("About Ora") { showAboutWindow() }
            Button("Check for Updates") {
                NotificationCenter.default.post(
                    name: .checkForUpdates,
                    object: NSApp.keyWindow
                )
            }
        }
    }

    // MARK: - Utility Helpers

    private func showAboutWindow() {
        let alert = NSAlert()
        alert.messageText = "Ora Browser"
        alert.informativeText = """
        Version \(getAppVersion())

        Fast, secure, and beautiful browser built for macOS.

        © 2025 Ora Browser
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func getAppVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (\(build))"
    }
}
