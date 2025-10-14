import SwiftData
import SwiftUI

struct SpacesSettingsView: View {
    @Query var containers: [TabContainer]

    @StateObject private var settings = SettingsStore.shared
    @State private var searchService = SearchEngineService()
    @State private var selectedContainerId: UUID?
    @EnvironmentObject var historyManager: HistoryManager

    private var selectedContainer: TabContainer? {
        containers.first { $0.id == selectedContainerId } ?? containers.first
    }

    var body: some View {
        SettingsContainer(maxContentWidth: 1040, usesScrollView: false) {
            HStack(spacing: 0) {
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
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if let container = selectedContainer {
                            // Space-Specific Defaults Section
                            VStack(alignment: .leading, spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Space-Specific Defaults")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                    Text("Configure default settings for this space")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                VStack(alignment: .leading, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Search Engine Override")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
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
                                            ForEach(
                                                searchService.searchEngines.filter { !$0.isAIChat },
                                                id: \.name
                                            ) { engine in
                                                Text(engine.name).tag(Optional(engine.name))
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .frame(minWidth: 200, maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(12)
                                    .background(Color(.controlBackgroundColor))
                                    .cornerRadius(6)

                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("AI Chat Override")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
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
                                            ForEach(
                                                searchService.searchEngines.filter(\.isAIChat),
                                                id: \.name
                                            ) { engine in
                                                Text(engine.name).tag(Optional(engine.name))
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .frame(minWidth: 200, maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(12)
                                    .background(Color(.controlBackgroundColor))
                                    .cornerRadius(6)

                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Auto Clear Tabs")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
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
                                        }
                                        .pickerStyle(.menu)
                                        .frame(minWidth: 200, maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(12)
                                    .background(Color(.controlBackgroundColor))
                                    .cornerRadius(6)
                                }
                            }

                            Divider()

                            // Clear Data Section
                            VStack(alignment: .leading, spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Privacy & Data")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                    Text("Clear stored data for this space")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                VStack(spacing: 8) {
                                    Button("Clear Cache") {
                                        PrivacyService.clearCache(container)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                    Button("Clear Cookies") {
                                        PrivacyService.clearCookies(container)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                    Button("Clear History") {
                                        historyManager.clearContainerHistory(container)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.bordered)
                            }

                        } else {
                            VStack(spacing: 12) {
                                Text("No spaces found")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                Text("Create a space to configure its settings")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            }
        }
        .onAppear { if selectedContainerId == nil { selectedContainerId = containers.first?.id } }
    }
}
