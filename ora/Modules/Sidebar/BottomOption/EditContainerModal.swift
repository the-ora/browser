import SwiftUI

struct EditContainerModal: View {
    let container: TabContainer
    @Binding var isPresented: Bool

    @Environment(\.theme) private var theme
    @EnvironmentObject var tabManager: TabManager

    @State private var name: String = ""
    @State private var emoji: String = ""
    @State private var isEmojiPickerOpen = false
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerView
            containerForm
            actionButtons
        }
        .frame(width: ContainerConstants.UI.popoverWidth)
        .padding()
        .onAppear {
            setupInitialValues()
        }
    }

    private var headerView: some View {
        Text("Edit Container")
            .font(.headline)
    }

    private var containerForm: some View {
        ContainerForm(
            name: $name,
            emoji: $emoji,
            isEmojiPickerOpen: $isEmojiPickerOpen,
            isTextFieldFocused: $isTextFieldFocused,
            onSubmit: saveContainer,
            defaultEmoji: ContainerConstants.defaultEmoji
        )
    }

    private var actionButtons: some View {
        Button("Save") {
            saveContainer()
        }
        .disabled(name.isEmpty)
    }

    private func setupInitialValues() {
        name = container.name
        emoji = container.emoji
    }

    private func saveContainer() {
        guard !name.isEmpty else { return }

        let finalEmoji = emoji.isEmpty ? ContainerConstants.defaultEmoji : emoji
        tabManager.renameContainer(container, name: name, emoji: finalEmoji)
        isPresented = false
    }
}
