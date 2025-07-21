import SwiftUI
import AppKit
import SwiftData

struct FavTabItem: View {
  let tab: Tab
  let isSelected: Bool
  let isDragging: Bool
  let onTap: () -> Void
  let onFavoriteToggle: () -> Void
  let onClose: () -> Void
    let onMoveToContainer: (TabContainer) -> Void

  @Environment(\.colorScheme) var colorScheme
    @Query var containers: [TabContainer]
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var historyManager: HistoryManager

  var body: some View {
    ZStack {
        if let favicon = tab.favicon {
            if tab.isWebViewReady {
                AsyncImage(
                  url: favicon
                ) { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                } placeholder: {
                    LocalFavIcon(
                        tab: tab,
                        textColor:Color(.white)
                    )

                }
            }
        } else {
            LocalFavIcon(
                tab: tab,
                textColor: Color(.white)
            )
        }

    }
    .onAppear {
        tab
            .restoreTransientState(
                historyManger: historyManager
            )
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

//      Menu("Move to Container") {
//        ForEach(containers) { container in
//            if container.id != tabManager.activeContainer?.id {
//            Button(action: { onMoveToContainer(container) }) {
//              Label(container.title, systemImage: container.icon)
//            }
//          }
//        }
//      }

      Divider()

      Button(role: .destructive, action: onClose) {
        Label("Close Tab", systemImage: "xmark")
      }
    }
  }
}
