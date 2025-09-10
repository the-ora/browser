import Foundation
import SwiftData

// MARK: - Folder

@Model
class Folder: ObservableObject, Identifiable {
    var id: UUID
    var name: String
    var isOpened: Bool
    var order: Int

    @Relationship(deleteRule: .nullify) var tabs: [Tab] = []
    @Relationship(inverse: \TabContainer.folders) var container: TabContainer
    init(
        id: UUID = UUID(),
        name: String,
        isOpened: Bool = false,
        order: Int = 0,
        container: TabContainer
    ) {
        self.id = id
        self.name = name
        self.isOpened = isOpened
        self.order = order
        self.container = container
    }
}
