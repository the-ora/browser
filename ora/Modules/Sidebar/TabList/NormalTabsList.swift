import SwiftData
import SwiftUI

private struct IndentedTab: Identifiable {
    let tab: Tab
    let indentationLevel: Int
    let tabs: [Tab]

    var id: UUID { tab.id }
}

private func tabsSortedByParentImpl(
    _ tabs: [Tab],
    withParentTabSelector parentTabSelector: UUID?,
    withIndentation indentation: Int,
    withTilesetUseSet usedTilesets: inout Set<UUID>
) -> [IndentedTab] {
    // Start by finding only parent tags, then recurse down through
    var output = [IndentedTab]()
    let roots = tabs.filter { $0.parent?.id == parentTabSelector }.sorted(
        by: { $0.order < $1.order
        })
    for root in roots {
        var toAppend = [root]
        if let tileset = root.tileset {
            if usedTilesets.contains(tileset.id) {
                continue
            }
            let foundTiles = Set(tileset.tabs.map(\.id))
            toAppend = tabs.filter { foundTiles.contains($0.id) }
            assert(!toAppend.isEmpty)
            usedTilesets.insert(tileset.id)
        }
        output
            .append(
                IndentedTab(
                    tab: root,
                    indentationLevel: indentation,
                    tabs: toAppend
                )
            )

        output
            .append(
                contentsOf: tabsSortedByParentImpl(
                    root.children,
                    withParentTabSelector: root.id,
                    withIndentation: indentation + 1,
                    withTilesetUseSet: &usedTilesets
                )
            )
    }

    return output
}

private func tabsSortedByParent(_ tabs: [Tab]) -> [IndentedTab] {
    var usedTilesets: Set<UUID> = []
    return tabsSortedByParentImpl(
        tabs,
        withParentTabSelector: nil,
        withIndentation: 0,
        withTilesetUseSet: &usedTilesets
    )
}

enum TargetedDropItem {
    case tab(id: UUID, tabset: Bool), divider(UUID)

    func imTargeted(withMyIdBeing id: UUID, andType t: DelegateTarget) -> Bool {
        switch (self, t) {
        case let (.tab(uuid, tabsetA), .tab(_)):
            return uuid == id
        case let (.divider(uuid), .divider):
            return uuid == id
        default:
            return false
        }
    }
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
    @State private var targetedDropItem: TargetedDropItem?
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 3) {
            NewTabButton(addNewTab: onAddNewTab)
            ForEach(tabsSortedByParent(tabs)) { iTab in
                VStack(spacing: 3) {
                    HStack {
                        ForEach(iTab.tabs) { tab in
                            TabItem(
                                tab: tab,
                                isSelected: iTab.tabs
                                    .contains(
                                        where: { t in tabManager.isActive(t)
                                        }),
                                isDragging: draggedItem == tab.id,
                                isDragTarget: targetedDropItem?
                                    .imTargeted(
                                        withMyIdBeing: tab.id,
                                        andType: .tab(tabset: false)
                                    ) ?? false,
                                onTap: { onSelect(tab)
                                },
                                onPinToggle: { onPinToggle(tab) },
                                onFavoriteToggle: { onFavoriteToggle(tab) },
                                onClose: { onClose(tab) },
                                onDuplicate: { onDuplicate(tab) },
                                onMoveToContainer: { onMoveToContainer(tab, $0) },
                                availableContainers: containers,
                                draggedItem: $draggedItem,
                                targetedDropItem: $targetedDropItem
                            )
                            .onDrag { onDrag(tab.id) }
                            .onDrop(
                                of: [.text],
                                delegate: TabDropDelegate(
                                    item: tab,
                                    representative: .tab(tabset: false), draggedItem: $draggedItem,
                                    targetedItem: $targetedDropItem,
                                    targetSection: .normal
                                )
                            )
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                removal: .opacity.combined(with: .move(edge: .top))
                            ))
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: shouldAnimate(tab))
                        }
                    }
                    .overlay(
                        iTab.tabs
                            .contains(where: { targetedDropItem?.imTargeted(
                                withMyIdBeing: $0.id,
                                andType: .tab(tabset: false)
                            ) ?? false }) ? DragTarget(
                                tab: iTab.tabs.first!,
                                draggedItem: $draggedItem,
                                targetedDropItem: $targetedDropItem
                            ) : nil
                    )

                    Capsule()
                        .frame(height: 3)
                        .foregroundStyle(theme.accent)
                        .opacity(targetedDropItem?
                            .imTargeted(withMyIdBeing: iTab.tabs.first!.id, andType: .divider) ?? false ? 1.0 : 0.0)
                        .onDrop(
                            of: [.text],
                            delegate: TabDropDelegate(
                                item: iTab.tabs.first!,
                                representative: .divider,
                                draggedItem: $draggedItem,
                                targetedItem: $targetedDropItem,
                                targetSection: .normal
                            )
                        )
                }
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
