import SwiftUI

struct DownloadsWidget: View {
    @EnvironmentObject var downloadManager: DownloadManager
    @Environment(\.theme) private var theme
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            // Active downloads (compact inline progress)
            if !downloadManager.activeDownloads.isEmpty {
                VStack(spacing: 6) {
                    ForEach(downloadManager.activeDownloads) { download in
                        DownloadProgressView(download: download) {
                            downloadManager.cancelDownload(download)
                        }
                    }
                }
                .padding(.bottom, 8)
            }

            // Downloads button - opens the downloads history destination
            Button(action: {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
                    downloadManager.isShowingDownloadsHistory.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down")
                        .foregroundColor(downloadButtonColor)
                        .frame(width: 12, height: 12)
                }
                .padding(8)
                .background(isHovered ? theme.invertedSolidWindowBackgroundColor.opacity(0.3) : .clear)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
        }
    }

    private var downloadButtonColor: Color {
        if !downloadManager.activeDownloads.isEmpty {
            return .blue
        } else if downloadManager.recentDownloads.contains(where: { $0.status == .completed }) {
            return .green
        } else {
            return .secondary
        }
    }
}
