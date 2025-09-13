import SwiftUI
import SwiftData

struct FolderView: View {
    let folder: Folder
    @Binding var draggedItem: UUID?
    let onDrag: (UUID) -> NSItemProvider
    let onSelect: (Tab) -> Void
    let onPinToggle: (Tab) -> Void
    let onFavoriteToggle: (Tab) -> Void
    let onClose: (Tab) -> Void
    let onMoveToContainer: (Tab, TabContainer) -> Void
    let availableContainers: [TabContainer]
    
    @EnvironmentObject var tabManager: TabManager
    @Environment(\.theme) private var theme
    @State private var isHovering = false
    @State private var isEditingName = false
    @State private var editedName = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Folder header
            HStack {
                Image(systemName: folder.isOpened ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(theme.foreground.opacity(0.6))
                    .onTapGesture {
                        tabManager.toggleFolderOpen(folder)
                    }
                
                Image(systemName: "folder.fill")
                    .font(.system(size: 12))
                    .foregroundColor(theme.foreground.opacity(0.8))
                
                if isEditingName {
                    TextField("Folder name", text: $editedName, onCommit: {
                        if !editedName.isEmpty {
                            tabManager.renameFolder(folder, newName: editedName)
                        }
                        isEditingName = false
                    })
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 13))
                    .foregroundColor(theme.foreground)
                    .onAppear {
                        editedName = folder.name
                    }
                } else {
                    Text(folder.name)
                        .font(.system(size: 13))
                        .foregroundColor(theme.foreground)
                        .lineLimit(1)
                        .onTapGesture(count: 2) {
                            isEditingName = true
                        }
                }
                
                Spacer()
                
                if folder.tabs.count > 0 {
                    Text("\(folder.tabs.count)")
                        .font(.system(size: 10))
                        .foregroundColor(theme.foreground.opacity(0.5))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(theme.foreground.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isHovering ? theme.activeTabBackground.opacity(0.2) : Color.clear)
            .cornerRadius(6)
            .onHover { isHovering = $0 }
            .contextMenu {
                Button("Rename Folder") {
                    isEditingName = true
                }
                
                if folder.tabs.isEmpty {
                    Button("Delete Folder") {
                        tabManager.deleteFolder(folder)
                    }
                } else {
                    Button("Delete Folder and Move Tabs Out") {
                        tabManager.deleteFolder(folder)
                    }
                }
            }
            
            // Folder contents (tabs)
            if folder.isOpened {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(folder.tabs.sorted(by: { $0.order > $1.order })) { tab in
                        TabItem(
                            tab: tab,
                            isSelected: tabManager.isActive(tab),
                            isDragging: draggedItem == tab.id,
                            onTap: { onSelect(tab) },
                            onPinToggle: { onPinToggle(tab) },
                            onFavoriteToggle: { onFavoriteToggle(tab) },
                            onClose: { onClose(tab) },
                            onMoveToContainer: { onMoveToContainer(tab, $0) },
                            availableContainers: availableContainers
                        )
                        .padding(.leading, 20)
                        .onDrag { onDrag(tab.id) }
                        .onDrop(
                            of: [.text],
                            delegate: FolderTabDropDelegate(
                                folder: folder,
                                targetTab: tab,
                                draggedItem: $draggedItem,
                                tabManager: tabManager
                            )
                        )
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: folder.tabs.map(\.id))
            }
        }
        .onDrop(
            of: [.text],
            delegate: FolderDropDelegate(
                folder: folder,
                draggedItem: $draggedItem,
                tabManager: tabManager
            )
        )
    }
}

// MARK: - Drop Delegates

struct FolderDropDelegate: DropDelegate {
    let folder: Folder
    @Binding var draggedItem: UUID?
    let tabManager: TabManager
    
    func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: [.text])
    }
    
    func dropEntered(info: DropInfo) {
        // Visual feedback when hovering
    }
    
    func performDrop(info: DropInfo) -> Bool {
        guard let draggedTabId = draggedItem,
              let tab = folder.container.tabs.first(where: { $0.id == draggedTabId }) else {
            return false
        }
        
        withAnimation {
            tabManager.moveTabToFolder(tab, folder: folder)
        }
        
        return true
    }
}

struct FolderTabDropDelegate: DropDelegate {
    let folder: Folder
    let targetTab: Tab
    @Binding var draggedItem: UUID?
    let tabManager: TabManager
    
    func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: [.text])
    }
    
    func performDrop(info: DropInfo) -> Bool {
        guard let draggedTabId = draggedItem,
              let draggedTab = folder.container.tabs.first(where: { $0.id == draggedTabId }),
              draggedTab.id != targetTab.id else {
            return false
        }
        
        withAnimation {
            // Move tab to folder if not already in it
            if draggedTab.folder != folder {
                tabManager.moveTabToFolder(draggedTab, folder: folder)
            }
            
            // Reorder within folder
            let draggedOrder = draggedTab.order
            let targetOrder = targetTab.order
            
            if draggedOrder != targetOrder {
                folder.container.reorderTabs(from: draggedTab, to: targetTab)
            }
        }
        
        return true
    }
}
