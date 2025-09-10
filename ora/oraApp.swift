import AppKit
import Foundation
import SwiftData
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Disable automatic window tabbing for all NSWindow instances
        NSWindow.allowsAutomaticWindowTabbing = false
    }
}

extension Notification.Name {
    static let toggleSidebar = Notification.Name("ToggleSidebar")
    static let copyAddressURL = Notification.Name("CopyAddressURL")
}

func deleteSwiftDataStore(_ loc: String) {
    let fileManager = FileManager.default
    let storeURL = URL.applicationSupportDirectory.appending(path: loc)
    let shmURL = storeURL.appendingPathExtension("-shm")
    let walURL = storeURL.appendingPathExtension("-wal")

    try? fileManager.removeItem(at: storeURL)
    try? fileManager.removeItem(at: shmURL)
    try? fileManager.removeItem(at: walURL)
}

class AppState: ObservableObject {
    @Published var showLauncher: Bool = false
    @Published var launcherSearchText: String = ""
    @Published var showFinderIn: UUID?
    @Published var isFloatingTabSwitchVisible: Bool = false
    @Published var isToolbarHidden: Bool = false
    @Published var showFullURL: Bool = (UserDefaults.standard.object(forKey: "showFullURL") as? Bool) ?? true {
        didSet { UserDefaults.standard.set(showFullURL, forKey: "showFullURL") }
    }
}

@main
struct OraApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var keyModifierListener = KeyModifierListener()
    @StateObject private var appearanceManager = AppearanceManager()
    @StateObject private var updateService = UpdateService()
    // Pass it to TabManager
    @StateObject private var tabManager: TabManager
    @StateObject private var historyManager: HistoryManager
    @StateObject private var downloadManager: DownloadManager
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let tabContext: ModelContext
    let historyContext: ModelContext
    let downloadContext: ModelContext

    let modelConfiguration = ModelConfiguration(
        "OraData",
        schema: Schema([TabContainer.self, History.self, Download.self]),
        url: URL.applicationSupportDirectory.appending(path: "OraData.sqlite")
    )
    init() {
        // #if DEBUG
        //        deleteSwiftDataStore("OraData.sqlite")
        // #endif
        //
        // Create single container for all models
        let container: ModelContainer
        let modelContext: ModelContext
        do {
            container = try ModelContainer(
                for: TabContainer.self, History.self, Download.self,
                configurations: modelConfiguration
            )
            modelContext = ModelContext(container)
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }

        self.tabContext = modelContext
        self.downloadContext = modelContext
        self.historyContext = modelContext
        let historyManagerObj = StateObject(
            wrappedValue: HistoryManager(
                modelContainer: container,
                modelContext: modelContext
            )
        )
        _historyManager = historyManagerObj
        _tabManager = StateObject(
            wrappedValue: TabManager(
                modelContainer: container,
                modelContext: modelContext
            )
        )

        _downloadManager = StateObject(
            wrappedValue: DownloadManager(
                modelContainer: container,
                modelContext: modelContext
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            BrowserView()
                .environmentObject(appState)
                .environmentObject(tabManager)
                .environmentObject(historyManager)
                .environmentObject(keyModifierListener)
                .environmentObject(appearanceManager)
                .environmentObject(downloadManager)
                .environmentObject(updateService)
                .modelContext(tabContext)
                .modelContext(historyContext)
                .onAppear {
                    keyModifierListener.registerKeyDownHandler { event in
                        guard !appState.isFloatingTabSwitchVisible else { return false }

                        if event.keyCode == 48 {  // Tab key
                            if event.modifierFlags.contains(.control) {
                                DispatchQueue.main.async {
                                    appState.isFloatingTabSwitchVisible = true
                                }
                                return true
                            }
                        }
                        return false
                    }

                    // Check for updates in background if auto-update is enabled
                    if SettingsStore.shared.autoUpdateEnabled {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            updateService.checkForUpdatesInBackground()
                        }
                    }
                }
                .modelContext(downloadContext)
                .withTheme()
                .frame(minWidth: 500, minHeight: 360)
        }
        .defaultSize(width: 1440, height: 900)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Tab") {
                    appState.showLauncher = true
                }
                .keyboardShortcut(KeyboardShortcuts.Tabs.new)

                Button("Close Tab") {
                    tabManager
                        .closeActiveTab()
                }
                .keyboardShortcut(
                    KeyboardShortcuts.Tabs.close
                )

                ImportDataButton()
            }

            CommandGroup(after: .pasteboard) {
                Button("Restore") {
                    tabManager.restoreLastTab()
                }
                .keyboardShortcut(
                    KeyboardShortcuts.Tabs.restore
                )

                Button("Find") {
                    if let activeTab = tabManager.activeTab {
                        appState.showFinderIn = activeTab.id
                    }
                }
                .keyboardShortcut(KeyboardShortcuts.Address.find)

                Divider()

                Button("Copy URL") {
                    NotificationCenter.default.post(name: .copyAddressURL, object: nil)
                }
                .keyboardShortcut(KeyboardShortcuts.Address.copyURL)
            }

            CommandGroup(replacing: .sidebar) {
                Picker("Appearance", selection: $appearanceManager.appearance) {
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

                if appState.showFullURL {
                    Button("Hide Full URL") {
                        appState.showFullURL = false
                    }
                } else {
                    Button("Show Full URL") {
                        appState.showFullURL = true
                    }
                }
            }

            CommandGroup(replacing: .appInfo) {
                Button("About Ora") {
                    showAboutWindow()
                }

                Button("Check for Updates") {
                    updateService.checkForUpdates()
                }
            }

            // CommandGroup(replacing: .appSettings) {
            //     Button("Settings…") {
            //         SettingsWindowController.shared.show()
            //     }
            //     .keyboardShortcut(",", modifiers: .command)
            // }

            CommandMenu("Navigation") {
                Button("Reload") {
                    if let tab = tabManager.activeTab {
                        tab.webView.reload()
                    }
                }
                .keyboardShortcut(
                    KeyboardShortcuts.Navigation.reload
                )
                Button("Back") {
                    if let tab = tabManager.activeTab {
                        tab.webView.goBack()
                    }
                }
                .keyboardShortcut(
                    KeyboardShortcuts.Navigation.back
                )
                Button("Forward") {
                    if let tab = tabManager.activeTab {
                        tab.webView.goForward()
                    }
                }
                .keyboardShortcut(
                    KeyboardShortcuts.Navigation.forward
                )
            }

            CommandMenu("Tabs") {
                Button("New Tab") {
                    appState.showLauncher = true
                }
                Button("Pin Tab") {
                    if let tab = tabManager.activeTab {
                        tabManager
                            .togglePinTab(tab)
                    }
                }
                .keyboardShortcut(
                    KeyboardShortcuts.Tabs.pin
                )

                Divider()

                Button("Next Tab") {
                    appState.isFloatingTabSwitchVisible = true
                }

                Button("Previous Tab") {
                    appState.isFloatingTabSwitchVisible = true
                }
            }

            CommandGroup(replacing: .toolbar) {
                if appState.isToolbarHidden {
                    Button("Show Toolbar") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appState.isToolbarHidden = false
                        }
                    }
                    .keyboardShortcut("d", modifiers: [.command, .shift])
                } else {
                    Button("Hide Toolbar") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appState.isToolbarHidden = true
                        }
                    }
                    .keyboardShortcut("d", modifiers: [.command, .shift])
                }
            }
        }
        Settings {
            SettingsContentView()
                .environmentObject(appearanceManager)
                .environmentObject(historyManager)
                .environmentObject(updateService)
                .modelContext(tabContext)
                .withTheme()
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
