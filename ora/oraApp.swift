import AppKit
import Foundation
import SwiftData
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Disable automatic window tabbing for all NSWindow instances
        NSWindow.allowsAutomaticWindowTabbing = false
        AppearanceManager.shared.updateAppearance()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let targetWindow = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible })
        guard let targetWindow else { return .terminateNow }
        NotificationCenter.default.post(name: .quitRequested, object: targetWindow)
        return .terminateLater
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        handleIncomingURLs(urls)
    }

    func getWindow() -> NSWindow? {
        if let key = NSApp.keyWindow { return key }
        if let visible = NSApp.windows.first(where: { $0.isVisible }) { return visible }
        if let any = NSApp.windows.first {
            any.makeKeyAndOrderFront(nil)
            return any
        }
        return WindowFactory.makeMainWindow(rootView: OraRoot())
    }

    func handleIncomingURLs(_ urls: [URL]) {
        let window = getWindow()!
        for url in urls {
            let userInfo: [AnyHashable: Any] = ["url": url]
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .openURL, object: window, userInfo: userInfo)
            }
        }
    }
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
    @Published var isFullscreen: Bool = false
}

@main
struct OraApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    /// Shared model container that uses the same configuration as the main browser
    private let sharedModelContainer: ModelContainer? =
        try? ModelConfiguration.createOraContainer(isPrivate: false)

    var body: some Scene {
        WindowGroup(id: "normal") {
            OraRoot()
                .frame(minWidth: 500, minHeight: 360)
                .environmentObject(DefaultBrowserManager.shared)
        }
        .defaultSize(width: 1440, height: 900)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .handlesExternalEvents(matching: [])

        WindowGroup("Private", id: "private") {
            OraRoot(isPrivate: true)
                .frame(minWidth: 500, minHeight: 360)
                .environmentObject(DefaultBrowserManager.shared)
        }
        .defaultSize(width: 1440, height: 900)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .handlesExternalEvents(matching: [])

        Settings {
            if let sharedModelContainer {
                SettingsContentView()
                    .environmentObject(AppearanceManager.shared)
                    .environmentObject(UpdateService.shared)
                    .environmentObject(DefaultBrowserManager.shared)
                    .withTheme()
                    .modelContainer(sharedModelContainer)
            } else {
                // Fallback UI when SwiftData is completely broken
                VStack {
                    Text("Settings Unavailable")
                        .font(.title)
                }
                .padding()
                .frame(width: 400, height: 300)
            }
        }
        .commands { OraCommands() }
    }
}

#if canImport(HotSwiftUI)
    @_exported import HotSwiftUI
#elseif canImport(Inject)
    @_exported import Inject
#else
    // This code can be found in the Swift package:
    // https://github.com/johnno1962/HotSwiftUI or
    // https://github.com/krzysztofzablocki/Inject

    #if DEBUG
        import Combine

        public class InjectionObserver: ObservableObject {
            public static let shared = InjectionObserver()
            @Published var injectionNumber = 0
            var cancellable: AnyCancellable?
            let publisher = PassthroughSubject<Void, Never>()
            init() {
                cancellable = NotificationCenter.default.publisher(for:
                    Notification.Name("INJECTION_BUNDLE_NOTIFICATION"))
                    .sink { [weak self] _ in
                        self?.injectionNumber += 1
                        self?.publisher.send()
                    }
            }
        }

        public extension SwiftUI.View {
            func eraseToAnyView() -> some SwiftUI.View {
                return AnyView(self)
            }

            func enableInjection() -> some SwiftUI.View {
                return eraseToAnyView()
            }

            func onInjection(bumpState: @escaping () -> Void) -> some SwiftUI.View {
                return self
                    .onReceive(InjectionObserver.shared.publisher, perform: bumpState)
                    .eraseToAnyView()
            }
        }

        @available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
        @propertyWrapper
        public struct ObserveInjection: DynamicProperty {
            @ObservedObject private var iO = InjectionObserver.shared
            public init() {}
            public private(set) var wrappedValue: Int {
                get { 0 } set {}
            }
        }
    #else
        public extension SwiftUI.View {
            @inline(__always)
            func eraseToAnyView() -> some SwiftUI.View {
                return self
            }

            @inline(__always)
            func enableInjection() -> some SwiftUI.View {
                return self
            }

            @inline(__always)
            func onInjection(bumpState: @escaping () -> Void) -> some SwiftUI.View {
                return self
            }
        }

        @available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
        @propertyWrapper
        public struct ObserveInjection {
            public init() {}
            public private(set) var wrappedValue: Int {
                get { 0 } set {}
            }
        }
    #endif
#endif
