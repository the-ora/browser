import SwiftData
import SwiftUI

struct ContainerSwitcher: View {
    let onContainerSelected: (TabContainer) -> Void

    @Environment(\.theme) private var theme
    @Environment(TabManager.self) private var tabManager
    @Query var containers: [TabContainer]

    @State private var hoveredContainer: UUID?

    private let normalButtonWidth: CGFloat = 28
    private let compactButtonWidth: CGFloat = 12

    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let totalWidth =
                CGFloat(containers.count) * normalButtonWidth + CGFloat(max(0, containers.count - 1))
                    * 2
            let isCompact = totalWidth > availableWidth

            HStack(alignment: .center, spacing: isCompact ? 4 : 2) {
                ForEach(containers, id: \.id) { container in
                    containerButton(for: container, isCompact: isCompact)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(0)
        }
        .padding(0)
        .frame(height: 28)
    }

    @ViewBuilder
    private func containerButton(for container: TabContainer, isCompact: Bool) -> some View {
        let isActive = tabManager.activeContainer?.id == container.id
        let isHovered = hoveredContainer == container.id
        let displayEmoji =
            isCompact && !isActive ? (isHovered ? container.emoji : "•") : container.emoji
        let buttonSize =
            isCompact && !isActive
                ? (isHovered ? compactButtonWidth + 4 : compactButtonWidth) : normalButtonWidth
        let fontSize: CGFloat = isCompact && !isActive ? (isHovered ? 12 : 12) : 12

        Button(action: {
            onContainerSelected(container)
        }) {
            HStack {
                Text(displayEmoji)
                    .font(.system(size: fontSize))
                    .foregroundColor(.secondary)
            }
            .frame(width: buttonSize, height: buttonSize)
            .grayscale(!isActive && !isHovered ? 0.5 : 0)
            .opacity(!isCompact && !isActive && !isHovered ? 0.5 : 1)
            .background(
                !isCompact && isHovered
                    ? theme.invertedSolidWindowBackgroundColor.opacity(0.3)
                    : isActive
                    ? theme.invertedSolidWindowBackgroundColor.opacity(0.2)
                    : .clear
            )
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: isActive || isHovered)
        .onHover { isHovering in
            withAnimation(.easeOut(duration: 0.15)) {
                hoveredContainer = isHovering ? container.id : nil
            }
        }
        .contextMenu {
            Button("Rename Container") {
                // tabManager.renameContainer(container, name: "New Name", emoji: "💩")
            }
            Button("Delete Container") {
                tabManager.deleteContainer(container)
            }
        }
    }
}
