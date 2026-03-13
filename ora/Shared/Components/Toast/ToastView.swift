import SwiftUI

// MARK: - View Modifier

extension View {
    func toast(manager: ToastManager) -> some View {
        self.frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: manager.position.alignment) {
                ToastsContainerView(manager: manager)
            }
    }
}

// MARK: - Genie Effect

/// A subtle macOS Genie-style warp: pinches one edge while fading + scaling.
private struct GenieEffect: GeometryEffect {
    var progress: CGFloat // 0 = identity, 1 = fully warped
    var isTop: Bool

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let amount = progress

        // Anchor at the edge the toast enters/exits from
        let anchorY: CGFloat = isTop ? 0 : size.height

        var transform = CATransform3DIdentity

        // Subtle perspective
        transform.m34 = -1.0 / 1200 * amount

        // Move anchor to edge, apply scale, move back
        transform = CATransform3DTranslate(transform, size.width / 2, anchorY, 0)
        let scaleX = 1.0 - 0.15 * amount  // pinch width slightly
        let scaleY = 1.0 - 0.25 * amount  // compress height more
        transform = CATransform3DScale(transform, scaleX, scaleY, 1)

        // Tiny X-axis tilt toward the edge (genie warp feel)
        let tiltAngle = (isTop ? -1.0 : 1.0) * 0.06 * amount // ~3.4° max
        transform = CATransform3DRotate(transform, tiltAngle, 1, 0, 0)

        transform = CATransform3DTranslate(transform, -size.width / 2, -anchorY, 0)

        // Slide toward the edge
        let slideY = (isTop ? -1.0 : 1.0) * 16 * amount
        transform = CATransform3DTranslate(transform, 0, slideY, 0)

        return ProjectionTransform(transform)
    }
}

private struct GenieTransitionModifier: ViewModifier {
    let progress: CGFloat
    let isTop: Bool

    func body(content: Content) -> some View {
        content
            .opacity(Double(1 - progress))
            .modifier(GenieEffect(progress: progress, isTop: isTop))
    }
}

private extension AnyTransition {
    static func genie(isTop: Bool) -> AnyTransition {
        .modifier(
            active: GenieTransitionModifier(progress: 1, isTop: isTop),
            identity: GenieTransitionModifier(progress: 0, isTop: isTop)
        )
    }
}

// MARK: - Toast Container (Sonner-style stacking)

private struct ToastsContainerView: View {
    @ObservedObject var manager: ToastManager
    @State private var isExpanded: Bool = false

    private let maxVisible = 3
    private let collapsedOffset: CGFloat = 8
    private let collapsedScale: CGFloat = 0.05
    private let expandedGap: CGFloat = 4
    private let estimatedToastHeight: CGFloat = 44

    private var position: ToastPosition {
        manager.position
    }

    private var isTop: Bool {
        position.isTop
    }

    /// Direction multiplier: top positions stack downward (+1), bottom positions stack upward (-1)
    private var stackDirection: CGFloat {
        isTop ? 1 : -1
    }

    var body: some View {
        let visible = Array(manager.toasts.suffix(maxVisible))

        ZStack(alignment: isTop ? .top : .bottom) {
            ForEach(Array(visible.enumerated()), id: \.element.id) { index, toast in
                let depth = visible.count - 1 - index // 0 = newest (front)

                ToastItemView(toast: toast) {
                    manager.dismiss(id: toast.id)
                }
                .offset(y: dragOffset(for: toast))
                .scaleEffect(
                    isExpanded ? 1 : 1 - CGFloat(depth) * collapsedScale,
                    anchor: isTop ? .top : .bottom
                )
                .offset(
                    y: isExpanded
                        ? CGFloat(depth) * (estimatedToastHeight + expandedGap) * stackDirection
                        : CGFloat(depth) * collapsedOffset * stackDirection
                )
                .opacity(depth >= maxVisible ? 0 : 1)
                .zIndex(Double(index))
                .gesture(swipeToDismiss(toast: toast))
                .transition(.genie(isTop: isTop))
            }
        }
        .padding(isTop ? .top : .bottom, 20)
        .padding(.horizontal, 20)
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
        .animation(.spring(duration: 0.3, bounce: 0.5), value: manager.toasts.map(\.id))
    }

    private func dragOffset(for toast: Toast) -> CGFloat {
        if isTop {
            return min(toast.dragOffsetY, 0)
        } else {
            return max(toast.dragOffsetY, 0)
        }
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
                    let dismissed = isTop
                        ? value.translation.height < -60
                        : value.translation.height > 60

                    if dismissed {
                        let flyOut: CGFloat = isTop ? -300 : 300
                        withAnimation(.easeIn(duration: 0.15)) {
                            manager.toasts[idx].dragOffsetY = flyOut
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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            if let icon = toast.resolvedIcon {
                toastIconView(icon)
            }

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
        .background(colorScheme == .dark ? theme.background.opacity(0.7) : theme.background)
        .background(
            BlurEffectView(material: .hudWindow, blendingMode: .withinWindow)
        )
        .clipShape(ConditionallyConcentricRectangle(cornerRadius: 14))
        .overlay(
            ConditionallyConcentricRectangle(cornerRadius: 14)
                .stroke(theme.border.opacity(0.5), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }

    @ViewBuilder
    private func toastIconView(_ icon: ToastIcon) -> some View {
        switch icon {
        case let .system(name):
            Image(systemName: name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(toast.type.iconColor(theme: theme))
        case let .asset(name):
            Image(name)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)
        case let .view(content):
            content
                .frame(width: 16, height: 16)
        }
    }
}
