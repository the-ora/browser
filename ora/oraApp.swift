import Foundation
import SwiftData
import SwiftUI

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
}

@main
struct OraApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var keyModifierListener = KeyModifierListener()
    @StateObject private var appearanceManager = AppearanceManager()
    // Pass it to TabManager
    @StateObject private var tabManager: TabManager
    @StateObject private var historyManager: HistoryManager
    @StateObject private var downloadManager: DownloadManager

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
                }
                .modelContext(downloadContext)
                .withTheme()
        }
        .defaultSize(width: 1440, height: 900)
        .windowStyle(.hiddenTitleBar)
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
                .keyboardShortcut(
                    KeyboardShortcuts.Address.find
                )
            }

            CommandGroup(replacing: .sidebar) {
                Picker("Appearance", selection: $appearanceManager.appearance) {
                    ForEach(AppAppearance.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
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
        }
        Settings {
            SettingsContentView()
                .environmentObject(appearanceManager)
                .environmentObject(historyManager)
                .modelContext(tabContext)
                .withTheme()
        }
    }
}
