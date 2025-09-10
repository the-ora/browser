import SwiftUI

struct EditableTabTitle: View {
    let tab: Tab
    let isSelected: Bool
    let textColor: Color
    @Binding var isEditing: Bool
    @State private var editingText = ""
    @FocusState private var isFocused: Bool
    @EnvironmentObject var tabManager: TabManager
    
    var body: some View {
        Group {
            if isEditing {
                TextField("Tab name", text: $editingText, onCommit: {
                    saveTitle()
                })
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundColor(textColor)
                .focused($isFocused)
                .background(Color.white.opacity(0.1))
                .cornerRadius(4)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .onAppear {
                    editingText = tab.displayTitle
                    // Delay focus to ensure the text field is ready
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isFocused = true
                    }
                }
                .onSubmit {
                    saveTitle()
                }
                .onExitCommand {
                    cancelEditing()
                }
            } else {
                Text(tab.displayTitle)
                    .font(.system(size: 13))
                    .foregroundColor(textColor)
                    .lineLimit(1)
                    .onTapGesture(count: 2) {
                        startEditing()
                    }
            }
        }
        .onChange(of: isEditing) { _, newValue in
            if newValue {
                editingText = tab.displayTitle
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isFocused = true
                }
            }
        }
    }
    
    private func startEditing() {
        editingText = tab.displayTitle
        isEditing = true
        // Ensure focus is set
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isFocused = true
        }
    }
    
    private func saveTitle() {
        let trimmedText = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If the edited text is empty or the same as the original title, 
        // clear the custom title
        if trimmedText.isEmpty || trimmedText == tab.title {
            tab.customTitle = nil
        } else {
            tab.customTitle = trimmedText
        }
        
        // Save to persistence
        tabManager.saveChanges()
        
        isEditing = false
        isFocused = false
    }
    
    private func cancelEditing() {
        isEditing = false
        isFocused = false
        editingText = tab.displayTitle
    }
}
