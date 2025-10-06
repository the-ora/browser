import SwiftUI

struct HighlightedText: View {
    let text: String
    let searchText: String
    let font: Font
    let primaryColor: Color
    let highlightColor: Color

    init(
        text: String,
        searchText: String,
        font: Font = .body,
        primaryColor: Color = .primary,
        highlightColor: Color = .yellow
    ) {
        self.text = text
        self.searchText = searchText
        self.font = font
        self.primaryColor = primaryColor
        self.highlightColor = highlightColor
    }

    var body: some View {
        if searchText.isEmpty {
            Text(text)
                .font(font)
                .foregroundColor(primaryColor)
        } else {
            Text(buildAttributedString())
                .font(font)
        }
    }

    private func buildAttributedString() -> AttributedString {
        var attributedString = AttributedString(text)
        let searchQuery = searchText.lowercased()
        let textLowercased = text.lowercased()

        var searchStartIndex = textLowercased.startIndex

        while let range = textLowercased.range(of: searchQuery, range: searchStartIndex ..< textLowercased.endIndex) {
            let attributedRange = AttributedString
                .Index(range.lowerBound, within: attributedString)! ..< AttributedString.Index(
                    range.upperBound,
                    within: attributedString
                )!

            attributedString[attributedRange].backgroundColor = highlightColor
            attributedString[attributedRange].foregroundColor = .black

            searchStartIndex = range.upperBound
        }

        // Set the default color for non-highlighted text
        attributedString.foregroundColor = primaryColor

        return attributedString
    }
}

#Preview {
    VStack(spacing: 16) {
        HighlightedText(
            text: "This is a sample text with highlighting",
            searchText: "sample",
            font: .title,
            primaryColor: .primary,
            highlightColor: .yellow
        )

        HighlightedText(
            text: "https://www.example.com/some/path",
            searchText: "example",
            font: .body,
            primaryColor: .secondary,
            highlightColor: .blue.opacity(0.3)
        )

        HighlightedText(
            text: "No highlighting when search is empty",
            searchText: "",
            font: .body
        )
    }
    .padding()
}
