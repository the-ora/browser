import SwiftUI

struct KeyCaptureView: NSViewRepresentable {
    private let onKeyDown: (NSEvent) -> NSEvent?

    init(onKeyDown: @escaping (NSEvent) -> Void) {
        self.onKeyDown = { event in
            onKeyDown(event)
            return event
        }
    }

    init(onKeyDownResult: @escaping (NSEvent) -> NSEvent?) {
        self.onKeyDown = onKeyDownResult
    }

    func makeNSView(context: Context) -> NSView {
        context.coordinator.updateOnKeyDown(onKeyDown)
        return NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.updateOnKeyDown(onKeyDown)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.removeMonitor()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
}

extension KeyCaptureView {
    final class Coordinator {
        private var monitor: Any?
        private var onKeyDown: ((NSEvent) -> NSEvent?)?

        func updateOnKeyDown(_ onKeyDown: @escaping (NSEvent) -> NSEvent?) {
            self.onKeyDown = onKeyDown

            guard monitor == nil else { return }

            monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
                self?.onKeyDown?(event) ?? event
            }
        }

        func removeMonitor() {
            guard let monitor else { return }
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
