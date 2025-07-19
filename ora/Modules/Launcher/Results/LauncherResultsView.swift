import SwiftUI

enum LauncherResultType: CaseIterable {
  case openedTab, suggestedQuery, suggestedLink, aiSearch
}

struct LauncherResultsView: View {
  @Environment(\.theme) private var theme

  var body: some View {
    HStack {
      Text("Results")
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(theme.background.opacity(0.9))
  }
}