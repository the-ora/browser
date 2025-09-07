import SwiftUI

struct AIInputField: View {
    @Binding var text: String
    let onSend: (String) -> Void
    let isGenerating: Bool

    @Environment(\.theme) private var theme
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            inputField
            sendButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(theme.background.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(theme.foreground.opacity(0.1), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    private var inputField: some View {
        TextField("Ask Apple Intelligence...", text: $text, axis: .vertical)
            .textFieldStyle(PlainTextFieldStyle())
            .font(.body)
            .foregroundStyle(theme.foreground)
            .focused($isFocused)
            .lineLimit(1 ... 6)
            .onSubmit {
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !isGenerating {
                    sendMessage()
                }
            }
            .disabled(isGenerating)
    }

    private var sendButton: some View {
        Button(action: sendMessage) {
            if isGenerating {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.8)
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 32, height: 32)
        .background(
            Circle()
                .fill(canSend ? theme.foreground : theme.foreground.opacity(0.3))
        )
        .disabled(!canSend)
        .animation(.easeInOut(duration: 0.2), value: canSend)
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating
    }

    private func sendMessage() {
        guard canSend else { return }
        let message = text.trimmingCharacters(in: .whitespacesAndNewlines)
        text = ""
        onSend(message)
    }
}

#Preview {
    VStack {
        Spacer()
        AIInputField(
            text: .constant(""),
            onSend: { _ in },
            isGenerating: false
        )
    }
}
