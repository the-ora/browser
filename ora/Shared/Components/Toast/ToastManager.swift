import SwiftUI

final class ToastManager: ObservableObject {
    static let shared = ToastManager()

    @Published var toasts: [Toast] = []

    private var dismissTimers: [String: DispatchWorkItem] = [:]
    private var isHovered: Bool = false

    var position: ToastPosition = .bottomCenter
    var defaultDuration: TimeInterval = 4.0

    @discardableResult
    func show(
        _ message: String,
        type: ToastType = .success,
        icon: ToastIcon? = nil,
        duration: TimeInterval? = nil
    ) -> String {
        let toast = Toast(message: message, type: type, icon: icon)

        withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
            toasts.append(toast)
        }

        scheduleDismiss(for: toast.id, after: duration ?? defaultDuration)

        return toast.id
    }

    func dismiss(id: String) {
        dismissTimers[id]?.cancel()
        dismissTimers.removeValue(forKey: id)

        withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
            toasts.removeAll { $0.id == id }
        }
    }

    func dismissAll() {
        for (_, timer) in dismissTimers {
            timer.cancel()
        }
        dismissTimers.removeAll()

        withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
            toasts.removeAll()
        }
    }

    func pauseTimers() {
        isHovered = true
        dismissTimers.values.forEach { $0.cancel() }
        dismissTimers.removeAll()
    }

    func resumeTimers() {
        isHovered = false
        for toast in toasts {
            scheduleDismiss(for: toast.id, after: defaultDuration)
        }
    }

    private func scheduleDismiss(for id: String, after duration: TimeInterval) {
        guard !isHovered else { return }

        dismissTimers[id]?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.dismiss(id: id)
        }

        dismissTimers[id] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
    }
}
