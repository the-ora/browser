import SwiftData
import SwiftUI

struct SpacesSettingsView: View {
    @Query(sort: \TabContainer.lastAccessedAt, order: .reverse) var containers: [TabContainer]

    @StateObject private var settings = SettingsStore.shared
    @State private var searchService = SearchEngineService()
    @State private var selectedContainerId: UUID?
    @EnvironmentObject var historyManger: HistoryManager

    private var selectedContainer: TabContainer? {
        containers.first { $0.id == selectedContainerId } ?? containers.first
    }

    var body: some View {
        SettingsContainer(maxContentWidth: 1040) {
            HStack(alignment: .top, spacing: 0) {
                // Left list
                List(selection: $selectedContainerId) {
                    ForEach(containers) { container in
                        HStack {
                            Text(container.emoji)
                            Text(container.name)
                        }
                        .tag(container.id)
                    }
                }
                .frame(minWidth: 200, idealWidth: 200, maxWidth: 220)

                Divider()

                // Right details
                VStack(alignment: .leading, spacing: 20) {
                    if let container = selectedContainer {
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Picker(
                                    "Search engine",
                                    selection: Binding(
                                        get: {
                                            settings.defaultSearchEngineId(for: container.id)
                                        },
                                        set: { settings.setDefaultSearchEngineId($0, for: container.id) }
                                    )
                                ) {
                                    Text("Use Global Default").tag(nil as String?)
                                    Divider()
                                    ForEach(searchService.searchEngines.filter { !$0.isAIChat }, id: \.name) { engine in
                                        Text(engine.name).tag(Optional(engine.name))
                                    }
                                }
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Picker(
                                    "AI Chat",
                                    selection: Binding(
                                        get: {
                                            settings.defaultAIEngineId(for: container.id)
                                        },
                                        set: { settings.setDefaultAIEngineId($0, for: container.id) }
                                    )
                                ) {
                                    Text("Use Global Default").tag(nil as String?)
                                    Divider()
                                    ForEach(searchService.searchEngines.filter(\.isAIChat), id: \.name) { engine in
                                        Text(engine.name).tag(Optional(engine.name))
                                    }
                                }.disabled(true)
                            }

                            Picker(
                                "Clear tabs after",
                                selection: Binding(
                                    get: { settings.autoClearTabsAfter(for: container.id) },
                                    set: { settings.setAutoClearTabsAfter($0, for: container.id) }
                                )
                            ) {
                                ForEach(AutoClearTabsAfter.allCases) { value in
                                    Text(value.rawValue).tag(value)
                                }
                            }.disabled(true)
                        }
                        .padding(8)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Clear Data").foregroundStyle(.secondary)
                            Button("Clear Cache") { PrivacyService.clearCache(container) }
                            Button("Clear Cookies") { PrivacyService.clearCookies(container) }
                            Button("Clear Browsing History") {
                                historyManger.clearContainerHistory(container)
                            }
                        }
                        .padding(8)

                    } else {
                        Text("No spaces found").foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(16)
            }
        }
        .onAppear { if selectedContainerId == nil { selectedContainerId = containers.first?.id } }
    }
}
