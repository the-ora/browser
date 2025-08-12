import SwiftUI

final class ToastManager: ObservableObject {
    @Published var toasts: [Toast] = []

    @discardableResult
    func show(message: String, systemImage: String? = "checkmark.circle.fill") -> String {
        let toast = Toast { id in
            ToastView(
                id: id, message: message, systemImage: systemImage,
                action: { [weak self] in self?.dismiss(id: id) }
            )
        }

        withAnimation(.bouncy) {
            toasts.append(toast)
        }

        return toast.id
    }

    func dismiss(id: String) {
        withAnimation(.bouncy) {
            toasts.removeAll(where: { $0.id == id })
        }
    }

    func dismissAll() {
        withAnimation(.bouncy) {
            toasts.removeAll()
        }
    }
}
