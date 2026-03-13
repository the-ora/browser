import SwiftUI

enum ToastType {
    case success
    case error
    case info

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    func iconColor(theme: Theme) -> Color {
        switch self {
        case .success: return .green
        case .error: return theme.destructive
        case .info: return theme.foreground
        }
    }
}

struct Toast: Identifiable, Equatable {
    private(set) var id: String = UUID().uuidString
    var message: String
    var type: ToastType = .success
    var systemImage: String?
    var dragOffsetY: CGFloat = 0

    var resolvedIcon: String {
        systemImage ?? type.icon
    }

    static func == (lhs: Toast, rhs: Toast) -> Bool {
        lhs.id == rhs.id && lhs.dragOffsetY == rhs.dragOffsetY
    }
}
