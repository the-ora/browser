import Foundation
import SwiftData

@MainActor
class HistoryManager: ObservableObject {
    
    let modelContainer: ModelContainer
    let modelContext: ModelContext

    
 
    init(modelContainer: ModelContainer, modelContext: ModelContext) {
        self.modelContainer = modelContainer
        self.modelContext = modelContext
    }
    public func record(title: String, url: URL) {
        let urlString = url.absoluteString

        // Check if a history record already exists for this URL
        let descriptor = FetchDescriptor<History>(
            predicate: #Predicate { $0.url == urlString
 },
            sortBy: [.init(\.lastAccessedAt, order: .reverse)]
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            existing.visitCount += 1
            existing.lastAccessedAt = Date() // update last visited time
        } else {
            let now = Date()
            modelContext.insert(History(
                url: urlString,
                title: title,
                faviconURL: "https://www.google.com/s2/favicons?domain=\(url.host ?? "google.com")",
                createdAt: now,
                lastAccessedAt: now,
                visitCount: 1
            ))
        }

        try? modelContext.save()
    }
}
