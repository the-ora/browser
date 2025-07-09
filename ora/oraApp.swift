import SwiftUI
import SwiftData

@main
struct oraApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            BrowserViewController()
                .background(VisualEffectView())
        }
        .defaultSize(width: 1440, height: 900)
        .windowStyle(.hiddenTitleBar)
    }
}
