import SwiftUI

struct CreateFolderSheet: View {
    @Binding var isPresented: Bool
    @Binding var folderName: String
    let onCreate: () -> Void
    
    @Environment(\.theme) private var theme
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Create New Folder")
                .font(.headline)
                .foregroundColor(theme.foreground)
            
            TextField("Folder name", text: $folderName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($isFocused)
                .onSubmit {
                    if !folderName.isEmpty {
                        onCreate()
                        isPresented = false
                    }
                }
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    folderName = ""
                    isPresented = false
                }
                .keyboardShortcut(.escape)
                
                Button("Create") {
                    if !folderName.isEmpty {
                        onCreate()
                        isPresented = false
                    }
                }
                .keyboardShortcut(.return)
                .disabled(folderName.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
        .background(theme.solidWindowBackgroundColor)
        .onAppear {
            folderName = "New Folder"
            isFocused = true
        }
    }
}
