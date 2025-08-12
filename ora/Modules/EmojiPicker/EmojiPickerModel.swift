import Combine
import Foundation
import SwiftUI

struct EmojiCategory: Identifiable {
    let id = UUID()
    let category: String
    let emojis: [EmojiItem]
}

struct EmojiItem: Codable, Identifiable {
    var id = UUID()
    let emoji: String
    let name: String
    let code: [String]?
}

class EmojiViewModel: ObservableObject {
    @Published var categories: [EmojiCategory] = []
    @Published var searchText: String = ""
    @Published var selectedCategory: String?
    @Published var isLoading: Bool = true
    @Published var error: String?

    init() {
        loadEmojis()
    }

    private func loadEmojis() {
        guard let url = Bundle.main.url(forResource: "emoji-set", withExtension: "json") else {
            error = "JSON file not found."
            isLoading = false
            return
        }

        do {
            let data = try Data(contentsOf: url)
            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let emojisDict = root["emojis"] as? [String: Any]
            else {
                throw NSError(domain: "Invalid JSON structure", code: 0)
            }

            let categoryOrder = [
                "Smileys, Emotion, People & Body",
                "Animals & Nature",
                "Food & Drink",
                "Travel, Places & Activities",
                "Objects",
                "Symbols",
                "Flags"
            ]

            var result: [EmojiCategory] = []

            for category in categoryOrder {
                guard let subcategories = emojisDict[category] as? [String: Any] else { continue }
                let subcategoryOrder = getSubcategoryOrder(for: category)

                let emojis: [EmojiItem] =
                    subcategoryOrder.isEmpty
                        ? extractEmojis(from: subcategories)
                        : subcategoryOrder.flatMap { subcat in
                            guard let items = subcategories[subcat] as? [[String: Any]] else { return [] }
                            return items.compactMap(EmojiItem.init(from:))
                        } as! [EmojiItem] // swiftlint:disable:this force_cast

                result.append(EmojiCategory(category: category, emojis: emojis))
            }

            categories = result
            selectedCategory = categories.first?.category
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    private func extractEmojis(from subcategories: [String: Any]) -> [EmojiItem] {
        subcategories.values.compactMap { $0 as? [[String: Any]] }
            .flatMap { $0.compactMap(EmojiItem.init(from:)) }
    }

    private func getSubcategoryOrder(for category: String) -> [String] {
        switch category {
        case "Smileys, Emotion, People & Body":
            return [
                "face-smiling", "face-affection", "face-tongue", "face-hand",
                "face-neutral-skeptical", "face-sleepy", "face-unwell",
                "face-hat", "face-glasses", "face-concerned", "face-negative",
                "face-costume", "cat-face", "monkey-face", "emotion",
                "hand-fingers-open", "hand-fingers-partial", "hand-single-finger",
                "hand-fingers-closed", "hands", "hand-prop", "body-parts",
                "person", "person-gesture", "person-role", "person-fantasy",
                "person-activity", "person-sport", "person-resting",
                "family", "person-symbol"
            ]
        case "Animals & Nature":
            return [
                "animal-mammal", "animal-bird", "animal-amphibian", "animal-reptile",
                "animal-marine", "animal-bug", "plant-flower", "plant-other"
            ]
        case "Food & Drink":
            return [
                "food-fruit", "food-vegetable", "food-prepared", "food-asian",
                "food-marine", "food-sweet", "drink"
            ]
        default:
            return []
        }
    }

    var filteredEmojis: [EmojiItem] {
        guard !searchText.isEmpty else {
            return
                selectedCategory
                    .flatMap { category in categories.first(where: { $0.category == category })?.emojis }
                    ?? []
        }

        let query = searchText.lowercased()
        return categories.flatMap(\.emojis)
            .filter { $0.name.lowercased().contains(query) }
    }
}

private extension EmojiItem {
    init?(from dict: [String: Any]) {
        guard let emoji = dict["emoji"] as? String,
              let name = dict["name"] as? String
        else {
            return nil
        }
        let code = dict["code"] as? [String]
        self.init(emoji: emoji, name: name, code: code)
    }
}
