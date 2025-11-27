import SwiftUI

struct DownloadsWidget: View {
    @EnvironmentObject var downloadManager: DownloadManager
    @Environment(\.theme) private var theme
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            // Active downloads
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

            // Downloads button
            Button(action: {
                downloadManager.isDownloadsPopoverOpen.toggle()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle")
                        .foregroundColor(downloadButtonColor)
                        .frame(width: 12, height: 12)

                    // Text("Downloads")
                    //     .font(.system(size: 13, weight: .medium))
                    //     .foregroundColor(theme.foreground)

                    // Spacer()

                    // if !downloadManager.recentDownloads.isEmpty {
                    //     Text("\(downloadManager.recentDownloads.count)")
                    //         .font(.system(size: 11, weight: .medium))
                    //         .foregroundColor(.secondary)
                    //         .padding(.horizontal, 6)
                    //         .padding(.vertical, 2)
                    //         .background(theme.background.opacity(0.6))
                    //         .cornerRadius(8)
                    // }

                    // Image(systemName: downloadManager.isDownloadsPopoverOpen ? "chevron.up" : "chevron.down")
                    //     .foregroundColor(.secondary)
                    //     .frame(width: 12, height: 12)
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
            .popover(isPresented: $downloadManager.isDownloadsPopoverOpen, arrowEdge: .bottom) {
                DownloadsListView()
                    .environmentObject(downloadManager)
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
