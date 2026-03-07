import SwiftUI

struct PlayerIconButtonStyle: ButtonStyle {
    let isEnabled: Bool
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isEnabled ? Color.white.opacity(isHovering || configuration.isPressed ? 0.95 : 0.82)
                : Color.white.opacity(0.35)
            )
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        isEnabled
                            ? (configuration.isPressed ? Color.white.opacity(0.18)
                                : (isHovering ? Color.white.opacity(0.10) : Color.clear)
                            )
                            : Color.clear
                    )
            )
            .scaleEffect(configuration.isPressed && isEnabled ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isHovering || configuration.isPressed)
            .onHover { hovering in
                if isEnabled { isHovering = hovering }
            }
    }
}
