import SwiftUI

struct KeyCaptureView: NSViewRepresentable {
    var onKeyDown: (NSEvent) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            onKeyDown(event)
            return event
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
