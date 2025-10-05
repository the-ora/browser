import Foundation
import SwiftData

// SwiftData model for a browsing history entry
@Model
final class History {
    @Attribute(.unique) var id: UUID // Unique identifier
    var url: URL
    var urlString: String
    var title: String
    var faviconURL: URL?
    var faviconLocalFile: URL?
    var visitedAt: Date? // When this specific visit occurred

    @Relationship(inverse: \TabContainer.history) var container: TabContainer?

    init(
        id: UUID = UUID(),
        url: URL,
        title: String,
        faviconURL: URL? = nil,
        faviconLocalFile: URL? = nil,
        visitedAt: Date? = Date(),
        container: TabContainer? = nil
    ) {
        self.id = id
        self.url = url
        self.urlString = url.absoluteString
        self.title = title
        self.faviconURL = faviconURL
        self.faviconLocalFile = faviconLocalFile
        self.visitedAt = visitedAt
        self.container = container
    }
}
