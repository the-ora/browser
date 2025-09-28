import AppKit
import SwiftUI

struct NewContainerButton: View {
    @State private var isHovering = false
    @State private var isPopoverOpen = false
    @State private var name = ""
    @State private var emoji = ""
    @State private var isEmojiPickerOpen = false
    @FocusState private var isTextFieldFocused: Bool

    @Environment(\.theme) private var theme
    @EnvironmentObject var tabManager: TabManager

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

                ContainerForm(
                    name: $name,
                    emoji: $emoji,
                    isEmojiPickerOpen: $isEmojiPickerOpen,
                    isTextFieldFocused: $isTextFieldFocused,
                    onSubmit: createContainer,
                    defaultEmoji: ContainerConstants.defaultEmoji
                )

                Button("Create") {
                    createContainer()
                }
                .disabled(name.isEmpty)
            }
            .frame(width: ContainerConstants.UI.popoverWidth)
            .padding()
        }
    }

    private func createContainer() {
        guard !name.isEmpty else { return }

        let finalEmoji = emoji.isEmpty ? ContainerConstants.defaultEmoji : emoji
        tabManager.createContainer(name: name, emoji: finalEmoji)
        isPopoverOpen = false
        resetForm()
    }

    private func resetForm() {
        name = ""
        emoji = ""
    }
}
