import Foundation
import SwiftData
import SwiftUI

final class PrivacyMode: ObservableObject {
    @Published var isPrivate: Bool

    init(isPrivate: Bool) {
        self.isPrivate = isPrivate
    }
}

struct OraRoot: View {
    @StateObject private var appState = AppState()
    @StateObject private var keyModifierListener = KeyModifierListener()
    @StateObject private var appearanceManager = AppearanceManager()
    @StateObject private var updateService = UpdateService()
    @StateObject private var mediaController: MediaController
    @StateObject private var tabManager: TabManager
    @StateObject private var historyManager: HistoryManager
    @StateObject private var downloadManager: DownloadManager
    @StateObject private var privacyMode: PrivacyMode

    let tabContext: ModelContext
    let historyContext: ModelContext
    let downloadContext: ModelContext
    @State private var window: NSWindow?

    init(isPrivate: Bool = false) {
        _privacyMode = StateObject(wrappedValue: PrivacyMode(isPrivate: isPrivate))
        let modelConfiguration = isPrivate ? ModelConfiguration(isStoredInMemoryOnly: true) : ModelConfiguration(
            "OraData",
            schema: Schema([TabContainer.self, History.self, Download.self]),
            url: URL.applicationSupportDirectory.appending(path: "OraData.sqlite")
        )

        let container: ModelContainer
        let modelContext: ModelContext
        do {
            container = try ModelContainer(
                for: TabContainer.self, History.self, Download.self,
                configurations: modelConfiguration
            )
            modelContext = ModelContext(container)
        } catch {
            deleteSwiftDataStore("OraData.sqlite")
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

        let media = MediaController()
        _mediaController = StateObject(wrappedValue: media)

        _tabManager = StateObject(
            wrappedValue: TabManager(
                modelContainer: container,
                modelContext: modelContext,
                mediaController: media
            )
        )

        _downloadManager = StateObject(
            wrappedValue: DownloadManager(
                modelContainer: container,
                modelContext: modelContext
            )
        )
    }

    var body: some View {
        BrowserView()
            .background(WindowReader(window: $window))
            .environmentObject(appState)
            .environmentObject(tabManager)
            .environmentObject(historyManager)
            .environmentObject(mediaController)
            .environmentObject(keyModifierListener)
            .environmentObject(CustomKeyboardShortcutManager.shared)
            .environmentObject(appearanceManager)
            .environmentObject(downloadManager)
            .environmentObject(updateService)
            .environmentObject(privacyMode)
            .modelContext(tabContext)
            .modelContext(historyContext)
            .modelContext(downloadContext)
            .withTheme()
            .onAppear {
                keyModifierListener.registerKeyDownHandler { event in
                    guard !appState.isFloatingTabSwitchVisible else { return false }

                    if event.keyCode == 48 {
                        if event.modifierFlags.contains(.control) {
                            DispatchQueue.main.async {
                                appState.isFloatingTabSwitchVisible = true
                            }
                            return true
                        }
                    }
                    return false
                }

                if SettingsStore.shared.autoUpdateEnabled {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        updateService.checkForUpdatesInBackground()
                    }
                }
                NotificationCenter.default.addObserver(forName: .showLauncher, object: nil, queue: .main) { note in
                    guard note.object as? NSWindow === window ?? NSApp.keyWindow else { return }
                    if tabManager.activeTab != nil {
                        appState.showLauncher.toggle()
                    }
                }
                NotificationCenter.default.addObserver(forName: .closeActiveTab, object: nil, queue: .main) { note in
                    guard note.object as? NSWindow === window ?? NSApp.keyWindow else { return }
                    tabManager.closeActiveTab()
                }
                NotificationCenter.default.addObserver(forName: .restoreLastTab, object: nil, queue: .main) { note in
                    guard note.object as? NSWindow === window ?? NSApp.keyWindow else { return }
                    tabManager.restoreLastTab()
                }
                NotificationCenter.default.addObserver(forName: .findInPage, object: nil, queue: .main) { note in
                    guard note.object as? NSWindow === window ?? NSApp.keyWindow else { return }
                    if let activeTab = tabManager.activeTab { appState.showFinderIn = activeTab.id }
                }
                NotificationCenter.default.addObserver(forName: .toggleFullURL, object: nil, queue: .main) { note in
                    guard note.object as? NSWindow === window ?? NSApp.keyWindow else { return }
                    appState.showFullURL.toggle()
                }
                NotificationCenter.default.addObserver(forName: .toggleToolbar, object: nil, queue: .main) { note in
                    guard note.object as? NSWindow === window ?? NSApp.keyWindow else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appState.isToolbarHidden.toggle()
                    }
                }
                NotificationCenter.default.addObserver(forName: .reloadPage, object: nil, queue: .main) { note in
                    guard note.object as? NSWindow === window ?? NSApp.keyWindow else { return }
                    tabManager.activeTab?.webView.reload()
                }
                NotificationCenter.default.addObserver(forName: .goBack, object: nil, queue: .main) { note in
                    guard note.object as? NSWindow === window ?? NSApp.keyWindow else { return }
                    tabManager.activeTab?.webView.goBack()
                }
                NotificationCenter.default.addObserver(forName: .goForward, object: nil, queue: .main) { note in
                    guard note.object as? NSWindow === window ?? NSApp.keyWindow else { return }
                    tabManager.activeTab?.webView.goForward()
                }
                NotificationCenter.default.addObserver(forName: .togglePinTab, object: nil, queue: .main) { note in
                    guard note.object as? NSWindow === window ?? NSApp.keyWindow else { return }
                    if let tab = tabManager.activeTab { tabManager.togglePinTab(tab) }
                }
                NotificationCenter.default.addObserver(forName: .nextTab, object: nil, queue: .main) { note in
                    guard note.object as? NSWindow === window ?? NSApp.keyWindow else { return }
                    appState.isFloatingTabSwitchVisible = true
                }
                NotificationCenter.default.addObserver(forName: .previousTab, object: nil, queue: .main) { note in
                    guard note.object as? NSWindow === window ?? NSApp.keyWindow else { return }
                    appState.isFloatingTabSwitchVisible = true
                }
                NotificationCenter.default.addObserver(forName: .setAppearance, object: nil, queue: .main) { note in
                    guard note.object as? NSWindow === window ?? NSApp.keyWindow else { return }
                    if let raw = note.userInfo?["appearance"] as? String,
                       let mode = AppAppearance(rawValue: raw)
                    {
                        appearanceManager.appearance = mode
                    }
                }
                NotificationCenter.default.addObserver(forName: .checkForUpdates, object: nil, queue: .main) { note in
                    guard note.object as? NSWindow === window ?? NSApp.keyWindow else { return }
                    updateService.checkForUpdates()
                }
                NotificationCenter.default.addObserver(forName: .selectTabAtIndex, object: nil, queue: .main) { note in
                    guard note.object as? NSWindow === window ?? NSApp.keyWindow else { return }
                    if let index = note.userInfo?["index"] as? Int {
                        tabManager.selectTabAtIndex(index)
                    }
                }
            }
    }
}
