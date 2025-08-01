import AppKit
import SwiftUI

// MARK: - BrowserViewController
struct BrowserViewController: View {
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var downloadManager: DownloadManager
    @Environment(\.theme) var theme
    @EnvironmentObject private var appState: AppState
    @State private var isFullscreen = false
    
    @StateObject var hide = SideHolder()
    
    var body: some View {
        HSplit(
            left: {
                SidebarView()
            },
            right: {
                //          ContentView()
                webView
                if tabManager.activeTab  == nil {
                    LauncherView()
                }
            }
        )
        .hide(hide)
        .splitter { Splitter.invisible() }
        .fraction(0.2)
        .constraints(
            minPFraction: 0.15,
            minSFraction: 0.7,
            priority: .left,
            dragToHideP: true
        )
        .ignoresSafeArea(.all)
        .background(theme.windowBackgroundColor)
        .background(BlurEffectView(material: .underWindowBackground, blendingMode: .behindWindow).ignoresSafeArea(.all))
        .background(
            WindowAccessor(
                isSidebarHidden: hide.side == .primary,
                isFullscreen: $isFullscreen
            )
        )
        .overlay {
            if appState.showLauncher && tabManager.activeTab  != nil {
                LauncherView()
            }
        }
    }
    
    @ViewBuilder
    private var webView: some View {
        VStack(alignment: .leading, spacing: 0) {
            URLBar(
                onSidebarToggle: {
                    withAnimation(.spring(response: 0.2, dampingFraction: 1.0)) {
                        hide.toggle(.primary)  // Toggle sidebar with Cmd+S
                    }
                }
            )
            if let tab = tabManager.activeTab {
                if tab.isWebViewReady {
                    ZStack(alignment: .topTrailing) {
                        WebView(webView: tab.webView)
                            .id(tab.id)
                        
                        // Floating find view overlay
                        if appState.showFinderIn == tab.id {
                            FindView(webView: tab.webView)
                                .padding(.top, 16)
                                .padding(.trailing, 16)
                                .zIndex(1000)
                        }
                    }
                } else {
                    ProgressView()
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity
                        )
                }
            }
            
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cornerRadius(isFullscreen && hide.side == .primary ? 0 : 8)
        .padding(
            isFullscreen && hide.side == .primary
            ? EdgeInsets(
                top: 0,
                leading: 0,
                bottom: 0,
                trailing: 0
            )
            : EdgeInsets(
                top: 10,
                leading: hide.side == .primary ? 10 : 0,
                bottom: 10,
                trailing: 10
            )
        )
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
        .ignoresSafeArea(.all)
    }
}
