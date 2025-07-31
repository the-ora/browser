import Foundation
import SwiftData
import SwiftUI

func deleteSwiftDataStore() {

    let fileManager = FileManager.default
    let storeURL = URL.applicationSupportDirectory.appending(path: "MyStore.sqlite")
    print("🧹 Deleting SwiftData store at: \(storeURL.path)")
    let shmURL = storeURL.appendingPathExtension("-shm")
    let walURL = storeURL.appendingPathExtension("-wal")
    
    try? fileManager.removeItem(at: storeURL)
    try? fileManager.removeItem(at: shmURL)
    try? fileManager.removeItem(at: walURL)
}
class AppState: ObservableObject {
    @Published var showLauncher: Bool = false
    @Published var launcherSearchText: String = ""
    @Published var showFinderIn: UUID? = nil
    @Published var isFloatingTabSwitchVisible: Bool = false
}
@main
struct oraApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var keyModifierListener = KeyModifierListener()
    @StateObject private var appearanceManager = AppearanceManager()
    // Pass it to TabManager
    @StateObject private var tabManager: TabManager
    @StateObject private var historyManager: HistoryManager
    
    let tabContext: ModelContext
    let historyContext: ModelContext
    
    let modelConfiguration = ModelConfiguration(
        "MyModel",
        schema: Schema([TabContainer.self]),
        url: URL.applicationSupportDirectory.appending(path: "MyStore.sqlite")
    )
    init() {
        //#if DEBUG
//                    deleteSwiftDataStore()
        //#endif
//        
        // tabs
        let container: ModelContainer
        let modelContext: ModelContext
        do {
           
            container = try ModelContainer(
                for: TabContainer.self,
                configurations: modelConfiguration
            )
            modelContext = ModelContext(container)
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
        // history
        let historyContainer: ModelContainer
        let historyModelContext: ModelContext
        do {
           
            historyContainer = try ModelContainer(
                for: History.self,
                configurations: modelConfiguration
            )
            historyModelContext = ModelContext(historyContainer)
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
        
        self.tabContext = modelContext
        self.historyContext = historyModelContext
        let historyManagerObj = StateObject(
            wrappedValue: HistoryManager(
                modelContainer: historyContainer,
                modelContext: historyModelContext
            )
        )
        _historyManager = historyManagerObj
        _tabManager = StateObject(
            wrappedValue: TabManager(
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
    }
}
