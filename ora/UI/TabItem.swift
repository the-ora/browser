import AppKit
import SwiftUI

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
    let tab: Tab
    let isSelected: Bool
    let isDragging: Bool
    let onTap: () -> Void
    let onPinToggle: () -> Void
    let onFavoriteToggle: () -> Void
    let onClose: () -> Void
    let onMoveToContainer: (TabContainer) -> Void
    @EnvironmentObject var tabManager: TabManager
    let availableContainers: [TabContainer]
    
    @Environment(\.theme) private var theme
    @State private var isHovering = false
    
    var body: some View {
        HStack {
            tabIcon
            tabTitle
            Spacer()
            actionButton
        }
        .onAppear{
            tab.restoreTransientState()
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
        HStack {
            
            if let favicon = tab.favicon {
                if tab.isWebViewReady {
                    AsyncImage(
                        url: favicon
                    ) { image in
                        image
                            .frame(width: 12, height: 8.57143)
                    } placeholder: {
                        Image(systemName: "globe")
                            .frame(width: 12, height: 8.57143)
                            .foregroundColor(textColor)
                    }
                }
            } else {
                Image(systemName: "globe")
                    .frame(width: 12, height: 8.57143)
                    .foregroundColor(textColor)
            }
        }
    }
    
    private var tabTitle: some View {
        Text(tab.title)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(textColor)
            .lineLimit(1)
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return theme.background
        } else if isHovering {
            return theme.background.opacity(0.3)
        }
        return .clear
    }
    
    private var textColor: Color {
        isSelected ? theme.foreground : .secondary
    }
    
    @ViewBuilder
    private var actionButton: some View {
        if tab.type == .pinned {
            ActionButton(icon: "pin.slash", color: textColor, action: onPinToggle)
        } else if isHovering {
            ActionButton(icon: "xmark", color: textColor, action: onClose)
        }
    }
    
    @ViewBuilder
    private var contextMenuItems: some View {
        Button(action: onPinToggle) {
            Label(
                tab.type == .pinned ? "Unpin Tab" : "Pin Tab",
                systemImage: tab.type == .pinned ? "pin.slash" : "pin")
        }
        
        Button(action: onFavoriteToggle) {
            Label(
                tab.type == .fav ? "Remove from Favorites" : "Add to Favorites",
                systemImage: tab.type == .fav ? "star.slash" : "star")
        }
        
        Divider()
        
        Menu("Move to Container") {
            ForEach(availableContainers) { container in
                if tab.container.id != tabManager.activeContainer?.id {
                    Button(action: { onMoveToContainer(tab.container) }) {
                        Label {
                            Text(container.name)
                        } icon: {
                            Text(container.emoji) // This is where you show the emoji
                        }
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
