import SwiftUI

struct ContainerForm: View {
    @Binding var name: String
    @Binding var emoji: String
    @Binding var isEmojiPickerOpen: Bool
    @FocusState.Binding var isTextFieldFocused: Bool

    let onSubmit: () -> Void
    let defaultEmoji: String

    @Environment(\.theme) private var theme
    @State private var isEmojiPickerHovering = false

    var body: some View {
        HStack(spacing: 8) {
            emojiPickerButton
            nameTextField
        }
    }

    private var emojiPickerButton: some View {
        Button(action: {
            isEmojiPickerOpen.toggle()
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: ContainerConstants.UI.cornerRadius, style: .continuous)
                    .stroke(
                        emoji.isEmpty ? theme.border : theme.border,
                        style: emoji.isEmpty
                            ? StrokeStyle(lineWidth: 1, dash: [5])
                            : StrokeStyle(lineWidth: 1)
                    )
                    .animation(
                        .easeOut(duration: ContainerConstants.Animation.emojiPickerDuration),
                        value: emoji.isEmpty
                    )
                    .background(isEmojiPickerHovering ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2))
                    .cornerRadius(ContainerConstants.UI.cornerRadius)

                if emoji.isEmpty {
                    Image(systemName: "plus")
                        .font(.system(size: 12))
                } else {
                    Text(emoji)
                        .font(.system(size: 12))
                }
            }
        }
        .popover(isPresented: $isEmojiPickerOpen, arrowEdge: .bottom) {
            EmojiPickerView(onSelect: { selectedEmoji in
                emoji = selectedEmoji
                isEmojiPickerOpen = false
            })
        }
        .frame(width: ContainerConstants.UI.emojiButtonSize, height: ContainerConstants.UI.emojiButtonSize)
        .background(isEmojiPickerHovering ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2))
        .cornerRadius(ContainerConstants.UI.cornerRadius)
        .buttonStyle(.plain)
        .onHover { isEmojiPickerHovering = $0 }
    }

    private var nameTextField: some View {
        TextField("Name", text: $name)
            .textFieldStyle(.plain)
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(ContainerConstants.UI.cornerRadius)
            .focused($isTextFieldFocused)
            .onSubmit(onSubmit)
            .overlay(
                RoundedRectangle(cornerRadius: ContainerConstants.UI.cornerRadius, style: .continuous)
                    .stroke(
                        isTextFieldFocused ? theme.foreground.opacity(0.5) : theme.border,
                        lineWidth: isTextFieldFocused ? 2 : 1
                    )
            )
    }
}
