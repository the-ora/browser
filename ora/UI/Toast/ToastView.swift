import SwiftUI

struct Toast: Identifiable {
    private(set) var id: String = UUID().uuidString
    var content: AnyView
    var offsetX: CGFloat = 0

    init(@ViewBuilder content: @escaping (String) -> some View) {
        self.content = .init(content(id))
    }
}

extension View {
    @ViewBuilder
    func toast(toasts: Binding<[Toast]>) -> some View {
        self.frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottom) {
                ToastsView(toasts: toasts)
            }
    }
}

private struct ToastsView: View {
    @Binding var toasts: [Toast]
    @State private var isExpanded: Bool = false
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack(alignment: .bottom) {
            // Toast stack
            VStack(spacing: isExpanded ? 10 : 0) {
                ForEach(Array(toasts.enumerated()), id: \.element.id) { index, toast in
                    toast.content
                        .fixedSize()
                        .layoutPriority(1)
                        .visualEffect { content, _ in
                            content
                                .scaleEffect(isExpanded ? 1 : scale(index: index), anchor: .bottom)
                                .offset(y: isExpanded ? 0 : offsetY(index: index))
                        }
                        .transition(
                            .asymmetric(
                                insertion: .offset(y: 100),
                                removal: .move(edge: .bottom)
                            )
                        )
                }
            }
            .padding(.bottom, 30)
            .onHover { isHovering in
                withAnimation(.bouncy) {
                    isExpanded = isHovering
                }
            }
        }
        // Animate when toasts array changes
//    .animation(.bouncy, value: $toasts)
    }

    private func offsetY(index: Int) -> CGFloat {
        let offset = min(CGFloat(index) * 15, 30)
        return -offset
    }

    private func scale(index: Int) -> CGFloat {
        let scale = min(CGFloat(index) * 0.1, 1)
        return 1 - scale
    }
}

struct ToastView: View {
    var id: String
    var message: String
    var systemImage: String? = "checkmark.circle.fill"
    let action: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage).foregroundColor(theme.background)
            }
            Text(message).foregroundColor(theme.background)
            Spacer(minLength: 10)
            Button(action: {
                // withAnimation(.bouncy) {
                action()
                // }
            }) {
                Image(systemName: "xmark").foregroundColor(theme.background)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(theme.foreground)
        .cornerRadius(10)
        .shadow(radius: 10)
    }
}
