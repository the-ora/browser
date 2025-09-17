import AppKit
import SwiftUI

struct OraCommands: Commands {
    @AppStorage("AppAppearance") private var appearanceRaw: String = AppAppearance.system.rawValue
    @Environment(\.openWindow) private var openWindow
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Window") {
                openWindow(id: "normal")
            }
            .keyboardShortcut(KeyboardShortcuts.Window.new)
            Button("New Private Window") {
                openWindow(id: "private")
            }
            .keyboardShortcut(KeyboardShortcuts.Window.newPrivate)
            Button("New Tab") { NotificationCenter.default.post(name: .showLauncher, object: NSApp.keyWindow) }
                .keyboardShortcut(KeyboardShortcuts.Tabs.new)

            Button("Close Tab") { NotificationCenter.default.post(name: .closeActiveTab, object: NSApp.keyWindow) }
                .keyboardShortcut(KeyboardShortcuts.Tabs.close)

            ImportDataButton()
        }

        CommandGroup(after: .pasteboard) {
            Button("Restore") { NotificationCenter.default.post(name: .restoreLastTab, object: NSApp.keyWindow) }
                .keyboardShortcut(KeyboardShortcuts.Tabs.restore)

            Button("Find") {
                NotificationCenter.default.post(name: .findInPage, object: NSApp.keyWindow)
            }
            .keyboardShortcut(KeyboardShortcuts.Address.find)

            Divider()

            Button("Copy URL") {
                NotificationCenter.default.post(name: .copyAddressURL, object: nil)
            }
            .keyboardShortcut(KeyboardShortcuts.Address.copyURL)
        }

        CommandGroup(replacing: .sidebar) {
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
                    Text(mode.rawValue).tag(mode)
                }
            }
        }

        CommandGroup(after: .sidebar) {
            Button("Toggle Sidebar") {
                NotificationCenter.default.post(name: .toggleSidebar, object: nil)
            }
            .keyboardShortcut(KeyboardShortcuts.App.toggleSidebar)

            Divider()

            Button("Toggle Full URL") { NotificationCenter.default.post(name: .toggleFullURL, object: NSApp.keyWindow) }
        }

        CommandGroup(replacing: .appInfo) {
            Button("About Ora") { showAboutWindow() }

            Button("Check for Updates") { NotificationCenter.default.post(
                name: .checkForUpdates,
                object: NSApp.keyWindow
            ) }
        }

        CommandMenu("Navigation") {
            Button("Reload") { NotificationCenter.default.post(name: .reloadPage, object: NSApp.keyWindow) }
                .keyboardShortcut(KeyboardShortcuts.Navigation.reload)
            Button("Back") { NotificationCenter.default.post(name: .goBack, object: NSApp.keyWindow) }
                .keyboardShortcut(KeyboardShortcuts.Navigation.back)
            Button("Forward") { NotificationCenter.default.post(name: .goForward, object: NSApp.keyWindow) }
                .keyboardShortcut(KeyboardShortcuts.Navigation.forward)
        }

        CommandMenu("Tabs") {
            Button("New Tab") { NotificationCenter.default.post(name: .showLauncher, object: NSApp.keyWindow) }
            Button("Pin Tab") { NotificationCenter.default.post(name: .togglePinTab, object: NSApp.keyWindow) }
                .keyboardShortcut(KeyboardShortcuts.Tabs.pin)

            Divider()

            Button("Next Tab") { NotificationCenter.default.post(name: .nextTab, object: NSApp.keyWindow) }
            Button("Previous Tab") { NotificationCenter.default.post(name: .previousTab, object: NSApp.keyWindow) }
        }

        CommandGroup(replacing: .toolbar) {
            Button("Toggle Toolbar") { NotificationCenter.default.post(name: .toggleToolbar, object: NSApp.keyWindow) }
                .keyboardShortcut(KeyboardShortcuts.App.toggleToolbar)
        }

        CommandGroup(replacing: .appSettings) {
            Button("Settings") {
                openWindow(id: "settings")
            }
            .keyboardShortcut(KeyboardShortcuts.App.settings)
        }
    }

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
