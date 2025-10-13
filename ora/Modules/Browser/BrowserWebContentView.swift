import SwiftUI

struct BrowserWebContentView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var toolbarManager: ToolbarManager
    let tab: Tab

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !toolbarManager.isToolbarHidden {
                URLBar(
                    onSidebarToggle: {
                        NotificationCenter.default.post(
                            name: .toggleSidebar, object: nil
                        )
                    }
                )
                .transition(
                    .asymmetric(
                        insertion: .push(from: .top),
                        removal: .push(from: .bottom)
                    )
                )
            }

            if tab.isWebViewReady {
                if tab.hasNavigationError, let error = tab.navigationError {
                    StatusPageView(
                        error: error,
                        failedURL: tab.failedURL,
                        onRetry: { tab.retryNavigation() },
                        onGoBack: tab.webView.canGoBack
                            ? {
                                tab.webView.goBack()
                                tab.clearNavigationError()
                            } : nil
                    )
                    .id(tab.id)
                } else {
                    ZStack(alignment: .topTrailing) {
                        WebView(webView: tab.webView).id(tab.id)

                        if appState.showFinderIn == tab.id {
                            FindView(webView: tab.webView)
                                .padding(.top, 16)
                                .padding(.trailing, 16)
                                .zIndex(1000)
                        }

                        if let hovered = tab.hoveredLinkURL, !hovered.isEmpty {
                            LinkPreview(text: hovered)
                        }
                    }
                }
            } else {
                ZStack {
                    Rectangle().fill(theme.background)
                    ProgressView().frame(width: 32, height: 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
