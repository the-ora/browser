import SwiftUI

extension Color {
  static func adaptiveBackground(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? .black : .white
  }

  static func adaptiveText(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? .white : .black
  }

  static func mutedBackground(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? .black.opacity(0.15) : .white.opacity(0.5)
  }
}
