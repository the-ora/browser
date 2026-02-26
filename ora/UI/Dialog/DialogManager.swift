import SwiftUI

final class DialogManager: ObservableObject {
    @Published var dialogs: [Dialog] = []

    @discardableResult
    func show(@ViewBuilder content: @escaping (String) -> some View) -> String {
        let dialog = Dialog { id in content(id) }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            dialogs.append(dialog)
        }
        return dialog.id
    }

    func dismiss(id: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            dialogs.removeAll(where: { $0.id == id })
        }
    }

    func dismissTop() {
        guard let last = dialogs.last else { return }
        dismiss(id: last.id)
    }

    func dismissAll() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            dialogs.removeAll()
        }
    }

    func confirm(
        title: String,
        message: String? = nil,
        icon: OraIconType? = nil,
        confirmLabel: String = "Confirm",
        variant: OraButtonVariant = .default,
        onConfirm: @escaping () -> Void
    ) {
        var dialog = Dialog { id in
            ConfirmDialogView(
                title: title,
                message: message,
                icon: icon,
                confirmLabel: confirmLabel,
                confirmVariant: variant,
                onConfirm: onConfirm,
                onCancel: { self.dismiss(id: id) }
            )
        }
        dialog.onConfirm = onConfirm
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            dialogs.append(dialog)
        }
    }
}
