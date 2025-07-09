import SwiftUI
import AppKit

// MARK: - BrowserViewController
struct BrowserViewController: View {
    @StateObject private var tabManager = TabManager()
    @Environment(\.colorScheme) var colorScheme
    @State private var columnVisibility: NavigationSplitViewVisibility = .all // Changed to NavigationSplitViewVisibility

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) { // Bind columnVisibility
            Sidebar(tabManager: tabManager, isSidebarVisible: .constant(columnVisibility == .all)) // Pass as constant
                .transition(.move(edge: .leading).combined(with: .opacity))
                .toolbar(removing: .sidebarToggle) // Hide default sidebar toggle
        } detail: {
            VStack(alignment: .leading, spacing: 0) {
                if let selectedTab = tabManager.selectedTab {
                    URLBar(tab: selectedTab, columnVisibility: $columnVisibility)
                    
                    WebView(webView: selectedTab.webView)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Text("No tab selected")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(VisualEffectView())
            .cornerRadius(8)
            .padding(6)
            .ignoresSafeArea(.all)
        }
        .navigationSplitViewStyle(.balanced) // Ensure balanced style for macOS
        .background(WindowAccessor(isSidebarVisible: columnVisibility == .all))
    }
}

struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .underWindowBackground
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        // No updates needed
    }
}

struct WindowAccessor: NSViewRepresentable {
    let isSidebarVisible: Bool
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        
        DispatchQueue.main.async {
            if let window = view.window {
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.titlebarSeparatorStyle = .none
                window.isOpaque = false

                // Hide traffic lights when sidebar is hidden
                window.standardWindowButton(.closeButton)?.isHidden = !isSidebarVisible
                window.standardWindowButton(.miniaturizeButton)?.isHidden = !isSidebarVisible
                window.standardWindowButton(.zoomButton)?.isHidden = !isSidebarVisible
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window {
            window.standardWindowButton(.closeButton)?.isHidden = !isSidebarVisible
            window.standardWindowButton(.miniaturizeButton)?.isHidden = !isSidebarVisible
            window.standardWindowButton(.zoomButton)?.isHidden = !isSidebarVisible
        }
    }
}

#Preview {
    BrowserViewController()
}
