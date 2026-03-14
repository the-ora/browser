import SwiftUI

struct DownloadHistoryRow: View {
    let download: Download
    @EnvironmentObject var downloadManager: DownloadManager
    @Environment(\.theme) private var theme
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            fileIconView

            VStack(alignment: .leading, spacing: 2) {
                Text(download.fileName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.foreground)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 4) {
                    if let hostname = sourceHostname {
                        Text(hostname)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)

                        if !statusText.isEmpty {
                            Text("\u{00B7}")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }

                    Text(statusText)
                        .font(.system(size: 10))
                        .foregroundColor(statusColor)
                        .lineLimit(1)

                    Spacer()

                    if download.status == .completed {
                        Text(download.formattedFileSize)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }

                if download.status == .downloading {
                    progressBar
                }
            }

            if isHovered || download.status == .downloading {
                actionButtons
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? theme.mutedBackground.opacity(0.5) : .clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            if download.status == .completed {
                downloadManager.openFile(download)
            }
        }
        .contextMenu {
            DownloadHistoryContextMenu(download: download)
        }
    }

    // MARK: - Subviews

    private var fileIconView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(iconColor.opacity(0.12))
                .frame(width: 32, height: 32)

            Image(systemName: fileIcon)
                .font(.system(size: 14))
                .foregroundColor(iconColor)
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(theme.mutedBackground)
                    .frame(height: 3)

                Capsule()
                    .fill(Color.blue)
                    .frame(width: geo.size.width * download.displayProgress, height: 3)
                    .animation(.easeOut(duration: 0.2), value: download.displayProgress)
            }
        }
        .frame(height: 3)
        .padding(.top, 2)
    }

    private var actionButtons: some View {
        HStack(spacing: 2) {
            switch download.status {
            case .downloading:
                iconButton("xmark.circle.fill", color: .secondary) {
                    downloadManager.cancelDownload(download)
                }
            case .completed:
                iconButton("folder", color: .secondary) {
                    downloadManager.openDownloadInFinder(download)
                }
            case .failed, .cancelled:
                iconButton("arrow.clockwise", color: .blue) {
                    downloadManager.retryDownload(download)
                }
            default:
                EmptyView()
            }

            if download.status != .downloading {
                iconButton("xmark", color: .secondary) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        downloadManager.deleteDownload(download)
                    }
                }
            }
        }
    }

    private func iconButton(_ systemName: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11))
                .foregroundColor(color)
                .frame(width: 20, height: 20)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Computed Properties

    private var sourceHostname: String? {
        guard let url = URL(string: download.originalURLString) else { return nil }
        return url.host?.replacingOccurrences(of: "www.", with: "")
    }

    private var fileIcon: String {
        let ext = (download.fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf": return "doc.fill"
        case "zip", "rar", "7z", "tar", "gz": return "archivebox.fill"
        case "jpg", "jpeg", "png", "gif", "webp", "svg": return "photo.fill"
        case "mp4", "mov", "avi", "mkv", "webm": return "video.fill"
        case "mp3", "wav", "flac", "aac", "ogg": return "music.note"
        case "dmg", "pkg", "app": return "app.fill"
        case "html", "htm": return "globe"
        case "txt", "md", "rtf": return "doc.text.fill"
        case "json", "xml", "csv": return "tablecells.fill"
        case "swift", "js", "py", "rb", "go": return "chevron.left.forwardslash.chevron.right"
        default: return "doc.fill"
        }
    }

    private var iconColor: Color {
        switch download.status {
        case .downloading: return .blue
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .orange
        default: return .gray
        }
    }

    private var statusColor: Color {
        switch download.status {
        case .downloading: return .blue
        case .failed: return .red
        case .cancelled: return .orange
        default: return .secondary
        }
    }

    private var statusText: String {
        switch download.status {
        case .downloading:
            if download.displayFileSize > 0 {
                return "\(download.formattedDownloadedSize) of \(download.formattedFileSize) \u{00B7} \(Int(download.displayProgress * 100))%"
            }
            return download.formattedDownloadedSize
        case .completed:
            return timeAgo(from: download.completedAt ?? download.createdAt)
        case .failed:
            return "Failed"
        case .cancelled:
            return "Cancelled"
        default:
            return "Pending"
        }
    }

    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct DownloadHistoryContextMenu: View {
    let download: Download
    @EnvironmentObject var downloadManager: DownloadManager

    var body: some View {
        Group {
            if download.status == .completed {
                Button("Open") {
                    downloadManager.openFile(download)
                }

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

            if download.status == .failed || download.status == .cancelled {
                Button("Retry Download") {
                    downloadManager.retryDownload(download)
                }
            }

            Divider()

            Button("Remove from History") {
                downloadManager.deleteDownload(download)
            }
        }
    }
}
