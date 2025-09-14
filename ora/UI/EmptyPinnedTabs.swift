import SwiftUI

struct EmptyPinnedTabs: View {
    @Environment(\.theme) var theme
    @State private var isTargeted = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "pin")
                .font(.system(size: 12))
                .foregroundColor(theme.mutedForeground)

            Text("Drop here to pin a tab")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(theme.mutedForeground)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(theme.invertedSolidWindowBackgroundColor.opacity(0.07))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    theme.invertedSolidWindowBackgroundColor.opacity(0.25),
                    style: StrokeStyle(lineWidth: 1, dash: [5, 5])
                )
        )
        .onHover { isTargeted = $0 }
    }
}
