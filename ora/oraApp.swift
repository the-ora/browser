import SwiftUI
import SwiftData
import Foundation

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
}
@main
struct oraApp: App {
    @StateObject private var appState = AppState()
    
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
            BrowserViewController()
                .environmentObject(appState)
                .environmentObject(tabManager)
                .environmentObject(historyManager)
                .modelContext(tabContext)
                .modelContext(historyContext)
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
                Button("Pin Tab") {
                    if let tab = tabManager.activeTab {
                        tabManager
                            .togglePinTab(tab)
                    }
                }
                .keyboardShortcut(
                    KeyboardShortcuts.Tabs.pin
                )
                Button("Reload") {
                    if let tab = tabManager.activeTab {
                        tab.webView.reload()
                    }
                }
                .keyboardShortcut(
                    KeyboardShortcuts.Navigation.reload
                )
                Button("Forward") {
                    if let tab = tabManager.activeTab {
                        tab.webView.reload()
                    }
                }
                .keyboardShortcut(
                    KeyboardShortcuts.Navigation.reload
                )
            }
        }
    }
}
