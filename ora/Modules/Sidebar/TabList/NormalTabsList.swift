import SwiftData
import SwiftUI

private struct IndentedTab: Identifiable {
    let tab: Tab
    let indentationLevel: Int

    var id: UUID { tab.id }
}

private func tabsSortedByParent(
    _ tabs: [Tab],
    withParentTabSelector parentTabSelector: UUID? = nil,
    withIndentation indentation: Int = 0
) -> [IndentedTab] {
    // Start by finding only parent tags, then recurse down through
    var output = [IndentedTab]()
    let roots = tabs.filter { $0.parent?.id == parentTabSelector }.sorted(
        by: { $0.order < $1.order
        })
    for root in roots {
        output.append(IndentedTab(tab: root, indentationLevel: indentation))
        output
            .append(
                contentsOf: tabsSortedByParent(
                    root.children,
                    withParentTabSelector: root.id,
                    withIndentation: indentation + 1
                )
            )
    }

    return output
}

struct NormalTabsList: View {
    let tabs: [Tab]
    @Binding var draggedItem: UUID?
    let onDrag: (UUID) -> NSItemProvider
    let onSelect: (Tab) -> Void
    let onPinToggle: (Tab) -> Void
    let onFavoriteToggle: (Tab) -> Void
    let onClose: (Tab) -> Void
    let onDuplicate: (Tab) -> Void
    let onMoveToContainer:
        (
            Tab,
            TabContainer
        ) -> Void
    let onAddNewTab: () -> Void
    @Query var containers: [TabContainer]
    @EnvironmentObject var tabManager: TabManager
    @State private var previousTabIds: [UUID] = []

    var body: some View {
        VStack(spacing: 8) {
            NewTabButton(addNewTab: onAddNewTab)
            ForEach(tabsSortedByParent(tabs)) { iTab in
                let tab = iTab.tab
                TabItem(
                    tab: tab,
                    isSelected: tabManager.isActive(tab),
                    isDragging: draggedItem == tab.id,
                    onTap: { onSelect(tab) },
                    onPinToggle: { onPinToggle(tab) },
                    onFavoriteToggle: { onFavoriteToggle(tab) },
                    onClose: { onClose(tab) },
                    onDuplicate: { onDuplicate(tab) },
                    onMoveToContainer: { onMoveToContainer(tab, $0) },
                    availableContainers: containers
                )
                .onDrag { onDrag(tab.id) }
                .onDrop(
                    of: [.text],
                    delegate: TabDropDelegate(
                        item: tab,
                        draggedItem: $draggedItem,
                        targetSection: .normal
                    )
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                    removal: .opacity.combined(with: .move(edge: .top))
                ))
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: shouldAnimate(tab))
                .padding(
                    .leading,
                    CGFloat(integerLiteral: iTab.indentationLevel * 8)
                )
            }
        }
        .onDrop(
            of: [.text],
            delegate: SectionDropDelegate(
                items: tabs,
                draggedItem: $draggedItem,
                targetSection: .normal,
                tabManager: tabManager
            )
        )
        .onAppear {
            previousTabIds = tabs.map(\.id)
        }
        .onChange(of: tabs.map(\.id)) { newTabIds in
            previousTabIds = newTabIds
        }
    }

    private func shouldAnimate(_ tab: Tab) -> Bool {
        // Only animate if the tab's position has actually changed
        guard let currentIndex = tabs.firstIndex(where: { $0.id == tab.id }),
              let previousIndex = previousTabIds.firstIndex(where: { $0 == tab.id })
        else {
            return true // Animate new tabs or tabs that were just created
        }
        return currentIndex != previousIndex
    }
}
