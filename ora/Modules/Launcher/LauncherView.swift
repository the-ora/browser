import AppKit
import SwiftUI

struct LauncherView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var historyManager: HistoryManager
    @EnvironmentObject var downloadManager: DownloadManager
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
            match = searchEngine.toLauncherMatch(originalAlias: input)
            input = ""
        }
    }

    private func onSubmit(_ newInput: String? = nil) {
        let correctInput = newInput ?? input
        let engineToUse =
            match
                ?? searchEngineService.getDefaultSearchEngine(for: tabManager.activeContainer?.id)?
                .toLauncherMatch(originalAlias: correctInput)

        if let engine = engineToUse,
           let url = searchEngineService.createSearchURL(for: engine, query: correctInput) {
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
                color: match?.color ?? .clear,
                trigger: match != nil
            )
            .offset(y: isVisible ? 250 : 240)
            .scaleEffect(isVisible ? 1.0 : 0.85)
            .opacity(isVisible ? 1.0 : 0.0)
            .blur(radius: isVisible ? 0 : 2)
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
