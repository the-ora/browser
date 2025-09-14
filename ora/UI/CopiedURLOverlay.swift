import SwiftUI

struct CopiedURLOverlay: View {
    let foregroundColor: Color
    @Binding var showCopiedAnimation: Bool
    @Binding var startWheelAnimation: Bool

    var body: some View {
        HStack {
            Image(systemName: "link")
            Text("Copied Current URL")
        }
        .font(.system(size: 14))
        .foregroundColor(foregroundColor)
        .opacity(showCopiedAnimation ? 1 : 0)
        .offset(y: showCopiedAnimation ? 0 : (startWheelAnimation ? -12 : 12))
        .animation(.easeOut(duration: 0.3), value: showCopiedAnimation)
        .animation(.easeOut(duration: 0.3), value: startWheelAnimation)
    }
}
