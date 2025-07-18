import SwiftUI

struct NewContainerButton: View {
  let action: () -> Void

  @State private var isHovering = false
  @Environment(\.colorScheme) var colorScheme

  var body: some View {
    Button(action: action) {
      Image(systemName: "plus")
        .frame(width: 12, height: 12)
        .foregroundColor(.secondary)
        .padding(8)
        .background(isHovering ? Color.adaptiveBackground(for: colorScheme).opacity(0.3) : .clear)
        .cornerRadius(10)
    }
    .buttonStyle(.plain)
    .onHover { isHovering = $0 }
  }
}
