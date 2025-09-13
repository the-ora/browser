import SwiftUI

struct DownloadProgressView: View {
    let download: Download
    let onCancel: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            // File icon
            Image(systemName: fileIcon)
                .foregroundColor(theme.foreground)
                .frame(width: 16, height: 16)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(download.fileName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.foreground)
                        .lineLimit(1)

                    Spacer()

                    if download.status == .downloading {
                        Button(action: onCancel) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .frame(width: 14, height: 14)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(theme.background)
                            .frame(height: 3)
                            .cornerRadius(1.5)

                        Rectangle()
                            .fill(progressColor)
                            .frame(width: geometry.size.width * download.displayProgress, height: 3)
                            .cornerRadius(1.5)
                            .animation(.easeOut(duration: 0.2), value: download.displayProgress)
                    }
                }
                .frame(height: 3)

                // Progress text
                HStack {
                    Text(progressText)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    Spacer()

                    if download.displayFileSize > 0, download.status == .downloading {
                        Text("\(Int(download.displayProgress * 100))%")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(8)
        .background(theme.background.opacity(0.3))
        .cornerRadius(6)
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

    private var progressColor: Color {
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

    private var progressText: String {
        let text: String = switch download.status {
        case .downloading:
            if download.displayFileSize > 0 {
                "\(download.formattedDownloadedSize) of \(download.formattedFileSize)"
            } else {
                download.formattedDownloadedSize
            }
        case .completed:
            "Downloaded"
        case .failed:
            "Failed"
        case .cancelled:
            "Cancelled"
        default:
            "Pending"
        }

        return text
    }
}
