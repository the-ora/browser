import SwiftUI
import AppKit

struct TabData: Identifiable {
  let id: String
  let icon: String
  let title: String
  var isPinned: Bool
  var isFavorite: Bool

  init(id: String, icon: String, title: String, isPinned: Bool = false, isFavorite: Bool = false) {
    self.id = id
    self.icon = icon
    self.title = title
    self.isPinned = isPinned
    self.isFavorite = isFavorite
  }
}

struct TabItem: View {
  let tab: TabData
  let isSelected: Bool
  let isDragging: Bool
  let onTap: () -> Void
  let onPinToggle: () -> Void
  let onFavoriteToggle: () -> Void
  let onClose: () -> Void
  let onMoveToContainer: (String) -> Void
  let availableContainers: [ContainerData]
  let selectedContainerId: String

  @Environment(\.colorScheme) var colorScheme
  @State private var isHovering = false

  var body: some View {
    HStack {
      tabIcon
      tabTitle
      Spacer()
      actionButton
    }
    .padding(8)
    .background(backgroundColor)
    .cornerRadius(10)
    .opacity(isDragging ? 0.0 : 1.0)
    .onTapGesture(perform: onTap)
    .onHover { isHovering = $0 }
    .contextMenu { contextMenuItems }
    .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isDragging)
  }

  private var tabIcon: some View {
    Image(systemName: tab.icon)
      .frame(width: 12, height: 8.57143)
      .foregroundColor(textColor)
  }

  private var tabTitle: some View {
    Text(tab.title)
      .font(.system(size: 13, weight: .medium))
      .foregroundColor(textColor)
      .lineLimit(1)
  }

  private var backgroundColor: Color {
    if isSelected {
      return Color.adaptiveBackground(for: colorScheme)
    } else if isHovering {
      return Color.adaptiveBackground(for: colorScheme).opacity(0.3)
    }
    return .clear
  }

  private var textColor: Color {
    isSelected ? Color.adaptiveText(for: colorScheme) : .secondary
  }

  @ViewBuilder
  private var actionButton: some View {
    if tab.isPinned {
      ActionButton(icon: "pin.slash", color: textColor, action: onPinToggle)
    } else if isHovering {
      ActionButton(icon: "xmark", color: textColor, action: onClose)
    }
  }

  @ViewBuilder
  private var contextMenuItems: some View {
    Button(action: onPinToggle) {
      Label(
        tab.isPinned ? "Unpin Tab" : "Pin Tab",
        systemImage: tab.isPinned ? "pin.slash" : "pin")
    }

    Button(action: onFavoriteToggle) {
      Label(
        tab.isFavorite ? "Remove from Favorites" : "Add to Favorites",
        systemImage: tab.isFavorite ? "star.slash" : "star")
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

struct ActionButton: View {
  let icon: String
  let color: Color
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: icon)
        .frame(width: 12, height: 12)
        .foregroundColor(color)
    }
    .buttonStyle(.plain)
  }
}