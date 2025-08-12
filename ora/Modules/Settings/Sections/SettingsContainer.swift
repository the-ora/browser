import SwiftUI

struct SettingsContainer<Content: View>: View {
    let maxContentWidth: CGFloat
    var usesScrollView: Bool = true
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            if usesScrollView {
                ScrollView { inner }
            } else {
                inner
            }
        }
    }

    @ViewBuilder
    private var inner: some View {
        HStack(alignment: .top) {
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 24) {
                content()
            }
            .frame(maxWidth: maxContentWidth, alignment: .leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}
