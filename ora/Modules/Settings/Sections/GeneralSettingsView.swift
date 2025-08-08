import AppKit
import SwiftUI

struct GeneralSettingsView: View {
  @EnvironmentObject var appearanceManager: AppearanceManager
  @StateObject private var settings = SettingsStore.shared
  @Environment(\.theme) var theme

  var body: some View {
    SettingsContainer(maxContentWidth: 760) {
      Form {
        VStack(alignment: .leading, spacing: 16) {
          HStack {
            Text("Born for your Mac. Make Ora your default browser.")
            Spacer()
            Button("Set Ora as default") { openDefaultBrowserSettings() }
          }
          .frame(maxWidth: .infinity)
          .padding(8)
          .background(theme.solidWindowBackgroundColor)
          .cornerRadius(8)

          AppearanceSelector(selection: $appearanceManager.appearance)
          // Toggle("Auto update Ora", isOn: $settings.autoUpdateEnabled)
        }
      }
    }
  }

  private func openDefaultBrowserSettings() {
    guard
      let url = URL(
        string: "x-apple.systempreferences:com.apple.preference.general?DefaultWebBrowser")
    else { return }
    NSWorkspace.shared.open(url)
  }
}
