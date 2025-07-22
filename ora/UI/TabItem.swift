import AppKit
import SwiftUI
import AppKit

struct LocalFavIcon: View {
    let faviconLocalFile: URL?
    let textColor: Color
    
    @State private var image: NSImage?
    
    var body: some View {
        if let image = image {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
        } else {
            Image(systemName: "globe")
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .foregroundColor(textColor)
                .onAppear(perform: loadFavicon)
        }
    }
    
    private func loadFavicon() {
        guard let localURL = faviconLocalFile,
              FileManager.default.fileExists(atPath: localURL.path) else { return }
        
        // Loading may block briefly, so you can even do it async if needed
        DispatchQueue.global(qos: .utility).async {
            if let loadedImage = NSImage(contentsOfFile: localURL.path) {
                DispatchQueue.main.async {
                    self.image = loadedImage
                }
            }
        }
    }
}
struct FavIcon:  View {
    let isWebViewReady: Bool
    let favicon: URL?
    let faviconLocalFile: URL?
    let textColor: Color
    
    var body: some View {
        
        HStack {
            if let favicon = favicon{
                if isWebViewReady {
                    
                    AsyncImage(
                        url: favicon
                    ) { image in
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                    } placeholder: {
                        LocalFavIcon(
                            faviconLocalFile: faviconLocalFile,
                            textColor: textColor
                        )
                    }
                    
                }
            } else {
                LocalFavIcon(
                    faviconLocalFile: faviconLocalFile,
                    textColor: textColor
                )
            }
        }
        .frame(width:16,height: 16)
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
    @EnvironmentObject var historyManager: HistoryManager
    let availableContainers: [TabContainer]
    
    @Environment(\.theme) private var theme
    @State private var isHovering = false
    
    var body: some View {
        HStack {
            FavIcon(
                isWebViewReady: tab.isWebViewReady,
                favicon: tab.favicon,
                faviconLocalFile: tab.faviconLocalFile,
                textColor: textColor
            )
            tabTitle
            Spacer()
            actionButton
        }
        .onAppear{
            tab
                .restoreTransientState(
                    historyManger: historyManager
                )
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
    
    
    
    private var tabTitle: some View {
        Text(tab.title)
            .font(.system(size: 13))
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

