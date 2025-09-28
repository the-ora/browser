import Foundation
import SwiftData

// SwiftData model for individual chronological browsing history visits
@Model
final class HistoryVisit {
    @Attribute(.unique) var id: UUID
    var url: URL
    var urlString: String
    var title: String
    var visitedAt: Date
    var faviconURL: URL?
    var faviconLocalFile: URL?

    // Relationship to consolidated history entry
    @Relationship(inverse: \History.visits) var historyEntry: History?

    init(
        id: UUID = UUID(),
        url: URL,
        title: String,
        visitedAt: Date = Date(),
        faviconURL: URL? = nil,
        faviconLocalFile: URL? = nil,
        historyEntry: History? = nil
    ) {
        self.id = id
        self.url = url
        self.urlString = url.absoluteString
        self.title = title
        self.visitedAt = visitedAt
        self.faviconURL = faviconURL
        self.faviconLocalFile = faviconLocalFile
        self.historyEntry = historyEntry
    }
}
