import SwiftUI

struct GradientAnimatingBorder: ViewModifier {
    let color: Color
    let trigger: Bool
    @State private var isAnimating = false
    @State private var showBorder = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if showBorder {
                    ZStack {
                        // Glow effect - outer blur
                        RoundedRectangle(cornerRadius: 16.0, style: .continuous)
                            .stroke(
                                AngularGradient(
                                    gradient: Gradient(colors: [
                                        color,
                                        color.opacity(0.8),
                                        color.opacity(0.4),
                                        color.opacity(0.1),
                                        color.opacity(0.0),
                                        color.opacity(0.0),
                                        color.opacity(0.0),
                                        color.opacity(0.0)
                                    ]),
                                    center: .center,
                                    angle: .degrees(isAnimating ? 360 : 0)
                                ),
                                lineWidth: 8.0
                            )
                            .blur(radius: 40)
                            .opacity(0.9)

                        // Main border
                        RoundedRectangle(cornerRadius: 16.0, style: .continuous)
                            .stroke(
                                AngularGradient(
                                    gradient: Gradient(colors: [
                                        color,
                                        color.opacity(0.9),
                                        color.opacity(0.6),
                                        color.opacity(0.3),
                                        color.opacity(0.1),
                                        color.opacity(0.0),
                                        color.opacity(0.0),
                                        color.opacity(0.0)
                                    ]),
                                    center: .center,
                                    angle: .degrees(isAnimating ? 360 : 0)
                                ),
                                lineWidth: 2.0
                            )
                    }
                    .onAppear {
                        showBorder = true
                        withAnimation(.linear(duration: 0.8).repeatCount(1, autoreverses: false)) {
                            isAnimating = true
                        }
                        // Hide border after animation completes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                showBorder = false
                            }
                        }
                    }
                }
            }
            .onChange(of: trigger) { _, newTrigger in
                if newTrigger {
                    showBorder = true
                    isAnimating = false
                    withAnimation(.linear(duration: 0.8).repeatCount(1, autoreverses: false)) {
                        isAnimating = true
                    }
                    // Hide border after animation completes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showBorder = false
                        }
                    }
                }
            }
    }
}
