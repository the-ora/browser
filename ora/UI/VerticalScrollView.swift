import AppKit
import SwiftUI

final class BaseVerticalScrollView: NSScrollView {
    init(contentView: NSView) {
        super.init(frame: .zero)

        drawsBackground = false
        hasVerticalScroller = false
        hasHorizontalScroller = false
        verticalScrollElasticity = .automatic
        horizontalScrollElasticity = .none
        translatesAutoresizingMaskIntoConstraints = false

        // Container that becomes the documentView
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        contentView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(contentView)

        self.documentView = container

        // Pin content to top/leading/trailing, but don't force it to match the
        // container's bottom so short content won't be centered.
        // Make the container at least as tall as the clip view so it's pinned to top.
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: container.topAnchor),
            contentView.bottomAnchor
                .constraint(lessThanOrEqualTo: container.bottomAnchor),

            // Track clip view width
            container.widthAnchor.constraint(equalTo: self.contentView.widthAnchor),

            // Ensure the document view is never shorter than the visible height
            container.heightAnchor.constraint(
                greaterThanOrEqualTo: self.contentView.heightAnchor
            )
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func scrollWheel(with event: NSEvent) {
        if abs(event.scrollingDeltaX) > 0, abs(event.scrollingDeltaY) < .ulpOfOne {
            nextResponder?.scrollWheel(with: event)
            return
        }
        super.scrollWheel(with: event)
    }

    override func reflectScrolledClipView(_ cView: NSClipView) {
        var origin = cView.bounds.origin
        if origin.x != 0 {
            origin.x = 0
            cView.setBoundsOrigin(origin)
        }
        super.reflectScrolledClipView(cView)
    }
}

struct VerticalScrollView<Content: View>: NSViewRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeNSView(context: Context) -> NSView {
        let hostingView = NSHostingView(rootView: content)
        let scrollView = BaseVerticalScrollView(contentView: hostingView)

        // Prefer expanding to the space SwiftUI offers
        scrollView.setContentHuggingPriority(.defaultLow, for: .vertical)
        scrollView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        return scrollView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard
            let scrollView = nsView as? BaseVerticalScrollView,
            let hostingView = scrollView.documentView?.subviews.first
            as? NSHostingView<Content>
        else { return }

        hostingView.rootView = content
    }

    // Make the representable adopt the proposed size from SwiftUI
    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: NSView,
        context: Context
    ) -> CGSize {
        CGSize(
            width: proposal.width ?? 0,
            height: proposal.height ?? 0
        )
    }
}
