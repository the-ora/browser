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
    let context: ModelContext
    
    init() {
        //#if DEBUG
//                    deleteSwiftDataStore()
        //#endif
        let container: ModelContainer
        let modelContext: ModelContext
        do {
            let modelConfiguration = ModelConfiguration(
                "MyModel",
                schema: Schema([TabContainer.self]),
                url: URL.applicationSupportDirectory.appending(path: "MyStore.sqlite")
            )
            container = try ModelContainer(
                for: TabContainer.self,
                configurations: modelConfiguration
            )
            modelContext = ModelContext(container)
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
        
        self.context = modelContext
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
                .modelContext(context)
                .background(VisualEffectView())
                .withTheme()
        }
        .defaultSize(width: 1440, height: 900)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Tab") {
                    appState.showLauncher = true
                }
                .keyboardShortcut("t", modifiers: .command)
            }
        }
    }
}
