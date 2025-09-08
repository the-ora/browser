import SwiftUI

struct AIMessageBubble: View {
    let message: AIMessage
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.sender == .user {
                Spacer(minLength: 80)
                messageContent
                    .background(theme.foreground.opacity(0.1))
            } else {
                aiAvatar
                messageContent
                    .background(theme.background.opacity(0.05))
                Spacer(minLength: 80)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var messageContent: some View {
        VStack(alignment: message.sender == .user ? .trailing : .leading, spacing: 4) {
            Text(message.content)
                .textSelection(.enabled)
                .font(.body)
                .foregroundStyle(theme.foreground)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(message.sender == .user ? theme.foreground.opacity(0.1) : theme.background.opacity(0.05))
                )

            Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
    }

    private var aiAvatar: some View {
        Image(systemName: "apple.intelligence")
            .font(.title2)
            .foregroundStyle(.tint)
            .frame(width: 32, height: 32)
            .background(
                Circle()
                    .fill(theme.background.opacity(0.1))
            )
    }

    private var streamingIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0 ..< 3, id: \.self) { index in
                Circle()
                    .fill(.secondary)
                    .frame(width: 4, height: 4)
                    .scaleEffect(1.0)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2)
                    )
            }
        }
        .padding(.horizontal, 12)
    }
}

#Preview {
    VStack {
        AIMessageBubble(message: AIMessage.aiMessage(
            content: "Hello! How can I help you today?"
        ))

        AIMessageBubble(message: AIMessage.userMessage(
            content: "Can you help me write a SwiftUI view?"
        ))

        AIMessageBubble(message: AIMessage.aiMessage(
            content: "I'm currently generating a response for you..."
        ))
    }
    .padding()
}
