import SwiftUI
import AppKit

enum TabSection {
  case favorites
  case pinned
  case regular
}

struct TabDropDelegate: DropDelegate {
  let item: TabData
  @Binding var containers: [ContainerData]
  let selectedContainerId: String
  @Binding var draggedItem: String?
  let targetSection: TabSection

  func dropEntered(info: DropInfo) {
    guard let provider = info.itemProviders(for: [.text]).first else { return }

    provider.loadObject(ofClass: NSString.self) { object, _ in
      guard let fromId = object as? String else { return }

      DispatchQueue.main.async {
        guard let containerIndex = containers.firstIndex(where: { $0.id == selectedContainerId }),
          let fromIndex = containers[containerIndex].tabs.firstIndex(where: { $0.id == fromId }),
          let toIndex = containers[containerIndex].tabs.firstIndex(where: { $0.id == item.id }),
          fromId != item.id
        else { return }

        if isInSameSection(containerIndex: containerIndex, fromId: fromId, toId: item.id) {
          withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            containers[containerIndex].tabs.move(
              fromOffsets: IndexSet(integer: fromIndex),
              toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
          }
        } else {
          moveTabBetweenSections(
            containerIndex: containerIndex, fromId: fromId, toSection: targetSection)
        }
      }
    }
  }

  func dropUpdated(info: DropInfo) -> DropProposal? {
    .init(operation: .move)
  }

  func performDrop(info: DropInfo) -> Bool {
    draggedItem = nil
    return true
  }

  private func isInSameSection(containerIndex: Int, fromId: String, toId: String) -> Bool {
    let tabs = containers[containerIndex].tabs

    guard let fromTab = tabs.first(where: { $0.id == fromId }),
      let toTab = tabs.first(where: { $0.id == toId })
    else { return false }

    return section(for: fromTab) == section(for: toTab)
  }

  private func section(for tab: TabData) -> TabSection {
    if tab.isFavorite { return .favorites }
    if tab.isPinned { return .pinned }
    return .regular
  }

  private func moveTabBetweenSections(containerIndex: Int, fromId: String, toSection: TabSection) {
    var tabs = containers[containerIndex].tabs

    guard let fromIndex = tabs.firstIndex(where: { $0.id == fromId }) else { return }

    var tab = tabs.remove(at: fromIndex)
    tab.isFavorite = (toSection == .favorites)
    tab.isPinned = (toSection == .pinned)

    tabs.insert(tab, at: 0)

    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
      containers[containerIndex].tabs = tabs
    }
  }
}