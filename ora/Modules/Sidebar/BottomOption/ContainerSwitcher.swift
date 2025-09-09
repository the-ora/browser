import SwiftData
import SwiftUI

struct ContainerSwitcher: View {
    let onContainerSelected: (TabContainer) -> Void

    @Environment(\.theme) private var theme
    @EnvironmentObject var tabManager: TabManager
    @Query var containers: [TabContainer]

    @State private var hoveredContainer: UUID?

    private let normalButtonWidth: CGFloat = 28
    let defaultEmoji = "•"
    // Never used
//    private let compactButtonWidth: CGFloat = 12

    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let totalWidth =
                CGFloat(containers.count) * normalButtonWidth + CGFloat(max(0, containers.count - 1))
                    * 2
//            let isCompact = totalWidth > availableWidth

            HStack(alignment: .center, spacing: 2 /* isCompact ? 4 : 2 */ ) {
                ForEach(containers, id: \.id) { container in
                    containerButton(for: container /* , isCompact: isCompact */ )
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(0)
        }
        .padding(0)
        .frame(height: 28)
    }

    @ViewBuilder
    private func containerButton(for container: TabContainer /* , isCompact: Bool */ )
        -> some View
    { // ditching isCompact -> never used
        let isActive = tabManager.activeContainer?.id == container.id
        let isHovered = hoveredContainer == container.id
        let displayEmoji = container.emoji.isEmpty ? defaultEmoji : container.emoji
        let fontSize = dynamicFontSize(for: displayEmoji, isActive: isActive)

        Button(action: {
            onContainerSelected(container)
        }) {
            HStack {
                Text(displayEmoji)
                    .font(.system(size: fontSize))
                    .foregroundColor(displayEmoji == defaultEmoji ? .primary : .secondary)
            }
            .frame(width: normalButtonWidth, height: normalButtonWidth)
            .grayscale(!isActive && !isHovered ? 0.5 : 0)
            .opacity(!isActive ? 0.5 : 1)
            .background(
                buttonBackground(isActive: isActive, isHovered: isHovered, emoji: displayEmoji)
            )
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: isActive || isHovered)
        .onHover { hoveredContainer = $0 ? container.id : nil }
        .contextMenu { contextMenuButtons(for: container) }
    }

    private func dynamicFontSize(for emoji: String, isActive: Bool) -> CGFloat {
        // normal emojis are sized correctly
        emoji == defaultEmoji ? 24 : 12
        // resize `dot` accordingly
    }

    private func buttonBackground(isActive: Bool, isHovered: Bool, emoji: String) -> Color {
        if isHovered {
            return theme.invertedSolidWindowBackgroundColor.opacity(0.3)
        } else if isActive, emoji != defaultEmoji {
            return theme.invertedSolidWindowBackgroundColor.opacity(0.2)
        }
        return .clear
    }

    @ViewBuilder
    private func contextMenuButtons(for container: TabContainer) -> some View {
        Button("Rename Container") {
            // tabManager.renameContainer(container, name: "New Name", emoji: "💩")
        }

        Button("Delete Container") {
            tabManager.deleteContainer(container)
        }
        .disabled(containers.count == 1) // disabled to avoid crashes
    }
}
