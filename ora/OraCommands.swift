import AppKit
import SwiftUI

struct OraCommands: Commands {
    @AppStorage("AppAppearance") private var appearanceRaw: String = AppAppearance.system.rawValue
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var shortcutManager = CustomKeyboardShortcutManager.shared

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Window") {
                openWindow(id: "normal")
            }
            .keyboardShortcut(KeyboardShortcuts.Window.new.keyboardShortcut)

            Button("New Private Window") {
                openWindow(id: "private")
            }
            .keyboardShortcut(KeyboardShortcuts.Window.newPrivate.keyboardShortcut)

            Button("New Tab") { NotificationCenter.default.post(name: .showLauncher, object: NSApp.keyWindow) }
                .keyboardShortcut(KeyboardShortcuts.Tabs.new.keyboardShortcut)

            Button("Close Tab") { NotificationCenter.default.post(name: .closeActiveTab, object: NSApp.keyWindow) }
                .keyboardShortcut(KeyboardShortcuts.Tabs.close.keyboardShortcut)

            ImportDataButton()
        }

        CommandGroup(after: .pasteboard) {
            Button("Restore") { NotificationCenter.default.post(name: .restoreLastTab, object: NSApp.keyWindow) }
                .keyboardShortcut(KeyboardShortcuts.Tabs.restore.keyboardShortcut)

            Button("Find") {
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
            .keyboardShortcut(KeyboardShortcuts.App.toggleSidebar.keyboardShortcut)

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
                .keyboardShortcut(KeyboardShortcuts.Navigation.reload.keyboardShortcut)
            Button("Back") { NotificationCenter.default.post(name: .goBack, object: NSApp.keyWindow) }
                .keyboardShortcut(KeyboardShortcuts.Navigation.back.keyboardShortcut)
            Button("Forward") { NotificationCenter.default.post(name: .goForward, object: NSApp.keyWindow) }
                .keyboardShortcut(KeyboardShortcuts.Navigation.forward.keyboardShortcut)
        }

        CommandMenu("Tabs") {
            Button("New Tab") { NotificationCenter.default.post(name: .showLauncher, object: NSApp.keyWindow) }
                .keyboardShortcut(KeyboardShortcuts.Tabs.new.keyboardShortcut)
            Button("Pin Tab") { NotificationCenter.default.post(name: .togglePinTab, object: NSApp.keyWindow) }
                .keyboardShortcut(KeyboardShortcuts.Tabs.pin.keyboardShortcut)

            Divider()

            Button("Next Tab") { NotificationCenter.default.post(name: .nextTab, object: NSApp.keyWindow) }
                .keyboardShortcut(KeyboardShortcuts.Tabs.next.keyboardShortcut)
            Button("Previous Tab") { NotificationCenter.default.post(name: .previousTab, object: NSApp.keyWindow) }
                .keyboardShortcut(KeyboardShortcuts.Tabs.previous.keyboardShortcut)

            Divider()

            Button("Tab 1") { NotificationCenter.default.post(
                name: .selectTabAtIndex,
                object: NSApp.keyWindow,
                userInfo: ["index": 1]
            ) }
            .keyboardShortcut(KeyboardShortcuts.Tabs.tab1.keyboardShortcut)

            Button("Tab 2") { NotificationCenter.default.post(
                name: .selectTabAtIndex,
                object: NSApp.keyWindow,
                userInfo: ["index": 2]
            ) }
            .keyboardShortcut(KeyboardShortcuts.Tabs.tab2.keyboardShortcut)

            Button("Tab 3") { NotificationCenter.default.post(
                name: .selectTabAtIndex,
                object: NSApp.keyWindow,
                userInfo: ["index": 3]
            ) }
            .keyboardShortcut(KeyboardShortcuts.Tabs.tab3.keyboardShortcut)

            Button("Tab 4") { NotificationCenter.default.post(
                name: .selectTabAtIndex,
                object: NSApp.keyWindow,
                userInfo: ["index": 4]
            ) }
            .keyboardShortcut(KeyboardShortcuts.Tabs.tab4.keyboardShortcut)

            Button("Tab 5") { NotificationCenter.default.post(
                name: .selectTabAtIndex,
                object: NSApp.keyWindow,
                userInfo: ["index": 5]
            ) }
            .keyboardShortcut(KeyboardShortcuts.Tabs.tab5.keyboardShortcut)

            Button("Tab 6") { NotificationCenter.default.post(
                name: .selectTabAtIndex,
                object: NSApp.keyWindow,
                userInfo: ["index": 6]
            ) }
            .keyboardShortcut(KeyboardShortcuts.Tabs.tab6.keyboardShortcut)

            Button("Tab 7") { NotificationCenter.default.post(
                name: .selectTabAtIndex,
                object: NSApp.keyWindow,
                userInfo: ["index": 7]
            ) }
            .keyboardShortcut(KeyboardShortcuts.Tabs.tab7.keyboardShortcut)

            Button("Tab 8") { NotificationCenter.default.post(
                name: .selectTabAtIndex,
                object: NSApp.keyWindow,
                userInfo: ["index": 8]
            ) }
            .keyboardShortcut(KeyboardShortcuts.Tabs.tab8.keyboardShortcut)

            Button("Tab 9") { NotificationCenter.default.post(
                name: .selectTabAtIndex,
                object: NSApp.keyWindow,
                userInfo: ["index": 9]
            ) }
            .keyboardShortcut(KeyboardShortcuts.Tabs.tab9.keyboardShortcut)
        }

        CommandGroup(replacing: .toolbar) {
            Button("Toggle Toolbar") { NotificationCenter.default.post(name: .toggleToolbar, object: NSApp.keyWindow) }
                .keyboardShortcut(KeyboardShortcuts.App.toggleToolbar.keyboardShortcut)
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
