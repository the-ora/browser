import AppKit
import SwiftUI

struct LauncherView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var historyManager: HistoryManager
    @EnvironmentObject var downloadManager: DownloadManager
    @Environment(\.theme) private var theme
    @StateObject private var searchEngineService = SearchEngineService()
    @StateObject private var faviconService = FaviconService()

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
                faviconService: faviconService,
                customEngine: customEngine
            )
            input = ""
        }
    }

    private func onSubmit(_ newInput: String? = nil) {
        let correctInput = newInput ?? input
        var engineToUse = match

        if engineToUse == nil,
           let defaultEngine = searchEngineService.getDefaultSearchEngine(for: tabManager.activeContainer?.id)
        {
            let customEngine = searchEngineService.settings.customSearchEngines
                .first { $0.searchURL == defaultEngine.searchURL }
            engineToUse = defaultEngine.toLauncherMatch(
                originalAlias: correctInput,
                faviconService: faviconService,
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
                    downloadManager: downloadManager
                )
        }
        appState.showLauncher = false
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(clearOverlay! ? 0 : 0.3)
                .ignoresSafeArea()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .animation(.easeOut(duration: 0.3), value: isVisible)
                .onTapGesture {
                    if tabManager.activeTab != nil {
                        isVisible = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
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
            .scaleEffect(isVisible ? 1.0 : 0.85)
            .opacity(isVisible ? 1.0 : 0.0)
            .blur(radius: isVisible ? 0 : 2)
            .offset(y: 250)
            .animation(
                isVisible
                    ? .spring(response: 0.15, dampingFraction: 0.5, blendDuration: 0.2)
                    : .easeOut(duration: 0.1),
                value: isVisible
            )
            .onAppear {
                isVisible = true
                isTextFieldFocused = true
                searchEngineService.setTheme(theme)
            }
            .onChange(of: appState.showLauncher) { _, newValue in
                isVisible = newValue
            }
            // .onChange(of: theme) { _, newValue in
            //     searchEngineService.setTheme(newValue)
            // }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onExitCommand {
            isVisible = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                appState.showLauncher = false
            }
        }
    }
}
