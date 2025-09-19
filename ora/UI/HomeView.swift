import SwiftUI

struct HomeView: View {
    let sidebarToggle: () -> Void
    @Environment(\.theme) var theme

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear
                .ignoresSafeArea(.all)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .background(theme.background.opacity(0.65))
                .background(
                    BlurEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                )

            URLBarButton(
                systemName: "sidebar.left",
                isEnabled: true,
                foregroundColor: theme.foreground.opacity(0.3),
                action: { sidebarToggle() }
            )
            .oraShortcut(KeyboardShortcuts.App.toggleSidebar)
            .position(x: 20, y: 20)
            .zIndex(3)

            VStack(alignment: .center, spacing: 16) {
                Image("ora-logo-plain")
                    .resizable()
                    .renderingMode(.template)
                    .frame(width: 50, height: 50)
                    .foregroundColor(theme.foreground.opacity(0.3))

                Text("Less noise, more browsing.")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.foreground.opacity(0.3))
            }
            .offset(x: -10, y: 120)
            .zIndex(2)

            LauncherView(clearOverlay: true)
        }
    }
}
