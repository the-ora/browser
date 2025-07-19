import AppKit
import SwiftUI

struct LauncherView: View {
  @EnvironmentObject var appState: AppState
  @EnvironmentObject var tabManager: TabManager
  @Environment(\.theme) private var theme
  @StateObject private var searchEngineService = SearchEngineService()

  @State private var input = ""
  @State private var isVisible = false
  @FocusState private var isTextFieldFocused: Bool
  @State private var match: LauncherMain.Match? = nil

  private func onTabPress() {
    guard !input.isEmpty else { return }
    if let searchEngine = searchEngineService.findSearchEngine(for: input) {
      match = searchEngine.toLauncherMatch(originalAlias: input)
      input = ""
    }
  }

  private func onSubmit() {
    let engineToUse =
      match
      ?? searchEngineService.getDefaultSearchEngine()?.toLauncherMatch(originalAlias: input)

    if let engine = engineToUse,
      let url = searchEngineService.createSearchURL(for: engine, query: input)
    {
      tabManager.openTab(url: url)
    }
    appState.showLauncher = false
  }

  var body: some View {
    ZStack(alignment: .top) {
      Color.black.opacity(0.3)
        .ignoresSafeArea()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.3), value: isVisible)
        .onTapGesture {
          isVisible = false
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            appState.showLauncher = false
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
