import SwiftUI

struct AppearanceSelector: View {
    @Binding var selection: AppAppearance
    @Environment(\.theme) var theme

    private struct Option: Identifiable {
        let id = UUID()
        let appearance: AppAppearance
        let imageName: String
        let title: String
    }

    private var options: [Option] {
        [
            .init(appearance: .light, imageName: "appearance-light", title: "Light"),
            .init(appearance: .dark, imageName: "appearance-dark", title: "Dark"),
            .init(appearance: .system, imageName: "appearance-system", title: "Auto")
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Appearance").foregroundStyle(.secondary)
            HStack(spacing: 16) {
                ForEach(options) { opt in
                    let isSelected = selection == opt.appearance
                    Button {
                        selection = opt.appearance
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(opt.imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 105, height: 68)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            Text(opt.title)
                                .fontWeight(isSelected ? .semibold : .regular)
                        }
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(isSelected ? theme.foreground.opacity(0.12) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
