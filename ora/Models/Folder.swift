import Foundation
import SwiftData

// MARK: - Folder

@Model
class Folder: ObservableObject, Identifiable {
    var id: UUID
    var name: String
    var isOpened: Bool

    @Relationship(inverse: \TabContainer.folders) var container: TabContainer
    init(
        id: UUID = UUID(),
        name: String,
        isOpened: Bool = false,
        container: TabContainer
    ) {
        self.id = UUID()
        self.name = name
        self.isOpened = isOpened
        self.container = container
    }
}
