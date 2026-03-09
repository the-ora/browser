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
                        onGoBack: tab.canGoBack
                            ? {
                                tab.goBack()
                                tab.clearNavigationError()
                            } : nil
                    )
                    .id(tab.id)
                } else if let page = tab.browserPage {
                    BrowserPageView(page: page).id(tab.id)
                        .overlay(alignment: .topLeading) {
                            if let triggerState = tab.passwordTriggerOverlayState {
                                PasswordAutofillTriggerView(overlay: triggerState, tab: tab)
                            }
                        }
                        .overlay(alignment: .topLeading) {
                            if let passwordOverlayState = tab.passwordOverlayState {
                                PasswordAutofillOverlayView(overlay: passwordOverlayState, tab: tab)
                            }
                        }
                        .overlay(alignment: .topTrailing) {
                            if appState.showFinderIn == tab.id {
                                FindView(page: page)
                                    .padding(.top, 16)
                                    .padding(.trailing, 16)
                            }
                        }
                        .overlay(alignment: .bottomLeading) {
                            if let hovered = tab.hoveredLinkURL, !hovered.isEmpty {
                                LinkPreview(text: hovered)
                            }
                        }
                } else {
                    ZStack {
                        Rectangle().fill(theme.background)
                        ProgressView().frame(width: 32, height: 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
