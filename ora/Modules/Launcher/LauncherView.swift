import AppKit
import SwiftUI

struct LauncherView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var toolbarManager: ToolbarManager
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var historyManager: HistoryManager
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var privacyMode: PrivacyMode
    @Environment(\.theme) private var theme
    @StateObject private var searchEngineService = SearchEngineService()

    @State private var input = ""
    @State private var isVisible = false
    @FocusState private var isTextFieldFocused: Bool
    @State private var match: LauncherMain.Match?

    var clearOverlay: Bool? = false

    private func onTabPress() {
        guard !input.isEmpty else { return }
        if let searchEngine = searchEngineService.findSearchEngine(for: input) {
            let customEngine = searchEngineService.settings.customSearchEngines
                .first { $0.searchURL == searchEngine.searchURL }
            match = searchEngine.toLauncherMatch(
                originalAlias: input,
                customEngine: customEngine
            )
            input = ""
        }
    }

    private func onSubmit(_ newInput: String? = nil) {
        let correctInput = newInput ?? input
        var engineToUse = match

        if engineToUse == nil,
           let defaultEngine = searchEngineService.getDefaultSearchEngine(
               for: tabManager.activeContainer?.id
           )
        {
            let customEngine = searchEngineService.settings.customSearchEngines
                .first { $0.searchURL == defaultEngine.searchURL }
            engineToUse = defaultEngine.toLauncherMatch(
                originalAlias: correctInput,
                customEngine: customEngine
            )
        }

        if let engine = engineToUse,
           let url = searchEngineService.createSearchURL(for: engine, query: correctInput)
        {
            tabManager
                .openTab(
                    url: url,
                    historyManager: historyManager,
                    downloadManager: downloadManager,
                    isPrivate: privacyMode.isPrivate
                )
        }
        appState.showLauncher = false
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(clearOverlay! ? 0 : 0.3)
                .ignoresSafeArea()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeOut(duration: 0.1), value: isVisible)
                .onTapGesture {
                    if tabManager.activeTab != nil {
                        isVisible = false
                        DispatchQueue.main.async {
                            appState.showLauncher = false
                        }
                    }
                }

            LauncherMain(
                text: $input,
                match: $match,
                isFocused: $isTextFieldFocused,
                onTabPress: onTabPress,
                onSubmit: onSubmit
            )
            .gradientAnimatingBorder(
                color: match?.faviconBackgroundColor ?? match?.color ?? .clear,
                trigger: match != nil
            )
            .padding(.horizontal, 20)  // Add horizontal margins around the search bar
            .offset(y: 250)
            .scaleEffect(isVisible ? 1.0 : 0.9)
            .opacity(isVisible ? 1.0 : 0.0)
            .blur(radius: isVisible ? 0 : 2)
            .animation(.easeOut(duration: 0.1), value: isVisible)
            .onAppear {
                isVisible = true
                isTextFieldFocused = true
                searchEngineService.setTheme(theme)
            }
            .onChange(of: appState.showLauncher) { _, newValue in
                isVisible = newValue
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onExitCommand {
            if tabManager.activeTab != nil {
                isVisible = false
                DispatchQueue.main.async {
                    appState.showLauncher = false
                }
            }
        }
    }
}
