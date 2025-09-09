import SwiftUI

struct GlobalMediaPlayer: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var media: MediaController
    @EnvironmentObject var tabManager: TabManager

    @State private var isHovered: Bool = false
    @State private var showVolume: Bool = false

    private var titleText: String {
        media.nowPlaying?.title ?? ""
    }

    private var faviconImage: Image {
        if let url = media.nowPlaying?.favicon {
            return Image(nsImage: NSImage(byReferencing: url))
        }
        return Image(systemName: "play.rectangle.fill")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isHovered, !titleText.isEmpty {
                HStack(spacing: 8) {
                    Text(titleText)
                        .lineLimit(1)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        media.close()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(PlayerIconButtonStyle(isEnabled: true))
                    .foregroundStyle(Color.white.opacity(0.9))
                }
                .padding(.horizontal, 8)
                .padding(.top, 6)
            }

            HStack(spacing: 12) {
                Button {
                    if let id = media.nowPlaying?.tabID {
                        tabManager.activateTab(id: id)
                    }
                } label: {
                    faviconImage
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
                .buttonStyle(PlayerIconButtonStyle(isEnabled: true))
                .help("Go to playing tab")

                Spacer(minLength: 4)

                Button(action: media.previousTrack) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .opacity(media.canGoPrevious ? 1.0 : 0.35)
                }
                .buttonStyle(PlayerIconButtonStyle(isEnabled: media.canGoPrevious))
                .disabled(!media.canGoPrevious)

                Button(action: media.togglePlayPause) {
                    Image(systemName: media.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .bold))
                }
                .buttonStyle(PlayerIconButtonStyle(isEnabled: true))
                .keyboardShortcut(.space, modifiers: [])

                Button(action: media.nextTrack) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .opacity(media.canGoNext ? 1.0 : 0.35)
                }
                .buttonStyle(PlayerIconButtonStyle(isEnabled: media.canGoNext))
                .disabled(!media.canGoNext)

                Spacer(minLength: 6)

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { showVolume.toggle() }
                } label: {
                    Image(systemName: media.volume <= 0.001 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(PlayerIconButtonStyle(isEnabled: true))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            if showVolume {
                Slider(value: Binding(
                    get: { media.volume },
                    set: { media.setVolume($0) }
                ), in: 0 ... 1)
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.background.opacity(0.85))
                .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .onHover { isHovered = $0 }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }
}
