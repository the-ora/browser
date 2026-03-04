import SwiftUI

struct ContainerForm: View {
    @Binding var name: String
    @Binding var emoji: String
    @Binding var isEmojiPickerOpen: Bool

    let onSubmit: () -> Void
    let defaultEmoji: String

    @Environment(\.theme) private var theme
    @State private var isEmojiPickerHovering = false
    @FocusState private var isNameFocused: Bool

    #if DEBUG
        @ObserveInjection var forceRedraw
    #endif

    var body: some View {
        HStack(spacing: 8) {
            emojiPickerButton
            nameTextField
        }
        .onAppear { isNameFocused = true }
        .enableInjection()
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
                    .background(isEmojiPickerHovering ? theme.mutedBackground.opacity(0.8)
                        : theme.mutedBackground)
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
        .cornerRadius(ContainerConstants.UI.cornerRadius)
        .buttonStyle(.plain)
        .onHover { isEmojiPickerHovering = $0 }
    }

    private var nameTextField: some View {
        OraInput(
            text: $name,
            placeholder: "eg. work, streaming, finance...",
            onSubmit: onSubmit
        )
        .focused($isNameFocused)
    }
}
