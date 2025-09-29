import SwiftUI

struct HistoryViewPrivate: View {
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                HStack {
                    Text("History")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Spacer()
                }
            }
            .padding()

            Divider()

            // Private browsing zero state
            VStack(spacing: 16) {
                Spacer()

                Image(systemName: "eye.slash")
                    .font(.system(size: 64))
                    .foregroundColor(.secondary)

                VStack(spacing: 8) {
                    Text("Private Browsing")
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text("History is not saved in private browsing mode")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Text("Your browsing activity won't be stored or visible in your history.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 32)

                Spacer()
            }

            Spacer()
        }
        .background(theme.background)
    }
}

#Preview {
    HistoryViewPrivate()
        .withTheme()
}
