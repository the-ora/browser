import SwiftUI
import AppKit

enum TabSection {
    case favorites
    case pinned
    case regular
}

struct TabDropDelegate: DropDelegate {
    let item: Tab // to
    @Binding var draggedItem: UUID?
    @EnvironmentObject var tabManager: TabManager
    
    let targetSection: TabSection
    
    func dropEntered(info: DropInfo) {
        guard let provider = info.itemProviders(for: [.text]).first else { return }
        
        provider.loadObject(ofClass: NSString.self) {
            object,
            _ in
            if let string = object as? String,
               let uuid = UUID(uuidString: string) {
                guard let from = item.container.tabs.first(where: {$0.id == uuid}) else { return }
                
                DispatchQueue.main.async {
                    
                    if isInSameSection(
                        from: from,
                        to: item
                    ) {
                        withAnimation(
                            .spring(
                                response: 0.3,
                                dampingFraction: 0.8
                            )
                        ) {
                            item.container
                                .reorderTabs(
                                    from: from,
                                    to: item
                                )
                        }
                    } else {
                        moveTabBetweenSections(from: from, to: item)
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
    
    private func isInSameSection(from: Tab, to: Tab) -> Bool {
        return section(for: from) == section(for: to)
        
    }
    
    private func section(for tab: Tab) -> TabSection {
        if tab.type == .fav { return .favorites }
        if tab.type == .pinned { return .pinned }
        return .regular
    }
    
    
     func moveTabBetweenSections(from: Tab, to: Tab) {
         func move() {
             from.switchSections(
                     from: from,
                     to: to
                 )
             from.container
                 .reorderTabs(from: from, to: to)
         }
         move()
//        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
//            move()
//            
//        }
    }
}
