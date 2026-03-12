import SwiftUI

struct SettingsCard<Content: View>: View {
    var header: String?
    var description: String?
    @ViewBuilder var content: () -> Content

    let cornerRadius: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if header != nil || description != nil {
                VStack(alignment: .leading, spacing: 4) {
                    if let header {
                        Text(header)
                            .font(.headline)
                    }
                    if let description {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ConditionallyConcentricRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.72))
        }
        .overlay {
            ConditionallyConcentricRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
        }
        .clipShape(ConditionallyConcentricRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
    }
}
