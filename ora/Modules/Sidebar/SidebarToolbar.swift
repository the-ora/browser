//
//  SidebarToolbar.swift
//  ora
//
//  Created by Yonathan Dejene on 13/10/2025.
//
import SwiftUI

struct SidebarToolbar: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var sidebarManager: SidebarManager
    @EnvironmentObject var toolbarManager: ToolbarManager

    private var sidebarIcon: String {
        sidebarManager.sidebarPosition == .secondary ? "sidebar.right" : "sidebar.left"
    }

    var body: some View {
        HStack(spacing: 0) {
            if sidebarManager.sidebarPosition != .secondary {
                WindowControls(isFullscreen: appState.isFullscreen).frame(height: 30)
            }

            if toolbarManager.isToolbarHidden {
                HStack(spacing: 0) {
                    if sidebarManager.sidebarPosition == .primary {
                        HStack {
                            URLBarButton(
                                systemName: sidebarIcon,
                                isEnabled: tabManager.activeTab != nil,
                                foregroundColor: theme.foreground.opacity(0.7),
                                action: { sidebarManager.toggleSidebar() }
                            )
                            .oraShortcutHelp("Toggle Sidebar", for: KeyboardShortcuts.App.toggleSidebar)
                            Spacer()
                        }
                    }
                    URLBarButton(
                        systemName: "chevron.left",
                        isEnabled: tabManager.activeTab?.webView.canGoBack ?? false,
                        foregroundColor: theme.foreground.opacity(0.7),
                        action: {
                            if let activeTab = tabManager.activeTab {
                                activeTab.goBack()
                            }
                        }
                    )
                    .oraShortcutHelp("Go Back", for: KeyboardShortcuts.Navigation.back)

                    URLBarButton(
                        systemName: "chevron.right",
                        isEnabled: tabManager.activeTab?.webView.canGoForward ?? false,
                        foregroundColor: theme.foreground.opacity(0.7),
                        action: {
                            if let activeTab = tabManager.activeTab {
                                activeTab.goForward()
                            }
                        }
                    )
                    .oraShortcutHelp("Go Forward", for: KeyboardShortcuts.Navigation.forward)

                    URLBarButton(
                        systemName: "arrow.clockwise",
                        isEnabled: tabManager.activeTab != nil,
                        foregroundColor: theme.foreground.opacity(0.7),
                        action: {
                            if let activeTab = tabManager.activeTab {
                                activeTab.webView.reload()
                            }
                        }
                    )
                    .oraShortcutHelp("Reload This Page", for: KeyboardShortcuts.Navigation.reload)

                    if sidebarManager.sidebarPosition == .secondary {
                        HStack {
                            Spacer()
                            URLBarButton(
                                systemName: sidebarIcon,
                                isEnabled: tabManager.activeTab != nil,
                                foregroundColor: theme.foreground.opacity(0.7),
                                action: { sidebarManager.toggleSidebar() }
                            )
                            .oraShortcutHelp("Toggle Sidebar", for: KeyboardShortcuts.App.toggleSidebar)
                        }
                    }
                }
                .padding(.trailing, 6)
                .padding(.leading, sidebarManager.sidebarPosition == .primary ? 0 : 6)
                .padding(.vertical, 0)
            }
        }
        .padding(0)
    }
}
