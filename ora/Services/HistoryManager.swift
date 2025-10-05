import Foundation
import os.log
import SwiftData

private let logger = Logger(subsystem: "com.orabrowser.ora", category: "HistoryManager")

@MainActor
class HistoryManager: ObservableObject {
    let modelContainer: ModelContainer
    let modelContext: ModelContext

    init(modelContainer: ModelContainer, modelContext: ModelContext) {
        self.modelContainer = modelContainer
        self.modelContext = modelContext
    }

    func record(
        title: String,
        url: URL,
        faviconURL: URL? = nil,
        faviconLocalFile: URL? = nil,
        container: TabContainer,
        isPrivate: Bool = false
    ) {
        // Don't save history in private mode
        guard !isPrivate else {
            logger.debug("Skipping history recording - private mode")
            return
        }
        let now = Date()

        // Create a new history entry for each visit (no more consolidation)
        let defaultFaviconURL = URL(string: "https://www.google.com/s2/favicons?domain=\(url.host ?? "google.com")")
        let resolvedFaviconURL = faviconURL ?? defaultFaviconURL

        let historyEntry = History(
            url: url,
            title: title,
            faviconURL: resolvedFaviconURL,
            faviconLocalFile: faviconLocalFile,
            visitedAt: now,
            container: container
        )

        modelContext.insert(historyEntry)
        try? modelContext.save()
    }

    func search(_ text: String, activeContainerId: UUID) -> [History] {
        let trimmedText = text.trimmingCharacters(in: .whitespaces)

        // Define the predicate for searching
        let predicate: Predicate<History>
        if trimmedText.isEmpty {
            // If the search text is empty, return all records for the container
            predicate = #Predicate { history in
                history.container != nil && history.container!.id == activeContainerId
            }
        } else {
            // Case-insensitive substring search on url and title
            predicate = #Predicate { history in
                (history.urlString.localizedStandardContains(trimmedText) ||
                    history.title.localizedStandardContains(trimmedText)
                ) && history.container != nil && history.container!.id == activeContainerId
            }
        }

        // Create fetch descriptor with predicate and sorting by visitedAt (most recent first)
        let descriptor = FetchDescriptor<History>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.visitedAt, order: .reverse)]
        )

        do {
            // Fetch matching history records
            return try modelContext.fetch(descriptor)
        } catch {
            logger.error("Error fetching history: \(error.localizedDescription)")
            return []
        }
    }

    func clearContainerHistory(_ container: TabContainer) {
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
        } catch {
            logger.error("Failed to clear history for container \(container.id): \(error.localizedDescription)")
        }
    }

    // MARK: - Chronological History Methods

    func getChronologicalHistory(for containerId: UUID, limit: Int? = nil) -> [History] {
        let containerDescriptor = FetchDescriptor<TabContainer>(
            predicate: #Predicate<TabContainer> { $0.id == containerId }
        )

        do {
            let containers = try modelContext.fetch(containerDescriptor)
            if let container = containers.first {
                // Sort the history by visitedAt in reverse order (most recent first)
                let sortedHistory = container.history.sorted { $0.visitedAt > $1.visitedAt }

                // Apply limit if specified
                let results = limit != nil ? Array(sortedHistory.prefix(limit!)) : sortedHistory

                return results
            }
        } catch {
            logger.error("Error fetching container: \(error.localizedDescription)")
        }

        return []
    }

    func searchChronologicalHistory(_ text: String, activeContainerId: UUID) -> [History] {
        let trimmedText = text.trimmingCharacters(in: .whitespaces)

        // Get all history for the container first
        let allHistory = getChronologicalHistory(for: activeContainerId)

        // If no search text, return all
        if trimmedText.isEmpty {
            return allHistory
        }

        // Filter in memory for search text
        let filteredHistory = allHistory.filter { history in
            history.urlString.localizedStandardContains(trimmedText) ||
                history.title.localizedStandardContains(trimmedText)
        }

        return filteredHistory
    }

    func deleteHistory(_ history: History) {
        modelContext.delete(history)
        try? modelContext.save()
    }

    func deleteHistories(_ histories: [History]) {
        for history in histories {
            modelContext.delete(history)
        }
        try? modelContext.save()
    }
}
