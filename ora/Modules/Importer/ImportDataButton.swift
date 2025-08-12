import SwiftUI

struct ImportDataButton: View {
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var historyManger: HistoryManager
    @EnvironmentObject var downloadManager: DownloadManager

    func importArc() {
        if let root = getRoot() {
            let result = inspectItems(root)
            var newContainers: [TabContainer] = []

            for space in result.cleanSpaces {
                let container =
                    tabManager
                        .createContainer(
                            name: space.title ?? "Unknown",
                            emoji: space.emoji ?? "💀"
                        )
                newContainers
                    .append(
                        container
                    )
                for tab in result.cleanTabs {
                    if space.containerIDs
                        .contains(
                            tab.parentID
                        )
                    {
                        if let url = URL(
                            string: tab.urlString
                        ) {
                            let newTab =
                                tabManager
                                    .addTab(
                                        title: tab.title,
                                        url: url,
                                        container: container,
                                        historyManager: historyManger,
                                        downloadManager: downloadManager
                                    )

                            tabManager
                                .togglePinTab(
                                    newTab
                                )
                        }
                    }
                }
            }

            var seenContainers: Set<UUID> = []
            for container in newContainers {
                if seenContainers
                    .contains(container.id)
                {
                    continue
                }
                seenContainers
                    .insert(container.id)
                for tab in result.cleanTabs {
                    if result.favs
                        .contains(
                            tab.parentID
                        )
                    {
                        if let url = URL(
                            string: tab.urlString
                        ) {
                            let newTab =
                                tabManager
                                    .addTab(
                                        title: tab.title,
                                        url: url,
                                        container: container,
                                        historyManager: historyManger,
                                        downloadManager: downloadManager
                                    )
                            tabManager
                                .toggleFavTab(
                                    newTab
                                )
                        }
                    }
                }
            }
        }
    }

    var body: some View {
        Group {
            Button("Arc") {
                importArc()
            }
            Button("Safari") {
                // importSafari()
            }
            Button("Chrome") {
                // importChrome()
            }
        }
    }
}
