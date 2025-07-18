import SwiftUI
import SwiftData

class AppState: ObservableObject {
    @Published var showLauncher: Bool = false
    @Published var launcherSearchText: String = ""
}
@main
struct oraApp: App {
    @StateObject private var appState = AppState()

    // Create model container and context once
    private let modelContainer: ModelContainer = {
        do {
            return try ModelContainer(for: Tab.self, TabContainer.self)
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }()
    private var modelContext: ModelContext {
        ModelContext(modelContainer)
    }

    // Pass it to TabManager
    @StateObject private var tabManager: TabManager

    init() {
        let container: ModelContainer
        do {
            container = try ModelContainer(for: TabContainer.self)
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }

        let context = ModelContext(container)
        _tabManager = StateObject(wrappedValue: TabManager(modelContainer: container, modelContext: context))
    }

    var body: some Scene {
        WindowGroup {
            BrowserViewController()
                .environmentObject(appState)
                .environmentObject(tabManager)
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
