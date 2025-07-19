import AppKit
import SwiftUI

struct Theme {
  let colorScheme: ColorScheme

  var background: Color {
    colorScheme == .dark ? .black : .white
  }

  var foreground: Color {
    colorScheme == .dark ? .white : .black
  }

  var mutedBackground: Color {
    colorScheme == .dark ? .black.opacity(0.15) : .white.opacity(0.5)
  }

  var mutedForeground: Color {
    .secondary
  }

  var disabledBackground: Color {
    colorScheme == .dark ? .black.opacity(0.3) : .white.opacity(0.3)
  }

  var disabledForeground: Color {
      colorScheme == .dark ? .white.opacity(0.3) : Color(.disabledControlTextColor)
  }

  var launcherInputBackground: Color {
    colorScheme == .dark ? Color(.windowBackgroundColor) : .white.opacity(0.8)
  }

  var placeholder: Color {
    Color(.placeholderTextColor)
  }

  var border: Color {
      Color(.separatorColor)
  }

  var destructive: Color {
    Color(hex: "#FF6969")
  }

  var success: Color {
    Color(hex: "#93DA97")
  }

  var warning: Color {
    Color(hex: "#FFBF78")
  }

  var info: Color {
    Color(hex: "#799EFF")
  }
}

private struct ThemeKey: EnvironmentKey {
  static let defaultValue = Theme(colorScheme: .light)  // fallback
}

extension EnvironmentValues {
  var theme: Theme {
    get { self[ThemeKey.self] }
    set { self[ThemeKey.self] = newValue }
  }
}

struct ThemeProvider: ViewModifier {
  @Environment(\.colorScheme) private var colorScheme

  func body(content: Content) -> some View {
    content.environment(\.theme, Theme(colorScheme: colorScheme))
  }
}

extension View {
  func withTheme() -> some View {
    self.modifier(ThemeProvider())
  }
}
