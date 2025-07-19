import SwiftUI

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
  @Environment(\.theme) private var theme

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
        .background(theme.background.opacity(0.07))
        .cornerRadius(6)
      }
      .buttonStyle(PlainButtonStyle())
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 10)
    .frame(width: 798, alignment: .leading)
    .background(backgroundColor ?? theme.background.opacity(0.9))
    .cornerRadius(8)
    .onHover { hover in
      isHovered = hover
    }
    .focusable()
  }
}