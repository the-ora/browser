import SwiftUI

// MARK: - View Modifier

extension View {
    func toast(manager: ToastManager) -> some View {
        self.frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottom) {
                ToastsContainerView(manager: manager)
            }
    }
}

// MARK: - Toast Container (Sonner-style stacking)

private struct ToastsContainerView: View {
    @ObservedObject var manager: ToastManager
    @State private var isExpanded: Bool = false

    private let maxVisible = 3
    private let collapsedOffset: CGFloat = 8
    private let collapsedScale: CGFloat = 0.05
    private let expandedGap: CGFloat = 8
    private let estimatedToastHeight: CGFloat = 44

    var body: some View {
        let visible = Array(manager.toasts.suffix(maxVisible))

        ZStack(alignment: .bottom) {
            ForEach(Array(visible.enumerated()), id: \.element.id) { index, toast in
                let depth = visible.count - 1 - index // 0 = newest (front)

                ToastItemView(toast: toast) {
                    manager.dismiss(id: toast.id)
                }
                .offset(y: max(toast.dragOffsetY, 0))
                .scaleEffect(
                    isExpanded ? 1 : 1 - CGFloat(depth) * collapsedScale,
                    anchor: .bottom
                )
                .offset(
                    y: isExpanded
                        ? -CGFloat(depth) * (estimatedToastHeight + expandedGap)
                        : -CGFloat(depth) * collapsedOffset
                )
                .opacity(depth >= maxVisible ? 0 : 1)
                .zIndex(Double(index))
                .gesture(swipeToDismiss(toast: toast))
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    )
                )
            }
        }
        .padding(.bottom, 20)
        .onHover { hovering in
            withAnimation(.smooth(duration: 0.25)) {
                isExpanded = hovering
            }
            if hovering {
                manager.pauseTimers()
            } else {
                manager.resumeTimers()
            }
        }
        .animation(.spring(duration: 0.4, bounce: 0.2), value: manager.toasts.map(\.id))
    }

    private func swipeToDismiss(toast: Toast) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                if let idx = manager.toasts.firstIndex(where: { $0.id == toast.id }) {
                    manager.toasts[idx].dragOffsetY = value.translation.height
                }
            }
            .onEnded { value in
                if let idx = manager.toasts.firstIndex(where: { $0.id == toast.id }) {
                    if value.translation.height > 60 {
                        withAnimation(.easeIn(duration: 0.15)) {
                            manager.toasts[idx].dragOffsetY = 300
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            manager.dismiss(id: toast.id)
                        }
                    } else {
                        withAnimation(.spring(duration: 0.3, bounce: 0.3)) {
                            manager.toasts[idx].dragOffsetY = 0
                        }
                    }
                }
            }
    }
}

// MARK: - Individual Toast

struct ToastItemView: View {
    let toast: Toast
    let onDismiss: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: toast.resolvedIcon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(toast.type.iconColor(theme: theme))

            Text(toast.message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(theme.foreground)
                .lineLimit(2)

            Spacer(minLength: 10)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(theme.foreground.opacity(0.4))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: 356)
        .background(theme.background)
        .clipShape(ConditionallyConcentricRectangle(cornerRadius: 14))
        .overlay(
            ConditionallyConcentricRectangle(cornerRadius: 14)
                .stroke(theme.border.opacity(0.5), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }
}
