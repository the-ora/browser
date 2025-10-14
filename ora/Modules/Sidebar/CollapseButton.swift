import AppKit
import SwiftUI

struct CollapseButton: View {
    @Binding var isSidebarCollapsed: Bool

    @Environment(\.theme) private var theme

    @State var isHovering = false

    var body: some View {
        Button(action: {
            isSidebarCollapsed.toggle()
        }) {
            HStack {
                Image(systemName: isSidebarCollapsed ? "chevron.right" : "chevron.left")
                    .frame(width: 12, height: 22)
                    .foregroundColor(.secondary)
            }
            .padding(8)
            .background(isHovering ? theme.invertedSolidWindowBackgroundColor.opacity(0.3) : .clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .onHover { isHovering  = $0 }
    }
}
