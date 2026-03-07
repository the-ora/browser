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
        context.coordinator.installMonitor(onKeyDown: onKeyDown)
        return NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.installMonitor(onKeyDown: onKeyDown)
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

        func installMonitor(onKeyDown: @escaping (NSEvent) -> NSEvent?) {
            removeMonitor()
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
                onKeyDown(event)
            }
        }

        func removeMonitor() {
            guard let monitor else { return }
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
