import SwiftUI

struct ImportDataButton: View {
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var historyManager: HistoryManager
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var privacyMode: PrivacyMode

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
                for tab in result.cleanTabs where space.containerIDs
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
                                    historyManager: historyManager,
                                    downloadManager: downloadManager,
                                    isPrivate: privacyMode.isPrivate
                                )

                        tabManager
                            .togglePinTab(
                                newTab
                            )
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
                                        historyManager: historyManager,
                                        downloadManager: downloadManager,
                                        isPrivate: privacyMode.isPrivate
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
        Menu("Import Data") {
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
