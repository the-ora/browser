import AppKit
import SwiftUI

struct TabDropDelegate: DropDelegate {
  let item: Tab  // to
  @Binding var draggedItem: UUID?

  let targetSection: TabSection

  func dropEntered(info: DropInfo) {
    guard let provider = info.itemProviders(for: [.text]).first else { return }
    performHapticFeedback(pattern: .generic)
    provider.loadObject(ofClass: NSString.self) {
      object,
      _ in
      if let string = object as? String,
        let uuid = UUID(uuidString: string)
      {

        DispatchQueue.main.async {
          guard let from = self.item.container.tabs.first(where: { $0.id == uuid }) else { return }

          if isInSameSection(
            from: from,
            to: self.item
          ) {
            withAnimation(
              .spring(
                response: 0.3,
                dampingFraction: 0.8
              )
            ) {
              self.item.container
                .reorderTabs(
                  from: from,
                  to: self.item
                )
            }
          } else {
            moveTabBetweenSections(from: from, to: self.item)
          }
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
}
