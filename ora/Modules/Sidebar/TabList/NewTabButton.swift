import SwiftUI


struct NewTabButton: View {
  let addNewTab: () -> Void

  @State private var isHovering = false
  @Environment(\.colorScheme) var colorScheme

  var body: some View {
    Button(action: addNewTab) {
      HStack(spacing: 8) {
        Image(systemName: "plus")
          .frame(width: 12, height: 12)

        Text("New Tab")
          .font(.system(size: 13, weight: .medium))
      }
      .foregroundColor(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .buttonStyle(.plain)
    .padding(8)
    .background(isHovering ? Color.adaptiveBackground(for: colorScheme).opacity(0.3) : .clear)
    .cornerRadius(10)
    .onHover { isHovering = $0 }
  }
}
