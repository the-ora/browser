import AppKit
import SwiftUI

struct ShareLinkButton: View {
    let isEnabled: Bool
    let foregroundColor: Color
    let onShare: (NSView, NSRect) -> Void

    @State private var shareSourceView: NSView?

    var body: some View {
        URLBarButton(
            systemName: "square.and.arrow.up",
            isEnabled: isEnabled,
            foregroundColor: foregroundColor,
            action: {
                if let sourceView = shareSourceView {
                    let rect = sourceView.bounds
                    onShare(sourceView, rect)
                }
            }
        )
        .background(
            ShareSourceView { nsView in
                shareSourceView = nsView
            }
        )
    }
}

private struct ShareSourceView: NSViewRepresentable {
    let onViewCreated: (NSView) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        DispatchQueue.main.async {
            onViewCreated(view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Nothing to update
    }
}
