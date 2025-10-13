import AppKit
import SwiftUI

enum WindowControlType {
    case close, minimize, zoom
}

struct WindowControls: View {
    @State private var isHovered = false
    let isFullscreen: Bool

    var body: some View {
        if !isFullscreen {
            HStack(spacing: 9) {
                WindowControlButton(type: .close, isHovered: $isHovered)
                WindowControlButton(type: .minimize, isHovered: $isHovered)
                WindowControlButton(type: .zoom, isHovered: $isHovered)
            }
            .padding(.horizontal, 8)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isHovered = hovering
                }
            }
        } else {
            EmptyView()
        }
    }
}

struct WindowControlButton: View {
    let type: WindowControlType
    @Binding var isHovered: Bool

    private var buttonSize: CGFloat {
        if #available(macOS 26.0, *) {
            return 14
        } else {
            return 12
        }
    }

    private var assetBaseName: String {
        switch type {
        case .close: return "close"
        case .minimize: return "minimize"
        case .zoom: return "maximize"
        }
    }

    var body: some View {
        Image(isHovered ? "\(assetBaseName)-hover" : "\(assetBaseName)-normal")
            .resizable()
            .frame(width: buttonSize, height: buttonSize)
            .onTapGesture {
                performAction()
            }
    }

    private func performAction() {
        guard let window = NSApp.keyWindow else { return }
        switch type {
        case .close:
            window.performClose(nil)
        case .minimize:
            window.performMiniaturize(nil)
        case .zoom:
            window.toggleFullScreen(nil)
        }
    }
}
