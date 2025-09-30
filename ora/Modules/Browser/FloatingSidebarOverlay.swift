import SwiftUI

struct FloatingSidebarOverlay: View {
    @Binding var showFloatingSidebar: Bool
    @Binding var isMouseOverSidebar: Bool
    var sidebarFraction: FractionHolder
    let sidebarPosition: SidebarPosition
    let isFullscreen: Bool
    let isDownloadsPopoverOpen: Bool

    @State private var dragFraction: CGFloat?

    var body: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let minFraction: CGFloat = 0.16
            let maxFraction: CGFloat = 0.30
            let currentFraction = dragFraction ?? sidebarFraction.value
            let clampedFraction = min(max(currentFraction, minFraction), maxFraction)
            let floatingWidth = max(0, min(totalWidth * clampedFraction, totalWidth))

            ZStack(alignment: sidebarPosition == .primary ? .leading : .trailing) {
                if showFloatingSidebar {
                    FloatingSidebar(isFullscreen: isFullscreen, sidebarPosition: sidebarPosition)
                        .frame(width: floatingWidth)
                        .transition(.move(edge: sidebarPosition == .primary ? .leading : .trailing))
                        .overlay(alignment: sidebarPosition == .primary ? .trailing : .leading) {
                            ResizeHandle(
                                dragFraction: $dragFraction,
                                sidebarFraction: sidebarFraction,
                                sidebarPosition: sidebarPosition,
                                floatingWidth: floatingWidth,
                                totalWidth: totalWidth,
                                minFraction: minFraction,
                                maxFraction: maxFraction
                            )
                        }
                        .zIndex(3)
                }

                HStack(spacing: 0) {
                    if sidebarPosition == .primary {
                        hoverStrip(width: showFloatingSidebar ? floatingWidth : 10)
                        Spacer()
                    } else {
                        Spacer()
                        hoverStrip(width: showFloatingSidebar ? floatingWidth : 10)
                    }
                }
                .zIndex(2)
            }
        }
    }

    @ViewBuilder
    private func hoverStrip(width: CGFloat) -> some View {
        Color.clear
            .frame(width: width)
            .overlay(
                SidebarMouseTrackingArea(
                    mouseEntered: Binding(
                        get: { showFloatingSidebar },
                        set: { newValue in
                            isMouseOverSidebar = newValue
                            if !newValue, isDownloadsPopoverOpen {
                                return
                            }
                            showFloatingSidebar = newValue
                        }
                    ),
                    sidebarPosition: sidebarPosition
                )
            )
    }
}

private struct ResizeHandle: View {
    @Binding var dragFraction: CGFloat?
    var sidebarFraction: FractionHolder
    let sidebarPosition: SidebarPosition
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
                        let proposedWidth: CGFloat = if sidebarPosition == .primary {
                            max(0, min(floatingWidth + value.translation.width, totalWidth))
                        } else {
                            max(0, min(floatingWidth - value.translation.width, totalWidth))
                        }

                        let newFraction = proposedWidth / max(totalWidth, 1)
                        dragFraction = min(max(newFraction, minFraction), maxFraction)
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
