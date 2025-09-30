import SwiftUI

struct FloatingSidebarOverlay: View {
    @Binding var showFloatingSidebar: Bool
    @Binding var isMouseOverSidebar: Bool
    @ObservedObject var sidebarFraction: FractionHolder
    let isFullscreen: Bool
    let isDownloadsPopoverOpen: Bool

    @State private var dragFraction: CGFloat?

    var body: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let minFraction: CGFloat = 0.16
            let maxFraction: CGFloat = 0.30
            let currentFraction = dragFraction ?? sidebarFraction.value
            let clampedFraction =
                min(max(currentFraction, minFraction), maxFraction)
            let floatingWidth = max(
                0, min(totalWidth * clampedFraction, totalWidth)
            )

            ZStack(alignment: .leading) {
                if showFloatingSidebar {
                    FloatingSidebar(isFullscreen: isFullscreen)
                        .frame(width: floatingWidth)
                        .transition(.move(edge: .leading))
                        .overlay(alignment: .trailing) {
                            ResizeHandle(
                                dragFraction: $dragFraction,
                                sidebarFraction: sidebarFraction,
                                floatingWidth: floatingWidth,
                                totalWidth: totalWidth,
                                minFraction: minFraction,
                                maxFraction: maxFraction
                            )
                        }
                        .zIndex(3)
                }

                Color.clear
                    .frame(width: showFloatingSidebar ? floatingWidth : 10)
                    .overlay(
                        MouseTrackingArea(
                            mouseEntered: Binding(
                                get: { showFloatingSidebar },
                                set: { newValue in
                                    isMouseOverSidebar = newValue
                                    if !newValue, isDownloadsPopoverOpen {
                                        return
                                    }
                                    showFloatingSidebar = newValue
                                }
                            )
                        )
                    )
                    .zIndex(2)
            }
        }
    }
}

private struct ResizeHandle: View {
    @Binding var dragFraction: CGFloat?
    var sidebarFraction: FractionHolder
    let floatingWidth: CGFloat
    let totalWidth: CGFloat
    let minFraction: CGFloat
    let maxFraction: CGFloat

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 14)
        #if targetEnvironment(macCatalyst) || os(macOS)
            .cursor(NSCursor.resizeLeftRight)
        #endif
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let proposedWidth = max(
                            0,
                            min(
                                floatingWidth + value.translation.width,
                                totalWidth
                            )
                        )
                        let newFraction = proposedWidth / max(totalWidth, 1)
                        dragFraction = min(
                            max(newFraction, minFraction), maxFraction
                        )
                    }
                    .onEnded { _ in
                        if let fraction = dragFraction {
                            sidebarFraction.value = fraction
                        }
                        dragFraction = nil
                    }
            )
    }
}
