import SwiftUI
import SwiftData
import Foundation

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
    @Published var showFinderIn: UUID? = nil
}
@main
struct oraApp: App {
    @StateObject private var appState = AppState()
    
    // Pass it to TabManager
    @StateObject private var tabManager: TabManager
    @StateObject private var historyManager: HistoryManager
    @StateObject private var downloadManager: DownloadManager
    
    let tabContext: ModelContext
    let historyContext: ModelContext
    let downloadContext: ModelContext
    
    let tabModelConfiguration = ModelConfiguration(
        "Tab",
        schema: Schema([TabContainer.self]),
        url: URL.applicationSupportDirectory.appending(path: "Tabs.sqlite")
    )
    let historyModelConfiguration = ModelConfiguration(
        "History",
        schema: Schema([History.self]),
        url: URL.applicationSupportDirectory.appending(path: "History.sqlite")
    )
    let downloadModelConfiguration = ModelConfiguration(
        "Download",
        schema: Schema([Download.self]),
        url: URL.applicationSupportDirectory.appending(path: "Download.sqlite")
    )
    init() {
        //#if DEBUG
//        deleteSwiftDataStore("Tabs.sqlite")
//        deleteSwiftDataStore("History.sqlite")
//        deleteSwiftDataStore("Download.sqlite")
        //#endif
//        
        // tabs
        let container: ModelContainer
        let modelContext: ModelContext
        do {
           
            container = try ModelContainer(
                for: TabContainer.self,
                configurations: tabModelConfiguration
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
                configurations: historyModelConfiguration
            )
            historyModelContext = ModelContext(historyContainer)
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
        // downloads
        let downloadContainer: ModelContainer
        let downloadModelContext: ModelContext
        do {
           
            downloadContainer = try ModelContainer(
                for: Download.self,
                configurations: downloadModelConfiguration
            )
            downloadModelContext = ModelContext(downloadContainer)
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
        
        self.tabContext = modelContext
        self.downloadContext = downloadModelContext
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
        
        _downloadManager = StateObject(
            wrappedValue: DownloadManager(
                modelContainer: downloadContainer,
                modelContext: downloadModelContext
            )
        )
        
    }
    
    var body: some Scene {
        WindowGroup {
            BrowserViewController()
                .environmentObject(appState)
                .environmentObject(tabManager)
                .environmentObject(historyManager)
                .environmentObject(downloadManager)
                .modelContext(tabContext)
                .modelContext(historyContext)
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
        }
    }
}
