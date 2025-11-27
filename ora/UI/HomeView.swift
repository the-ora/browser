import SwiftUI

struct HomeView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject private var sidebarManager: SidebarManager

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

            HStack {
                URLBarButton(
                    systemName: "sidebar.left",
                    isEnabled: true,
                    foregroundColor: theme.foreground.opacity(0.3),
                    action: { sidebarManager.toggleSidebar() }
                )
                .oraShortcut(KeyboardShortcuts.App.toggleSidebar)
            }
            .zIndex(3)
            .frame(maxWidth: .infinity, alignment: sidebarManager.sidebarPosition == .primary ? .leading : .trailing)
            .padding(6)
            .padding(.top, 6)
            .ignoresSafeArea(.all)

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
