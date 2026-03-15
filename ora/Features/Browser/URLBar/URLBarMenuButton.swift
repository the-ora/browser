import AppKit
import SwiftUI

struct URLBarMenuButton: View {
    let foregroundColor: Color
    let onShare: (NSView, NSRect) -> Void

    @State private var isHovering = false
    @State private var menuSourceView: NSView?

    private var cornerRadius: CGFloat {
        if #available(macOS 26, *) {
            return 10
        } else {
            return 6
        }
    }

    var body: some View {
        Button {
            showMenu()
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isHovering ? foregroundColor : foregroundColor.opacity(0.7))
                .frame(width: 30, height: 30)
                .background(
                    ConditionallyConcentricRectangle(cornerRadius: cornerRadius)
                        .fill(isHovering ? foregroundColor.opacity(0.1) : Color.clear)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovering = hovering
        }
        .background(
            MenuSourceView { nsView in
                menuSourceView = nsView
            }
        )
    }

    private func showMenu() {
        guard let sourceView = menuSourceView else { return }

        let menu = NSMenu()

        let shareItem = NSMenuItem(
            title: "Share link",
            action: #selector(MenuActions.shareAction(_:)),
            keyEquivalent: ""
        )
        let delegate = MenuActions { [sourceView] in
            let rect = sourceView.bounds
            onShare(sourceView, rect)
        }
        shareItem.target = delegate
        shareItem.representedObject = delegate // prevent deallocation
        menu.addItem(shareItem)

        let point = NSPoint(x: 0, y: sourceView.bounds.height + 4)
        menu.popUp(positioning: nil, at: point, in: sourceView)
    }
}

private class MenuActions: NSObject {
    let handler: () -> Void

    init(handler: @escaping () -> Void) {
        self.handler = handler
    }

    @objc func shareAction(_ sender: Any?) {
        handler()
    }
}

private struct MenuSourceView: NSViewRepresentable {
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

    func updateNSView(_ nsView: NSView, context: Context) {}
}
