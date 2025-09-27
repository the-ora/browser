import Foundation

/// Constants related to container functionality
enum ContainerConstants {
    /// Default emoji used when no emoji is selected for a container
    static let defaultEmoji = "•"

    /// UI constants for container forms and displays
    enum UI {
        static let normalButtonWidth: CGFloat = 28
        static let compactButtonWidth: CGFloat = 12
        static let popoverWidth: CGFloat = 300
        static let emojiButtonSize: CGFloat = 32
        static let cornerRadius: CGFloat = 10
    }

    /// Animation constants for container interactions
    enum Animation {
        static let hoverDuration: Double = 0.15
        static let emojiPickerDuration: Double = 0.1
    }
}
