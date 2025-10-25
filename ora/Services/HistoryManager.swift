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
        container: TabContainer
    ) {
        let urlString = url.absoluteString

        // Check if a history record already exists for this URL
        let descriptor = FetchDescriptor<History>(
            predicate: #Predicate {
                $0.urlString == urlString
            },
            sortBy: [.init(\.lastAccessedAt, order: .reverse)]
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            existing.visitCount += 1
            existing.lastAccessedAt = Date() // update last visited time
        } else {
            let now = Date()
            let defaultFaviconURL =
                URL(string: "https://www.google.com/s2/favicons?domain=\(url.host ?? "google.com")&sz=64")
            let fallbackURL = URL(fileURLWithPath: "")
            let resolvedFaviconURL = faviconURL ?? defaultFaviconURL ?? fallbackURL
            modelContext.insert(History(
                url: url,
                title: title,
                faviconURL: resolvedFaviconURL,
                faviconLocalFile: faviconLocalFile,
                createdAt: now,
                lastAccessedAt: now,
                visitCount: 1,
                container: container
            ))
        }

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
}
