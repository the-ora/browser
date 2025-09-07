import AppKit
import SwiftData
import SwiftUI

struct SidebarView: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var historyManger: HistoryManager
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var appState: AppState
    @Query var containers: [TabContainer]
    @Query(filter: nil, sort: [.init(\History.lastAccessedAt, order: .reverse)]) var histories:
        [History]
    private let columns = Array(repeating: GridItem(spacing: 10), count: 3)
    let isFullscreen: Bool

    @State private var showFullURL: Bool = false
    @State private var editingURLString: String = ""

    private var selectedContainerIndex: Binding<Int> {
        Binding(
            get: {
                guard let activeContainer = tabManager.activeContainer else { return 0 }
                return containers.firstIndex(where: { $0.id == activeContainer.id }) ?? 0
            },
            set: { newIndex in
                guard newIndex >= 0, newIndex < containers.count else { return }
                tabManager.activateContainer(containers[newIndex])
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // URL display when toolbar is hidden
            if appState.isToolbarHidden, let tab = tabManager.activeTab {
                SidebarURLDisplay(
                    tab: tab,
                    editingURLString: $editingURLString,
                    showFullURL: $showFullURL
                )
            }

            NSPageView(
                selection: selectedContainerIndex,
                pageObjects: containers,
                idKeyPath: \.name
            ) { container in
                ContainerView(
                    container: container,
                    selectedContainer: container.name,
                    containers: containers
                )
                .padding(.horizontal, 10)
                .environmentObject(tabManager)
                .environmentObject(historyManger)
                .environmentObject(downloadManager)
                .environmentObject(appState)
            }

            HStack {
                DownloadsWidget()
                Spacer()
                ContainerSwitcher(onContainerSelected: onContainerSelected)
                Spacer()
                NewContainerButton()
            }
            .padding(.horizontal, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(
            EdgeInsets(
                top: isFullscreen ? 10 : 36,
                leading: 0,
                bottom: 10,
                trailing: 0
            )
        )
    }

    private func onContainerSelected(container: TabContainer) {
        withAnimation(.easeOut(duration: 0.1)) {
            tabManager.activateContainer(container)
        }
    }

    private func getDisplayURL(_ tab: Tab) -> String {
        if showFullURL {
            return tab.url.absoluteString
        } else {
            return tab.url.host ?? tab.url.absoluteString
        }
    }
}
