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
        guard !isPrivate else { return }
        let urlString = url.absoluteString
        let now = Date()

        // 1. Handle consolidated history (existing behavior)
        let descriptor = FetchDescriptor<History>(
            predicate: #Predicate<History> { history in
                history.urlString == urlString
            },
            sortBy: [.init(\.lastAccessedAt, order: .reverse)]
        )

        let consolidatedHistory: History
        if let existing = try? modelContext.fetch(descriptor).first(where: { $0.container?.id == container.id }) {
            existing.visitCount += 1
            existing.lastAccessedAt = now
            consolidatedHistory = existing
        } else {
            let defaultFaviconURL = URL(string: "https://www.google.com/s2/favicons?domain=\(url.host ?? "google.com")")
            let fallbackURL = URL(fileURLWithPath: "")
            let resolvedFaviconURL = faviconURL ?? defaultFaviconURL ?? fallbackURL
            consolidatedHistory = History(
                url: url,
                title: title,
                faviconURL: resolvedFaviconURL,
                faviconLocalFile: faviconLocalFile,
                createdAt: now,
                lastAccessedAt: now,
                visitCount: 1,
                container: container
            )
            modelContext.insert(consolidatedHistory)
        }

        // 2. Always create a new chronological visit entry
        let visit = HistoryVisit(
            url: url,
            title: title,
            visitedAt: now,
            faviconURL: faviconURL,
            faviconLocalFile: faviconLocalFile,
            historyEntry: consolidatedHistory
        )
        modelContext.insert(visit)

        // 3. Add visit to the consolidated history's visits array
        consolidatedHistory.visits.append(visit)

        try? modelContext.save()
    }

    func search(_ text: String, activeContainerId: UUID) -> [History] {
        let trimmedText = text.trimmingCharacters(in: .whitespaces)

        // Define the predicate for searching
        let predicate: Predicate<History>
        if trimmedText.isEmpty {
            // If the search text is empty, return all records
            predicate = #Predicate { _ in true }
        } else {
            // Case-insensitive substring search on url and title
            predicate = #Predicate { history in
                (history.urlString.localizedStandardContains(trimmedText) ||
                    history.title.localizedStandardContains(trimmedText)
                ) && history.container != nil && history.container!.id == activeContainerId
            }
        }

        // Create fetch descriptor with predicate and sorting
        let descriptor = FetchDescriptor<History>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.lastAccessedAt, order: .reverse)]
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

        // Fetch all visits and filter in-memory to avoid force unwraps
        let visitDescriptor = FetchDescriptor<HistoryVisit>()

        do {
            let histories = try modelContext.fetch(descriptor)
            let allVisits = try modelContext.fetch(visitDescriptor)

            // Filter visits safely without force unwraps
            let visitsToDelete = allVisits.filter { visit in
                guard let historyEntry = visit.historyEntry,
                      let visitContainer = historyEntry.container
                else {
                    return false
                }
                return visitContainer.id == containerId
            }

            for history in histories {
                modelContext.delete(history)
            }

            for visit in visitsToDelete {
                modelContext.delete(visit)
            }

            try modelContext.save()
        } catch {
            logger.error("Failed to clear history for container \(container.id): \(error.localizedDescription)")
        }
    }

    // MARK: - Chronological History Methods

    func getChronologicalHistory(for containerId: UUID, limit: Int? = nil) -> [HistoryVisit] {
        // Fetch all visits first, then filter in-memory to avoid SwiftData predicate limitations
        var descriptor = FetchDescriptor<HistoryVisit>(
            sortBy: [SortDescriptor(\.visitedAt, order: .reverse)]
        )

        if let limit {
            descriptor.fetchLimit = limit * 3 // Fetch more to account for filtering
        }

        do {
            let allVisits = try modelContext.fetch(descriptor)
            let filteredVisits = allVisits.filter { visit in
                guard let historyEntry = visit.historyEntry,
                      let container = historyEntry.container
                else {
                    return false
                }
                return container.id == containerId
            }

            // Apply limit after filtering if specified
            if let limit {
                return Array(filteredVisits.prefix(limit))
            }
            return filteredVisits
        } catch {
            logger.error("Error fetching chronological history: \(error.localizedDescription)")
            return []
        }
    }

    func searchChronologicalHistory(_ text: String, activeContainerId: UUID) -> [HistoryVisit] {
        let trimmedText = text.trimmingCharacters(in: .whitespaces)

        // Fetch all visits first, then filter in-memory for better safety and flexibility
        let descriptor = FetchDescriptor<HistoryVisit>(
            sortBy: [SortDescriptor(\.visitedAt, order: .reverse)]
        )

        do {
            let allVisits = try modelContext.fetch(descriptor)
            let filteredVisits = allVisits.filter { visit in
                // Defensive filtering for container match
                guard let historyEntry = visit.historyEntry,
                      let container = historyEntry.container
                else {
                    return false
                }

                let containerMatches = container.id == activeContainerId

                // If no search text, just return container matches
                if trimmedText.isEmpty {
                    return containerMatches
                }

                // Check if text matches URL or title
                let textMatches = visit.urlString.localizedStandardContains(trimmedText) ||
                    visit.title.localizedStandardContains(trimmedText)

                return containerMatches && textMatches
            }

            return filteredVisits
        } catch {
            logger.error("Error searching chronological history: \(error.localizedDescription)")
            return []
        }
    }

    func deleteHistoryVisit(_ visit: HistoryVisit) {
        modelContext.delete(visit)
        try? modelContext.save()
    }

    func deleteHistoryVisits(_ visits: [HistoryVisit]) {
        for visit in visits {
            modelContext.delete(visit)
        }
        try? modelContext.save()
    }
}
