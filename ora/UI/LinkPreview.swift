import SwiftUI

struct LinkPreview: View {
    let text: String
    @Environment(\.theme) private var theme

    private func getAppVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        return "Ora \(version)"
    }

    var body: some View {
        VStack {
            Spacer()
            HStack {
                ZStack {
                    Text(text)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(theme.foreground)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .multilineTextAlignment(.leading)
                }
                .padding(6)
                .frame(minWidth: 1, idealWidth: 1, maxWidth: 500, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(theme.background)
                )
                .background(BlurEffectView(
                    material: .popover,
                    blendingMode: .withinWindow
                ))
                .overlay(
                    RoundedRectangle(cornerRadius: 99, style: .continuous)
                        .stroke(Color(.separatorColor), lineWidth: 1)
                )
                .cornerRadius(99)
                Spacer()

                // Version indicator (bottom-right)
                Text(getAppVersion())
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.black.opacity(0.2))
                    )
                    .padding(.trailing, 12)
            }
            .padding(.bottom, 8)
            .padding(.leading, 8)
        }
        .transition(.opacity)
        .animation(.easeOut(duration: 0.1), value: text)
        .zIndex(900)
    }
}
