import SwiftUI

struct DownloadsHistoryView: View {
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var sidebarManager: SidebarManager
    @EnvironmentObject var appState: AppState
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().opacity(0.5)
            content
            Spacer(minLength: 0)
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.subtleWindowBackgroundColor)
        .background(BlurEffectView(material: .underWindowBackground, blendingMode: .behindWindow))
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 0) {
            // Match SidebarHeader traffic light spacing when sidebar is primary
            if sidebarManager.sidebarPosition != .secondary {
                WindowControls(isFullscreen: appState.isFullscreen)
                    .frame(height: 30)
            }

            Text("Downloads")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.foreground)
                .lineLimit(1)

            Spacer()

            if hasNonActiveDownloads {
                Button(action: {
                    downloadManager.clearCompletedDownloads()
                }) {
                    Text("Clear")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 38)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button(action: dismissDownloads) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Spaces")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(theme.foreground.opacity(0.7))
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if downloadManager.activeDownloads.isEmpty, downloadManager.recentDownloads.isEmpty {
            emptyState
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    // Active downloads section
                    if !downloadManager.activeDownloads.isEmpty {
                        sectionHeader("Active")
                        ForEach(downloadManager.activeDownloads) { download in
                            DownloadHistoryRow(download: download)
                        }
                    }

                    // History section (non-active downloads)
                    let historyDownloads = downloadManager.recentDownloads.filter {
                        $0.status != .downloading
                    }
                    if !historyDownloads.isEmpty {
                        if !downloadManager.activeDownloads.isEmpty {
                            Divider().opacity(0.3).padding(.vertical, 4)
                        }
                        sectionHeader("History")
                        ForEach(historyDownloads) { download in
                            DownloadHistoryRow(download: download)
                        }
                    }
                }
                .padding(.horizontal, 10)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "arrow.down.circle")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(theme.mutedForeground)

            Text("No Downloads")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(theme.foreground)

            Text("Files you download will appear here")
                .font(.system(size: 12))
                .foregroundColor(theme.mutedForeground)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, 6)
            .padding(.top, 10)
            .padding(.bottom, 4)
    }

    private var hasNonActiveDownloads: Bool {
        downloadManager.recentDownloads.contains {
            $0.status == .completed || $0.status == .failed || $0.status == .cancelled
        }
    }

    private func dismissDownloads() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
            downloadManager.isShowingDownloadsHistory = false
        }
    }
}
