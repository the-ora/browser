import SwiftData
import SwiftUI

struct SpacesSettingsView: View {
    private enum ClearDataAction: Hashable {
        case cache(UUID)
        case cookies(UUID)
        case history(UUID)
    }

    @Query var containers: [TabContainer]

    @StateObject private var settings = SettingsStore.shared
    @State private var searchService = SearchEngineService()
    @State private var selectedContainerId: UUID?
    @State private var completedClearActions: Set<ClearDataAction> = []
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var toastManager: ToastManager

    private var selectedContainer: TabContainer? {
        containers.first { $0.id == selectedContainerId } ?? containers.first
    }

    var body: some View {
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
                        SettingsCard(header: "Defaults") {
                            Grid(alignment: .leading, verticalSpacing: 12) {
                                GridRow {
                                    Text("Search Engine")
                                        .frame(width: 140, alignment: .leading)
                                    Picker(
                                        "",
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
                                    .labelsHidden()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }

                                GridRow {
                                    Text("AI Chat")
                                        .frame(width: 140, alignment: .leading)
                                    Picker(
                                        "",
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
                                    .labelsHidden()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }

                                GridRow {
                                    Text("Auto Clear Tabs")
                                        .frame(width: 140, alignment: .leading)
                                    Picker(
                                        "",
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
                                    .labelsHidden()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }

                        SettingsCard(header: "Clear Data") {
                            VStack(spacing: 8) {
                                Button(
                                    clearDataButtonTitle(
                                        for: .cache(container.id),
                                        defaultTitle: "Clear Cache",
                                        completedTitle: "Cache Cleared"
                                    )
                                ) {
                                    PrivacyService.clearCache(container) {
                                        DispatchQueue.main.async {
                                            completedClearActions.insert(.cache(container.id))
                                            toastManager.show("Cache cleared", icon: .system("trash"))
                                        }
                                    }
                                }
                                .disabled(completedClearActions.contains(.cache(container.id)))
                                .frame(maxWidth: .infinity, alignment: .leading)

                                Button(
                                    clearDataButtonTitle(
                                        for: .cookies(container.id),
                                        defaultTitle: "Clear Cookies",
                                        completedTitle: "Cookies Cleared"
                                    )
                                ) {
                                    PrivacyService.clearCookies(container) {
                                        DispatchQueue.main.async {
                                            completedClearActions.insert(.cookies(container.id))
                                            toastManager.show("Cookies cleared", icon: .system("trash"))
                                        }
                                    }
                                }
                                .disabled(completedClearActions.contains(.cookies(container.id)))
                                .frame(maxWidth: .infinity, alignment: .leading)

                                Button(
                                    clearDataButtonTitle(
                                        for: .history(container.id),
                                        defaultTitle: "Clear History",
                                        completedTitle: "History Cleared"
                                    )
                                ) {
                                    if clearHistory(for: container) {
                                        completedClearActions.insert(.history(container.id))
                                        toastManager.show("History cleared", icon: .system("trash"))
                                    }
                                }
                                .disabled(completedClearActions.contains(.history(container.id)))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.bordered)
                        }

                    } else {
                        Text("No spaces found")
                            .foregroundStyle(.secondary)
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
        .onAppear { if selectedContainerId == nil { selectedContainerId = containers.first?.id } }
    }

    private func clearHistory(for container: TabContainer) -> Bool {
        let containerId = container.id
        let descriptor = FetchDescriptor<History>(
            predicate: #Predicate { $0.container?.id == containerId }
        )

        do {
            let histories = try modelContext.fetch(descriptor)
            for history in histories {
                modelContext.delete(history)
            }
            try modelContext.save()
            return true
        } catch {
            print("Failed to clear history for container \(container.id): \(error.localizedDescription)")
            return false
        }
    }

    private func clearDataButtonTitle(
        for action: ClearDataAction,
        defaultTitle: String,
        completedTitle: String
    ) -> String {
        completedClearActions.contains(action) ? completedTitle : defaultTitle
    }
}
