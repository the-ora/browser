import SwiftUI
import AppKit

struct FavTabItem: View {
  let tab: TabData
  let isSelected: Bool
  let isDragging: Bool
  let onTap: () -> Void
  let onFavoriteToggle: () -> Void
  let onClose: () -> Void
  let onMoveToContainer: (String) -> Void
  let availableContainers: [ContainerData]
  let selectedContainerId: String

  @Environment(\.colorScheme) var colorScheme

  var body: some View {
    ZStack {
      Image(systemName: tab.icon)
        .frame(width: 16, height: 16)
    }
    .foregroundColor(Color.adaptiveText(for: colorScheme))
    .frame(height: 48)
    .frame(maxWidth: .infinity)
    .background(
      isSelected
        ? Color.adaptiveBackground(for: colorScheme) : Color.mutedBackground(for: colorScheme)
    )
    .cornerRadius(10)
    .opacity(isDragging ? 0.0 : 1.0)
    .onTapGesture(perform: onTap)
    .contextMenu {
      Button(action: onFavoriteToggle) {
        Label("Remove from Favorites", systemImage: "star.slash")
      }

      Divider()

      Menu("Move to Container") {
        ForEach(availableContainers) { container in
          if container.id != selectedContainerId {
            Button(action: { onMoveToContainer(container.id) }) {
              Label(container.title, systemImage: container.icon)
            }
          }
        }
      }

      Divider()

      Button(role: .destructive, action: onClose) {
        Label("Close Tab", systemImage: "xmark")
      }
    }
  }
}