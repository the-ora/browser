import AppKit
import SwiftUI

extension Color {
  init(hex: String) {
    let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&int)
    let a: UInt64
    let r: UInt64
    let g: UInt64
    let b: UInt64
    switch hex.count {
    case 3:  // RGB (12-bit)
      (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
    case 6:  // RGB (24-bit)
      (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
    case 8:  // ARGB (32-bit)
      (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
    default:
      (a, r, g, b) = (1, 1, 1, 0)
    }

    self.init(
      .sRGB,
      red: Double(r) / 255,
      green: Double(g) / 255,
      blue: Double(b) / 255,
      opacity: Double(a) / 255
    )
  }
}

enum ShadowPopPhase: CaseIterable {
  case idle, validating, decrease, increase, finished
}

struct SearchEngineCapsule: View {
  let text: String
  let color: Color
  let foregroundColor: Color
  let icon: String

  var body: some View {
    HStack(alignment: .center, spacing: 8) {
      if icon.isEmpty {
        Image(systemName: "magnifyingglass")
          .resizable()
          .frame(width: 16, height: 16)
          .foregroundStyle(foregroundColor)
      } else {
        Image(icon)
          .resizable()
          .frame(width: 16, height: 16)
          .foregroundStyle(foregroundColor)
      }
      Text(text)
        .font(.callout)
        .bold()
        .foregroundStyle(foregroundColor)
    }
    .padding(.vertical, 6)
    .padding(.horizontal, 12)
    .frame(alignment: .leading)
    .background(color)
    .cornerRadius(99)
  }
}

enum LauncherResultType: CaseIterable {
  case openedTab, suggestedQuery, suggestedLink, aiSearch
}

struct LauncherResultTile: View {
  let type: LauncherResultType
  let title: String
  let url: URL?
  let icon: Image?
  let backgroundColor: Color?
  let foregroundColor: Color?
  let action: () -> Void

  @State private var isHovered = false
  @State private var isFocused = false

  var openButtonText: String {
    switch type {
    case .openedTab:
      return "Switch to tab"
    case .aiSearch:
      return "Ask \"\(title)\""
    default:
      return "Open"
    }
  }

  var body: some View {
    HStack(alignment: .center, spacing: 8) {
      if type == .suggestedQuery {
        Image(systemName: "magnifyingglass")
          .resizable()
          .frame(width: 16, height: 16)
          .foregroundStyle(foregroundColor ?? (isFocused || isHovered ? .blue : .primary))
      } else if let icon = icon {
        icon
          .resizable()
          .frame(width: 16, height: 16)
          .foregroundStyle(foregroundColor ?? (isFocused || isHovered ? .blue : .primary))
      }

      HStack(alignment: .center, spacing: 8) {
        Text(title)
          .font(.system(size: 18, weight: .medium))
          .bold()
          .foregroundStyle(foregroundColor ?? (isFocused || isHovered ? .blue : .primary))
        if let url = url {
          Text(" — \(url)")
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(Color(.secondaryLabelColor))
        }
      }
      Spacer()
      Button(action: action) {
        HStack(alignment: .center, spacing: 10) {
          Text(openButtonText)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Color(.secondaryLabelColor))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.black.opacity(0.07))
        .cornerRadius(6)
      }
      .buttonStyle(PlainButtonStyle())
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 10)
    .frame(width: 798, alignment: .leading)
    .background(backgroundColor ?? Color.white.opacity(0.9))
    .cornerRadius(8)
    .onHover { hover in
      isHovered = hover
    }
    .focusable()
  }
}

struct LauncherResultsView: View {
  var body: some View {
    HStack {
      Text("Results")
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(.white).opacity(0.9))
  }
}

struct LauncherTextField: NSViewRepresentable {
  @Binding var text: String
  var font: NSFont
  let onTab: () -> Void
  let onDelete: () -> Bool
  var cursorColor: Color
  var placeholder: String

  class CustomTextField: NSTextField {
    var cursorColor: NSColor?

    override func becomeFirstResponder() -> Bool {
      let didBecome = super.becomeFirstResponder()
      if didBecome, let textView = currentEditor() as? NSTextView, let color = cursorColor {
        textView.insertionPointColor = color
      }
      return didBecome
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  func makeNSView(context: Context) -> CustomTextField {
    let textField = CustomTextField()
    textField.delegate = context.coordinator
    textField.font = font
    textField.bezelStyle = .roundedBezel
    textField.isBordered = false
    textField.focusRingType = .none
    textField.drawsBackground = false
    textField.placeholderString = placeholder
    return textField
  }

  func updateNSView(_ nsView: CustomTextField, context: Context) {
    nsView.stringValue = text
    nsView.cursorColor = NSColor(cursorColor)
    nsView.placeholderString = placeholder
    if let textView = nsView.currentEditor() as? NSTextView {
      textView.insertionPointColor = nsView.cursorColor
    }
  }

  class Coordinator: NSObject, NSTextFieldDelegate {
    var parent: LauncherTextField

    init(_ parent: LauncherTextField) {
      self.parent = parent
    }

    func controlTextDidChange(_ obj: Notification) {
      if let textField = obj.object as? NSTextField {
        parent.text = textField.stringValue
      }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool
    {
      if selector == #selector(NSResponder.insertTab(_:)) {
        parent.onTab()
        return true
      } else if selector == #selector(NSResponder.deleteBackward(_:)) {
        return parent.onDelete()
      }
      return false
    }
  }
}

struct LauncherInput: View {
  struct Match {
    let text: String
    let color: Color
    let foregroundColor: Color
    let icon: String
    let originalAlias: String
  }
  @Binding var text: String
  @Binding var match: Match?
  var isFocused: FocusState<Bool>.Binding
  let onTabPress: () -> Void
  @Environment(\.colorScheme) var colorScheme

  var results: [(id: String, tile: LauncherResultTile)] {
    [
      (
        "tab1",
        LauncherResultTile(
          type: .openedTab, title: "Tab 1", url: nil, icon: nil, backgroundColor: nil,
          foregroundColor: nil, action: { print("Debug: Executing action for Tab 1") })
      ),
      (
        "query",
        LauncherResultTile(
          type: .suggestedQuery, title: "Search for \"\(text)\"", url: nil, icon: nil,
          backgroundColor: nil, foregroundColor: nil,
          action: { print("Debug: Executing action for suggested query") })
      ),
      (
        "link",
        LauncherResultTile(
          type: .suggestedLink, title: "Open link", url: URL(string: "https://www.google.com"),
          icon: nil, backgroundColor: nil, foregroundColor: nil,
          action: { print("Debug: Executing action for suggested link") })
      ),
      (
        "ai",
        LauncherResultTile(
          type: .aiSearch, title: "Ask \"\(text)\"", url: nil, icon: nil, backgroundColor: nil,
          foregroundColor: nil, action: { print("Debug: Executing action for AI search") })
      ),
    ]
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .center, spacing: 8) {
        if match == nil {
          Image(systemName: getIconName(match: match, text: text))
            .resizable()
            .frame(width: 18, height: 18)
            .foregroundStyle(Color(.placeholderTextColor))
        }

        if match != nil {
          SearchEngineCapsule(
            text: match?.text ?? "",
            color: match?.color ?? .blue,
            foregroundColor: match?.foregroundColor ?? .white,
            icon: match?.icon ?? ""
          )
        }
        LauncherTextField(
          text: $text,
          font: NSFont.systemFont(ofSize: 18, weight: .medium),
          onTab: onTabPress,
          onDelete: {
            if text.isEmpty && match != nil {
              text = match!.originalAlias
              match = nil
              return true
            }
            return false
          },
          cursorColor: match?.color ?? (colorScheme == .dark ? .white : .black),
          placeholder: getPlaceholder(match: match)
        )
        .textFieldStyle(PlainTextFieldStyle())
        .focused(isFocused)
      }
      .animation(nil, value: match?.color)
      .padding(.horizontal, 8)
      .padding(.vertical, 10)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(8)
    .frame(width: 814, alignment: .leading)
    .background(Color(colorScheme == .dark ? .windowBackgroundColor : .white).opacity(0.8))
    .background(BlurEffectView(material: .popover, blendingMode: .withinWindow))
    .cornerRadius(16)
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .inset(by: 0.25)
        .stroke(
          Color(match?.color ?? (colorScheme == .dark ? .white : .black)).opacity(0.15),
          lineWidth: 0.5)
    )
    .shadow(
      color: Color.black.opacity(0.3),
      radius: 40, x: 0, y: 24
    )
  }

  private func getPlaceholder(match: Match?) -> String {
    if match == nil {
      return "Search the web or enter url..."
    }
    switch match!.text {
    case "X":
      return "Search on X"
    case "Youtube":
      return "Search on Youtube"
    case "Google":
      return "Search on Google"
    case "ChatGPT":
      return "Ask ChatGPT"
    case "Grok":
      return "Ask Grok"
    case "Perplexity":
      return "Ask Perplexity"
    case "Reddit":
      return "Search on Reddit"
    case "T3Chat":
      return "Ask T3Chat"
    default:
      return "Search on \(match!.text)"
    }
  }

  private func isDomainOrIP(_ text: String) -> Bool {
    let cleanText = text.replacingOccurrences(of: "https://", with: "")
      .replacingOccurrences(of: "http://", with: "")
      .replacingOccurrences(of: "www.", with: "")

    let ipPattern = #"^(\d{1,3}\.){3}\d{1,3}$"#
    if cleanText.range(of: ipPattern, options: .regularExpression) != nil {
      return true
    }

    let domainPattern =
      #"^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$"#
    return cleanText.range(of: domainPattern, options: .regularExpression) != nil
      && cleanText.contains(".")
  }

  private func getIconName(match: Match?, text: String) -> String {
    if match != nil {
      return "magnifyingglass"
    }
    return isDomainOrIP(text) ? "globe" : "magnifyingglass"
  }
}

struct SearchEngine {
  let name: String
  let color: Color
  let icon: String
  let aliases: [String]
  let foregroundColor: Color?

  init(name: String, color: Color, icon: String, aliases: [String], foregroundColor: Color? = nil) {
    self.name = name
    self.color = color
    self.icon = icon
    self.aliases = aliases
    self.foregroundColor = foregroundColor
  }
}

struct LauncherView: View {
  @EnvironmentObject var appState: AppState
  @State private var input = ""
  @State private var match: LauncherInput.Match? = nil
  @FocusState private var isTextFieldFocused: Bool
  @Environment(\.colorScheme) var colorScheme
  @State private var isVisible = false

  private var searchEngines: [SearchEngine] {
    [
      SearchEngine(
        name: "Youtube", color: Color(hex: "#FC0D1B"), icon: "",
        aliases: ["youtube", "you", "youtu", "yo", "yt"]),
      SearchEngine(
        name: "ChatGPT", color: colorScheme == .dark ? .white : .black, icon: "openai-capsule-logo",
        aliases: ["chat", "chatgpt", "gpt", "cgpt", "openai", "cha"],
        foregroundColor: colorScheme == .dark ? .black : .white),
      SearchEngine(
        name: "Google", color: .blue, icon: "", aliases: ["google", "goo", "g", "search"]),
      SearchEngine(
        name: "Grok", color: colorScheme == .dark ? .white : .black, icon: "grok-capsule-logo",
        aliases: ["grok", "gr", "gro"], foregroundColor: colorScheme == .dark ? .black : .white),
      SearchEngine(
        name: "Perplexity", color: Color(hex: "#20808D"), icon: "perplexity-capsule-logo",
        aliases: ["perplexity", "perplex", "pplx", "ppl", "per"]),
      SearchEngine(
        name: "Reddit", color: Color(hex: "#FF4500"), icon: "reddit-capsule-logo",
        aliases: ["reddit", "r", "rd", "rdit", "red"]),
      SearchEngine(
        name: "T3Chat", color: Color(hex: "#960971"), icon: "t3chat-capsule-logo",
        aliases: ["t3chat", "t3", "t3c", "tchat"]),
      SearchEngine(
        name: "X", color: colorScheme == .dark ? .white : .black, icon: "",
        aliases: ["x", "x.com", "twitter", "tw", "twtr", "twit", "twitt", "twitte"],
        foregroundColor: colorScheme == .dark ? .black : .white),
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
              originalAlias: input
            )
            input = ""
          }
        }
      )
      .gradientBorder(
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
      .onChange(of: appState.showLauncher) { newValue in
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

struct GradientBorderModifier: ViewModifier {
  let color: Color
  let trigger: Bool
  @State private var isAnimating = false
  @State private var showBorder = false

  func body(content: Content) -> some View {
    content
      .overlay {
        if showBorder {
          ZStack {
            // Glow effect - outer blur
            RoundedRectangle(cornerRadius: 16.0)
              .stroke(
                AngularGradient(
                  gradient: Gradient(colors: [
                    color,
                    color.opacity(0.8),
                    color.opacity(0.4),
                    color.opacity(0.1),
                    color.opacity(0.0),
                    color.opacity(0.0),
                    color.opacity(0.0),
                    color.opacity(0.0),
                  ]),
                  center: .center,
                  angle: .degrees(isAnimating ? 360 : 0)
                ),
                lineWidth: 8.0
              )
              .blur(radius: 40)
              .opacity(0.9)

            // Main border
            RoundedRectangle(cornerRadius: 16.0)
              .stroke(
                AngularGradient(
                  gradient: Gradient(colors: [
                    color,
                    color.opacity(0.9),
                    color.opacity(0.6),
                    color.opacity(0.3),
                    color.opacity(0.1),
                    color.opacity(0.0),
                    color.opacity(0.0),
                    color.opacity(0.0),
                  ]),
                  center: .center,
                  angle: .degrees(isAnimating ? 360 : 0)
                ),
                lineWidth: 2.0
              )
          }
          .onAppear {
            showBorder = true
            withAnimation(.linear(duration: 0.8).repeatCount(1, autoreverses: false)) {
              isAnimating = true
            }
            // Hide border after animation completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
              withAnimation(.easeOut(duration: 0.3)) {
                showBorder = false
              }
            }
          }
        }
      }
      .onChange(of: trigger) { newTrigger in
        if newTrigger {
          showBorder = true
          isAnimating = false
          withAnimation(.linear(duration: 0.8).repeatCount(1, autoreverses: false)) {
            isAnimating = true
          }
          // Hide border after animation completes
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.3)) {
              showBorder = false
            }
          }
        }
      }
  }
}

extension View {
  func gradientBorder(color: Color, trigger: Bool) -> some View {
    modifier(
      GradientBorderModifier(
        color: color,
        trigger: trigger
      )
    )
  }
}

struct BlurEffectView: NSViewRepresentable {
  let material: NSVisualEffectView.Material
  let blendingMode: NSVisualEffectView.BlendingMode

  func makeNSView(context: Context) -> NSVisualEffectView {
    let visualEffectView = NSVisualEffectView()
    visualEffectView.material = material
    visualEffectView.blendingMode = blendingMode
    visualEffectView.state = .active
    return visualEffectView
  }

  func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
    nsView.material = material
    nsView.blendingMode = blendingMode
    nsView.state = .active
  }
}
