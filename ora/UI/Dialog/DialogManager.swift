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
        if let dialog = dialogs.first(where: { $0.id == id }) {
            dialog.onDismiss?()
        }
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
        iconImage: Image? = nil,
        confirmLabel: String = "Confirm",
        variant: OraButtonVariant = .default,
        onConfirm: @escaping () -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        final class ConfirmState { var confirmed = false }
        let state = ConfirmState()

        var dialog = Dialog { id in
            ConfirmDialogView(
                title: title,
                message: message,
                icon: icon,
                iconImage: iconImage,
                confirmLabel: confirmLabel,
                confirmVariant: variant,
                onConfirm: {
                    state.confirmed = true
                    onConfirm()
                    self.dismiss(id: id)
                },
                onCancel: { self.dismiss(id: id) }
            )
        }
        dialog.onConfirm = {
            state.confirmed = true
            onConfirm()
        }
        dialog.onDismiss = {
            if !state.confirmed { onCancel?() }
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            dialogs.append(dialog)
        }
    }
}
