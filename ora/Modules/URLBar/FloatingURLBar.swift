import SwiftUI

struct FloatingURLBar: View {
    @Binding var showFloatingURLBar: Bool
    @Binding var isMouseOverURLBar: Bool

    var body: some View {
        ZStack(alignment: .top) {
            if showFloatingURLBar {
                URLBar(
                    onSidebarToggle: {
                        NotificationCenter.default.post(
                            name: .toggleSidebar, object: nil
                        )
                    }
                )
                .shadow(color: Color.black.opacity(0.2), radius: 10, y: 4)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(1)
            }

            VStack(alignment: .leading) {
                hoverStrip(width: .infinity)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
        }
        .animation(.easeInOut(duration: 0.1), value: showFloatingURLBar)
    }

    @ViewBuilder
    private func hoverStrip(width: CGFloat) -> some View {
        Color.clear
            .overlay(
                GlobalMouseTrackingArea(
                    mouseEntered: Binding(
                        get: { showFloatingURLBar },
                        set: { newValue in
                            withAnimation(.easeInOut(duration: 0.25)) {
                                isMouseOverURLBar = newValue
                                showFloatingURLBar = newValue
                            }
                        }
                    ),
                    edge: .top,
                    padding: 40,
                    slack: 8
                )
            )
    }
}
