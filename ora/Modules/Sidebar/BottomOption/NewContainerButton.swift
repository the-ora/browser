import AppKit
import SwiftUI

struct NewContainerButton: View {
    @State private var isHovering = false
    @State private var isEmojiPickerHovering = false
    @State private var isPopoverOpen = false
    @State private var name = ""
    @State private var emoji = ""
    @State private var isEmojiPickerOpen = false
    @FocusState private var isTextFieldFocused: Bool

    @Environment(\.theme) private var theme
    @Environment(TabManager.self) private var tabManager

    var body: some View {
        Button(action: {
            isPopoverOpen.toggle()
        }) {
            HStack {
                Image(systemName: "plus")
                    .frame(width: 12, height: 12)
                    .foregroundColor(.secondary)
            }
            .padding(8)
            .background(isHovering ? theme.invertedSolidWindowBackgroundColor.opacity(0.3) : .clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .popover(isPresented: $isPopoverOpen) {
            VStack(alignment: .leading, spacing: 10) {
                Text("New Container")
                    .font(.headline)

                HStack(spacing: 8) {
                    Button(action: {
                        isEmojiPickerOpen.toggle()
                    }) {
                        if emoji.isEmpty {
                            Image(systemName: "plus")
                                .font(.system(size: 12))
                        } else {
                            Text(emoji)
                                .font(.system(size: 12))
                        }
                    }
                    .popover(isPresented: $isEmojiPickerOpen, arrowEdge: .bottom) {
                        EmojiPickerView(onSelect: { emoji in
                            self.emoji = emoji
                            isEmojiPickerOpen = false
                        })
                    }
                    .frame(width: 32, height: 32)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(
                                emoji.isEmpty ? theme.border : theme.border,
                                style: emoji.isEmpty
                                    ? StrokeStyle(lineWidth: 1, dash: [5])
                                    : StrokeStyle(lineWidth: 1)
                            )
                            .animation(.easeOut(duration: 0.1), value: emoji.isEmpty)
                    )
                    .background(isEmojiPickerHovering ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    .buttonStyle(.plain)
                    .onHover { isEmojiPickerHovering = $0 }

                    TextField("Name", text: $name)
                        .textFieldStyle(.plain)
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                        .focused($isTextFieldFocused)
                        .onSubmit {
                            if !name.isEmpty, !emoji.isEmpty {
                                tabManager.createContainer(name: name, emoji: emoji)
                                isPopoverOpen = false
                                name = ""
                                emoji = ""
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(
                                    isTextFieldFocused ? theme.foreground.opacity(0.5) : theme.border,
                                    lineWidth: isTextFieldFocused ? 2 : 1
                                )
                        )
                }

                Button("Create") {
                    tabManager.createContainer(name: name, emoji: emoji)
                    isPopoverOpen = false
                }
                .disabled(name.isEmpty || emoji.isEmpty)
            }
            .frame(width: 300)
            .padding()
        }
    }
}
