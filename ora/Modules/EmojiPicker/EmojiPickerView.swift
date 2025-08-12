import SwiftUI

struct EmojiPickerView: View {
    let onSelect: (String) -> Void

    @StateObject private var viewModel = EmojiViewModel()
    @State private var hoveredEmoji: String?

    var body: some View {
        emojiContentView
            .frame(width: 400, height: 400)
            .padding(8)
            .overlay {
                if viewModel.isLoading {
                    ProgressView("Loading Emojis...")
                } else if let error = viewModel.error {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                }
            }
    }

    private var emojiContentView: some View {
        VStack(spacing: 8) {
            SearchBar(text: $viewModel.searchText)
                .frame(height: 40)

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 30))], spacing: 10) {
                    ForEach(viewModel.filteredEmojis) { item in
                        Text(item.emoji)
                            .font(.system(size: 16))
                            .frame(width: 32, height: 32)
                            .background(hoveredEmoji == item.emoji ? Color.gray.opacity(0.2) : Color.clear)
                            .cornerRadius(8)
                            .onHover { hoveredEmoji = $0 ? item.emoji : nil }
                            .onTapGesture { onSelect(item.emoji) }
                    }
                }
            }

            // Bottom category navigation
            HStack {
                Spacer()
                ForEach(viewModel.categories) { category in
                    Button {
                        viewModel.selectedCategory = category.category
                    } label: {
                        // Use a placeholder system image; replace with category-specific emoji if available
                        Image(systemName: categoryIcon(for: category.category))
                            .font(.system(size: 16))
                            .foregroundColor(viewModel.selectedCategory == category.category ? .blue : .gray)
                    }
                    .buttonStyle(.plain)
                    .padding(4)

                    Spacer()
                }
            }
        }
    }

    // Map category names to bottom icons (customize based on JSON or screenshot)
    private func categoryIcon(for category: String) -> String {
        switch category.lowercased() {
        case let str where str.contains("smileys"): return "face.smiling.inverse"
        case let str where str.contains("animals"): return "pawprint"
        case let str where str.contains("food"): return "fork.knife"
        case let str where str.contains("travel"): return "sun.max"
        case let str where str.contains("objects"): return "gift"
        case let str where str.contains("symbols"): return "heart"
        case let str where str.contains("flags"): return "flag"
        default: return "questionmark"
        }
    }
}

// Custom Search Bar
struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Search", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .frame(maxWidth: .infinity)
        }
        .padding(8)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }
}
