import SwiftUI

enum ToastType {
    case success
    case error
    case info
    case custom

    var defaultIcon: ToastIcon? {
        switch self {
        case .success: return .system("checkmark.circle.fill")
        case .error: return .system("exclamationmark.triangle.fill")
        case .info: return .system("info.circle.fill")
        case .custom: return nil
        }
    }

    func iconColor(theme: Theme) -> Color {
        switch self {
        case .success: return .green
        case .error: return theme.destructive
        case .info: return theme.foreground
        case .custom: return theme.foreground
        }
    }
}

enum ToastIcon {
    case system(String)
    case asset(String)
    case view(AnyView)

    static func shape(_ shape: some View) -> ToastIcon {
        .view(AnyView(shape))
    }

    static func ora(_ icon: OraIconType, color: Color? = nil) -> ToastIcon {
        .view(AnyView(OraIcons(icon: icon, size: .custom(14), color: color)))
    }
}

struct Toast: Identifiable, Equatable {
    private(set) var id: String = UUID().uuidString
    var message: String
    var type: ToastType = .success
    var icon: ToastIcon?
    var dragOffsetY: CGFloat = 0

    var resolvedIcon: ToastIcon? {
        icon ?? type.defaultIcon
    }

    static func == (lhs: Toast, rhs: Toast) -> Bool {
        lhs.id == rhs.id && lhs.dragOffsetY == rhs.dragOffsetY
    }
}
