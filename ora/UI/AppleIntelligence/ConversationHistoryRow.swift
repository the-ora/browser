import SwiftData
import SwiftUI

struct ConversationHistoryRow: View {
    let conversation: AIConversation
    let isActive: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @Environment(\.theme) private var theme
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Conversation Content
            VStack(alignment: .leading, spacing: 4) {
                Text(conversation.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(theme.foreground)
                    .lineLimit(1)

                if let lastMessage = conversation.messages.last {
                    Text(lastMessage.content)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    Text("New conversation")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .italic()
                }

                HStack {
                    Text(conversation.lastAccessedAt, style: .relative)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)

                    Spacer()

                    if !conversation.messages.isEmpty {
                        Text("\(conversation.messages.count) message\(conversation.messages.count == 1 ? "" : "s")")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            // Delete button (shown on hover)
            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .opacity(0.7)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? theme.foreground.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? theme.foreground.opacity(0.2) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isActive)
    }
}

#Preview {
    VStack {
        ConversationHistoryRow(
            conversation: AIConversation(name: "Help with SwiftUI"),
            isActive: false,
            onSelect: {},
            onDelete: {}
        )

        ConversationHistoryRow(
            conversation: AIConversation(name: "Current conversation with a longer title"),
            isActive: true,
            onSelect: {},
            onDelete: {}
        )
    }
    .padding()
    .background(Color(.windowBackgroundColor))
}
