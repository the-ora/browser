import AppKit
import SwiftUI

struct SearchEngine {
  let name: String
  let color: Color
  let icon: String
  let aliases: [String]
  let foregroundColor: Color?
  let searchURL: String

  init(
    name: String, color: Color, icon: String, aliases: [String], foregroundColor: Color? = nil,
    searchURL: String
  ) {
    self.name = name
    self.color = color
    self.icon = icon
    self.aliases = aliases
    self.foregroundColor = foregroundColor
    self.searchURL = searchURL
  }
}

struct LauncherView: View {
  @EnvironmentObject var appState: AppState
  @EnvironmentObject var tabManager: TabManager
  @Environment(\.theme) private var theme

  @State private var input = ""
  @State private var isVisible = false
  @FocusState private var isTextFieldFocused: Bool
  @State private var match: LauncherInput.Match? = nil

  private var searchEngines: [SearchEngine] {
    [
      SearchEngine(
        name: "YouTube",
        color: Color(hex: "#FC0D1B"),
        icon: "",
        aliases: ["youtube", "you", "youtu", "yo", "yt"],
        searchURL: "https://www.youtube.com/results?search_query={query}"
      ),
      SearchEngine(
        name: "ChatGPT",
        color: theme.foreground,
        icon: "openai-capsule-logo",
        aliases: ["chat", "chatgpt", "gpt", "cgpt", "openai", "cha"],
        foregroundColor: theme.foreground,
        searchURL: "https://chatgpt.com?q={query}"
      ),
      SearchEngine(
        name: "Google",
        color: .blue,
        icon: "",
        aliases: ["google", "goo", "g", "search"],
        searchURL: "https://www.google.com/search?q={query}"
      ),
      SearchEngine(
        name: "Grok",
        color: theme.foreground,
        icon: "grok-capsule-logo",
        aliases: ["grok", "gr", "gro"],
        foregroundColor: theme.foreground,
        searchURL: "https://grok.com?q={query}"
      ),
      SearchEngine(
        name: "Perplexity",
        color: Color(hex: "#20808D"),
        icon: "perplexity-capsule-logo",
        aliases: ["perplexity", "perplex", "pplx", "ppl", "per"],
        searchURL: "https://www.perplexity.ai/search?q={query}"
      ),
      SearchEngine(
        name: "Reddit",
        color: Color(hex: "#FF4500"),
        icon: "reddit-capsule-logo",
        aliases: ["reddit", "r", "rd", "rdit", "red"],
        searchURL: "https://www.reddit.com/search/?q={query}"
      ),
      SearchEngine(
        name: "T3Chat",
        color: Color(hex: "#960971"),
        icon: "t3chat-capsule-logo",
        aliases: ["t3chat", "t3", "t3c", "tchat"],
        searchURL: "https://t3.chat/new?q={query}"
      ),
      SearchEngine(
        name: "X",
        color: theme.foreground,
        icon: "",
        aliases: ["x", "x.com", "twitter", "tw", "twtr", "twit", "twitt", "twitte"],
        foregroundColor: theme.foreground,
        searchURL: "https://twitter.com/search?q={query}"
      ),
    ]
  }
  
  var body: some View {
    ZStack {
      Color.black.opacity(0.5)
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

      LauncherInput(
        text: $input,
        match: $match,
        isFocused: $isTextFieldFocused,
        onTabPress: {
          guard !input.isEmpty else { return }
          let textLowercased = input.lowercased()
          if let searchEngine = searchEngines.first(where: { $0.aliases.contains(textLowercased) })
          {
            match = LauncherInput.Match(
              text: searchEngine.name,
              color: searchEngine.color,
              foregroundColor: searchEngine.foregroundColor ?? .white,
              icon: searchEngine.icon,
              originalAlias: input,
              searchURL: searchEngine.searchURL
            )
            input = ""
          }
        },
        onSubmit: {
          let encodedQuery =
            input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
          let engineToUse =
            match
            ?? {
              guard let engine = searchEngines.first(where: { $0.name == "Google" }) else {
                return nil
              }
              return LauncherInput.Match(
                text: engine.name,
                color: engine.color,
                foregroundColor: engine.foregroundColor ?? .white,
                icon: engine.icon,
                originalAlias: input,
                searchURL: engine.searchURL
              )
            }()

          if let engine = engineToUse {
            let urlString = engine.searchURL.replacingOccurrences(of: "{query}", with: encodedQuery)
            if let url = URL(string: urlString) {
              tabManager.openTab(url: url)
            }
          }
          appState.showLauncher = false
          //            isTextFieldFocused = false

        }
      )
      .gradientAnimatingBorder(
        color: match?.color ?? .clear,
        trigger: match != nil
      )
      .frame(width: 500, height: 50)
      .offset(y: isVisible ? -150 : -140)
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
