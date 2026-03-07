import SwiftUI

struct EmptyFavTabItem: View {
    @Environment(\.theme) var theme
    @State private var isTargeted = false

    let cornerRadius: CGFloat = 8

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "star")
                .font(.system(size: 16))
                .foregroundColor(theme.mutedForeground)

            Text("Drag a tab here to \n add it to your favorites")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(theme.mutedForeground)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .frame(height: 96)
        .background(theme.invertedSolidWindowBackgroundColor.opacity(0.07))
        .cornerRadius(cornerRadius)
        .overlay(
            ConditionallyConcentricRectangle(cornerRadius: cornerRadius)
                .stroke(
                    theme.invertedSolidWindowBackgroundColor.opacity(0.25),
                    style: StrokeStyle(lineWidth: 1, dash: [5, 5])
                )
        )
        .onHover { isTargeted = $0 }
    }
}
