import SwiftUI

// MARK: - Navigation Button

struct NavigationButton: View {
    let systemName: String
    let isEnabled: Bool
    let foregroundColor: Color
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isEnabled ? (isHovering ? foregroundColor.opacity(0.8) : foregroundColor) : foregroundColor.opacity(0.5))
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(isHovering && isEnabled ? foregroundColor.opacity(0.1) : Color.clear)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
