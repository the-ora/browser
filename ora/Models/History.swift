import Foundation
import SwiftData
// SwiftData model for a browsing history entry
@Model
final class History {
    @Attribute(.unique) var id: UUID // Unique identifier
    var url: String
    var title: String
    var faviconURL: String
    var createdAt: Date
    var visitCount: Int
    var lastAccessedAt: Date
    
    init(id: UUID = UUID(), url: String, title: String, faviconURL: String, createdAt: Date,lastAccessedAt: Date, visitCount: Int) {
        let now = Date()
        self.id = id
        self.url = url
        self.title = title
        self.faviconURL = faviconURL
        self.createdAt = now
        self.lastAccessedAt = now
        self.visitCount = visitCount
    }
}
