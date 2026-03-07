import SwiftUI

struct DownloadsListView: View {
    @EnvironmentObject var downloadManager: DownloadManager
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Downloads")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.foreground)

                Spacer()

                if !downloadManager.recentDownloads.isEmpty {
                    Button("Clear Completed") {
                        downloadManager.clearCompletedDownloads()
                    }
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.background.opacity(0.5))

            Divider()
                .background(theme.background)

            // Downloads list
            if downloadManager.recentDownloads.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)

                    Text("No downloads yet")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    Text("Files you download will appear here")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(downloadManager.recentDownloads) { download in
                            DownloadListItem(download: download)
                                .contextMenu {
                                    DownloadContextMenu(download: download)
                                }
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
        .frame(width: 320)
//        .background(theme.windowBackgroundColor)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

struct DownloadListItem: View {
    let download: Download
    @EnvironmentObject var downloadManager: DownloadManager
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            // File icon
            Image(systemName: fileIcon)
                .foregroundColor(iconColor)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(download.fileName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.foreground)
                    .lineLimit(1)

                HStack {
                    Text(statusText)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    Spacer()

                    if download.status == .completed {
                        Text(download.formattedFileSize)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }

                if download.status == .downloading {
                    // Progress bar for downloading items
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(theme.background)
                                .frame(height: 2)
                                .cornerRadius(1)

                            Rectangle()
                                .fill(.blue)
                                .frame(width: geometry.size.width * download.displayProgress, height: 2)
                                .cornerRadius(1)
                                .animation(.easeOut(duration: 0.2), value: download.displayProgress)
                        }
                    }
                    .frame(height: 2)
                }
            }

            // Action buttons
            HStack(spacing: 4) {
                if download.status == .downloading {
                    Button(action: {
                        downloadManager.cancelDownload(download)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.plain)
                } else if download.status == .completed {
                    Button(action: {
                        downloadManager.openDownloadInFinder(download)
                    }) {
                        Image(systemName: "folder")
                            .foregroundColor(.secondary)
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(download.status == .downloading ? theme.background.opacity(0.3) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            if download.status == .completed {
                downloadManager.openDownloadInFinder(download)
            }
        }
    }

    private var fileIcon: String {
        let ext = (download.fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf":
            return "doc.fill"
        case "zip", "rar", "7z":
            return "archivebox.fill"
        case "jpg", "jpeg", "png", "gif", "webp":
            return "photo.fill"
        case "mp4", "mov", "avi", "mkv":
            return "video.fill"
        case "mp3", "wav", "flac", "aac":
            return "music.note"
        case "dmg", "pkg":
            return "app.fill"
        default:
            return "doc.fill"
        }
    }

    private var iconColor: Color {
        switch download.status {
        case .downloading:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        case .cancelled:
            return .orange
        default:
            return .gray
        }
    }

    private var statusText: String {
        switch download.status {
        case .downloading:
            if download.displayFileSize > 0 {
                return "\(download.formattedDownloadedSize) of \(download.formattedFileSize) • \(Int(download.displayProgress * 100))%"
            } else {
                return download.formattedDownloadedSize
            }
        case .completed:
            return timeAgoString(from: download.completedAt ?? download.createdAt)
        case .failed:
            return "Failed • \(timeAgoString(from: download.createdAt))"
        case .cancelled:
            return "Cancelled • \(timeAgoString(from: download.createdAt))"
        default:
            return "Pending"
        }
    }

    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct DownloadContextMenu: View {
    let download: Download
    @EnvironmentObject var downloadManager: DownloadManager

    var body: some View {
        Group {
            if download.status == .completed {
                Button("Show in Finder") {
                    downloadManager.openDownloadInFinder(download)
                }

                Button("Copy Path") {
                    if let path = download.destinationURL?.path {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(path, forType: .string)
                    }
                }
            }

            if download.status == .downloading {
                Button("Cancel Download") {
                    downloadManager.cancelDownload(download)
                }
            }

            Divider()

            Button("Remove from List") {
                downloadManager.deleteDownload(download)
            }
        }
    }
}
