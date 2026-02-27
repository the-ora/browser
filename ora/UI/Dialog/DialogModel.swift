import SwiftUI

struct Dialog: Identifiable {
    private(set) var id: String = UUID().uuidString
    var content: AnyView
    var onConfirm: (() -> Void)?
    var onDismiss: (() -> Void)?

    init(@ViewBuilder content: @escaping (String) -> some View) {
        self.content = .init(content(id))
    }
}
